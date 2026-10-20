import 'dart:async';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:appflowy_editor/src/editor/editor_component/service/selection/mobile_magnifier.dart';
import 'package:appflowy_editor/src/editor/editor_component/service/selection/shared.dart';
import 'package:flutter/foundation.dart';
import 'package:appflowy_editor/src/render/selection/mobile_basic_handle.dart';
import 'package:appflowy_editor/src/render/selection/mobile_collapsed_handle.dart';
import 'package:appflowy_editor/src/render/selection/mobile_selection_handle.dart';
import 'package:appflowy_editor/src/service/selection/mobile_selection_gesture.dart';
import 'package:flutter/material.dart' hide Overlay, OverlayEntry;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

/// only used in mobile
///
/// this will notify the developers when the selection is not collapsed.
StreamController<int> appFlowyEditorOnTapSelectionArea =
    StreamController<int>.broadcast();

enum MobileSelectionDragMode {
  none,
  leftSelectionHandle,
  rightSelectionHandle,
  cursor;
}

enum MobileSelectionHandlerType {
  leftHandle,
  rightHandle,
  cursorHandle,
}

// the value type is MobileSelectionDragMode
const String selectionDragModeKey = 'selection_drag_mode';
bool disableIOSSelectWordEdgeOnTap = false;
bool disableMagnifier = false;

class MobileSelectionServiceWidget extends StatefulWidget {
  const MobileSelectionServiceWidget({
    super.key,
    this.cursorColor = const Color(0xFF00BCF0),
    this.selectionColor = const Color.fromARGB(53, 111, 201, 231),
    this.showMagnifier = true,
    this.magnifierSize = const Size(72, 48),
    required this.child,
  });

  final Widget child;
  final Color cursorColor;
  final Color selectionColor;

  /// Show the magnifier or not.
  ///
  /// only works on iOS or Android.
  final bool showMagnifier;

  final Size magnifierSize;

  @override
  State<MobileSelectionServiceWidget> createState() =>
      _MobileSelectionServiceWidgetState();
}

class _MobileSelectionServiceWidgetState
    extends State<MobileSelectionServiceWidget>
    with WidgetsBindingObserver
    implements AppFlowySelectionService {
  @override
  final List<Rect> selectionRects = [];

  @override
  ValueNotifier<Selection?> currentSelection = ValueNotifier(null);

  @override
  List<Node> currentSelectedNodes = [];

  final List<SelectionGestureInterceptor> _interceptors = [];
  final ValueNotifier<Offset?> _lastPanOffset = ValueNotifier(null);

  // the selection from editorState will be updated directly, but the cursor
  // or selection area depends on the layout of the text, so we need to update
  // the selection after the layout.
  final PropertyValueNotifier<Selection?> selectionNotifierAfterLayout =
      PropertyValueNotifier<Selection?>(null);

  /// Pan
  Offset? _panStartOffset;
  double? _panStartScrollDy;
  Selection? _panStartSelection;
  bool? _isPanStartHorizontal;

  MobileSelectionDragMode dragMode = MobileSelectionDragMode.none;

  bool updateSelectionByTapUp = false;
  bool _preserveViewing = false;
  bool _longPressSelectingWords = false;

  late EditorState editorState = Provider.of<EditorState>(
    context,
    listen: false,
  );

  bool isCollapsedHandleVisible = false;

  Timer? collapsedHandleTimer;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);
    editorState.selectionNotifier.addListener(_updateSelection);
    editorState.addScrollViewScrolledListener(_handleAutoScrollWhileDragging);
  }

  @override
  void dispose() {
    clearSelection();
    _lastPanOffset.dispose();
    currentSelection.dispose();
    WidgetsBinding.instance.removeObserver(this);
    selectionNotifierAfterLayout.dispose();
    editorState.selectionNotifier.removeListener(_updateSelection);
    editorState.removeScrollViewScrolledListener(
      _handleAutoScrollWhileDragging,
    );
    collapsedHandleTimer?.cancel();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stack = Stack(
      clipBehavior: Clip.none,
      children: [
        widget.child,

        // magnifier for zoom in the text.
        if (widget.showMagnifier) _buildMagnifier(),

        // the handles for expanding the selection area.
        _buildLeftHandle(),
        _buildRightHandle(),
        _buildCollapsedHandle(),
      ],
    );

    return defaultTargetPlatform == TargetPlatform.iOS
        ? MobileSelectionGestureDetector(
            deferSingleTap: () =>
                editorState.service.keyboardService?.isEditing != true,
            onTapUp: _onTapUp,
            onDoubleTapUp: _onDoubleTapUp,
            onTripleTapUp: _onTripleTapUp,
            onLongPressStart: _onLongPressStart,
            onLongPressMoveUpdate: _onLongPressUpdate,
            onLongPressEnd: _onLongPressEnd,
            child: stack,
          )
        : MobileSelectionGestureDetector(
            deferSingleTap: () =>
                editorState.service.keyboardService?.isEditing != true,
            onTapUp: _onTapUp,
            onDoubleTapUp: _onDoubleTapUp,
            onTripleTapUp: _onTripleTapUp,
            onLongPressStart: _onLongPressStart,
            onLongPressMoveUpdate: _onLongPressUpdate,
            onLongPressEnd: _onLongPressEnd,
            onPanUpdate: _onPanUpdateAndroid,
            onPanEnd: _onPanEndAndroid,
            child: stack,
          );
  }

  Widget _buildMagnifier() {
    return ValueListenableBuilder(
      valueListenable: _lastPanOffset,
      builder: (_, offset, __) {
        if (offset == null || disableMagnifier || _longPressSelectingWords) {
          return const SizedBox.shrink();
        }
        return MobileMagnifier(
          size: widget.magnifierSize,
          offset: offset,
        );
      },
    );
  }

  Widget _buildCollapsedHandle() {
    return ValueListenableBuilder(
      valueListenable: selectionNotifierAfterLayout,
      builder: (context, selection, _) {
        if (selection == null || !selection.isCollapsed) {
          isCollapsedHandleVisible = false;

          return const SizedBox.shrink();
        }

        // on Android, the drag handle should be updated when typing text.
        if (defaultTargetPlatform == TargetPlatform.android &&
            editorState.selectionUpdateReason !=
                SelectionUpdateReason.uiEvent) {
          isCollapsedHandleVisible = false;

          return const SizedBox.shrink();
        }

        if (selection.isCollapsed &&
            [
              MobileSelectionDragMode.leftSelectionHandle,
              MobileSelectionDragMode.rightSelectionHandle,
            ].contains(dragMode)) {
          isCollapsedHandleVisible = false;

          return const SizedBox.shrink();
        }

        selection = selection.normalized;

        final node = editorState.getNodeAtPath(selection.start.path);
        final selectable = node?.selectable;
        final rect = selectable?.getCursorRectInPosition(
          selection.start,
          shiftWithBaseOffset: true,
        );

        if (node == null || rect == null) {
          isCollapsedHandleVisible = false;

          return const SizedBox.shrink();
        }

        isCollapsedHandleVisible = true;

        _clearCollapsedHandleOnAndroid();

        final editorStyle = editorState.editorStyle;

        return MobileCollapsedHandle(
          layerLink: node.layerLink,
          rect: rect,
          handleColor: editorStyle.dragHandleColor,
          handleWidth: editorStyle.mobileDragHandleWidth,
          handleBallWidth: editorStyle.mobileDragHandleBallSize.width,
          enableHapticFeedbackOnAndroid:
              editorStyle.enableHapticFeedbackOnAndroid,
          onDragging: (isDragging) {
            if (isDragging) {
              collapsedHandleTimer?.cancel();
              collapsedHandleTimer = null;
            } else {
              _clearCollapsedHandleOnAndroid();
            }
          },
        );
      },
    );
  }

  Widget _buildLeftHandle() {
    return _buildHandle(HandleType.left);
  }

  Widget _buildRightHandle() {
    return _buildHandle(HandleType.right);
  }

  Widget _buildHandle(HandleType handleType) {
    if (![HandleType.left, HandleType.right].contains(handleType)) {
      throw ArgumentError('showLeftHandle and showRightHandle cannot be same.');
    }

    return ValueListenableBuilder(
      valueListenable: selectionNotifierAfterLayout,
      builder: (context, selection, _) {
        if (selection == null) {
          return const SizedBox.shrink();
        }

        if (selection.isCollapsed &&
            [
              MobileSelectionDragMode.none,
              MobileSelectionDragMode.cursor,
            ].contains(dragMode)) {
          return const SizedBox.shrink();
        }

        final isCollapsedWhenDraggingHandle = selection.isCollapsed &&
            [
              MobileSelectionDragMode.leftSelectionHandle,
              MobileSelectionDragMode.rightSelectionHandle,
            ].contains(dragMode);

        selection = selection.normalized;

        final node = editorState.getNodeAtPath(
          handleType == HandleType.left
              ? selection.start.path
              : selection.end.path,
        );
        final selectable = node?.selectable;

        // get the cursor rect when the selection is collapsed.
        final rects = isCollapsedWhenDraggingHandle
            ? [
                selectable?.getCursorRectInPosition(
                      selection.start,
                      shiftWithBaseOffset: true,
                    ) ??
                    Rect.zero,
              ]
            : selectable?.getRectsInSelection(
                selection,
                shiftWithBaseOffset: true,
              );

        if (node == null || rects == null || rects.isEmpty) {
          return const SizedBox.shrink();
        }

        final editorStyle = editorState.editorStyle;

        return MobileSelectionHandle(
          layerLink: node.layerLink,
          rect: handleType == HandleType.left ? rects.first : rects.last,
          handleType: handleType,
          handleColor: isCollapsedWhenDraggingHandle
              ? Colors.transparent
              : editorStyle.dragHandleColor,
          handleWidth: editorStyle.mobileDragHandleWidth,
          handleBallWidth: editorStyle.mobileDragHandleBallSize.width,
          enableHapticFeedbackOnAndroid:
              editorStyle.enableHapticFeedbackOnAndroid,
        );
      },
    );
  }

  // The collapsed handle will be dismissed when no user interaction is detected.
  void _clearCollapsedHandleOnAndroid() {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    collapsedHandleTimer?.cancel();
    collapsedHandleTimer = Timer(
      editorState.editorStyle.autoDismissCollapsedHandleDuration,
      () {
        if (isCollapsedHandleVisible) {
          editorState.updateSelectionWithReason(
            editorState.selection,
          );
        }
      },
    );
  }

  @override
  void updateSelection(Selection? selection) {
    if (currentSelection.value == selection) {
      return;
    }

    _clearSelection();

    if (selection != null) {
      if (!selection.isCollapsed) {
        // updates selection area.
        AppFlowyEditorLog.selection.debug('update cursor area, $selection');
        _updateSelectionAreas(selection);
      }
    }

    currentSelection.value = selection;
    editorState.updateSelectionWithReason(
      selection,
      reason: SelectionUpdateReason.uiEvent,
      customSelectionType: SelectionType.inline,
      extraInfo: {
        selectionDragModeKey: dragMode,
        selectionExtraInfoDoNotAttachTextService:
            _preserveViewing || dragMode == MobileSelectionDragMode.cursor,
        selectionExtraInfoDisableFloatingToolbar:
            dragMode != MobileSelectionDragMode.none,
      },
    );
  }

  @override
  void clearSelection() {
    currentSelectedNodes = [];
    currentSelection.value = null;

    _clearSelection();
  }

  void _clearPanVariables() {
    _longPressSelectingWords = false;
    _panStartOffset = null;
    _panStartSelection = null;
    _panStartScrollDy = null;
    _lastPanOffset.value = null;
  }

  @override
  void clearCursor() {
    _clearSelection();
  }

  void _clearSelection() {
    selectionRects.clear();
  }

  void _handleAutoScrollWhileDragging() {
    if (!mounted || dragMode == MobileSelectionDragMode.none) {
      return;
    }
    if (_panStartOffset == null ||
        _panStartSelection == null ||
        _lastPanOffset.value == null) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          dragMode == MobileSelectionDragMode.none ||
          _panStartOffset == null ||
          _panStartSelection == null) {
        return;
      }
      final offset = _lastPanOffset.value;
      if (offset == null) {
        return;
      }
      _updateSelectionDuringDrag(offset);
    });
  }

  void _updateSelectionDuringDrag(Offset panEndOffset) {
    if (_panStartOffset == null || _panStartSelection == null) {
      return;
    }

    if (_longPressSelectingWords) {
      final word = getNodeInOffset(panEndOffset)
          ?.selectable
          ?.getWordBoundaryInOffset(panEndOffset);
      if (word != null) {
        updateSelection(mobileWordDragSelection(_panStartSelection!, word));
      }
      return;
    }

    final double? dy = editorState.service.scrollService?.dy;
    final Offset panStartOffset;
    if (dy == null || _panStartScrollDy == null) {
      panStartOffset = _panStartOffset!;
    } else {
      panStartOffset = _panStartOffset!.translate(
        0,
        _panStartScrollDy! - dy,
      );
    }

    final selectionInRange = getNodeInOffset(panEndOffset)
        ?.selectable
        ?.getSelectionInRange(panStartOffset, panEndOffset);
    final end = selectionInRange?.end;
    if (end == null) {
      return;
    }

    late final Selection newSelection;
    switch (dragMode) {
      case MobileSelectionDragMode.leftSelectionHandle:
        newSelection = Selection(
          start: _panStartSelection!.normalized.end,
          end: end,
        ).normalized;
        break;

      case MobileSelectionDragMode.rightSelectionHandle:
        newSelection = Selection(
          start: _panStartSelection!.normalized.start,
          end: end,
        ).normalized;
        break;

      case MobileSelectionDragMode.cursor:
        newSelection = Selection.collapsed(end);
        break;

      case MobileSelectionDragMode.none:
        return;
    }

    updateSelection(newSelection);
  }

  @override
  Node? getNodeInOffset(Offset offset) {
    final List<Node> sortedNodes = editorState.getVisibleNodes(
      context.read<EditorScrollController>(),
    );

    return editorState.getNodeInOffset(
      sortedNodes,
      offset,
      0,
      sortedNodes.length - 1,
    );
  }

  @override
  Position? getPositionInOffset(Offset offset) {
    final node = getNodeInOffset(offset);
    final selectable = node?.selectable;
    if (selectable == null) {
      clearSelection();

      return null;
    }

    return selectable.getPositionInOffset(offset);
  }

  @override
  void registerGestureInterceptor(SelectionGestureInterceptor interceptor) {
    _interceptors.add(interceptor);
  }

  @override
  void unregisterGestureInterceptor(String key) {
    _interceptors.removeWhere((element) => element.key == key);
  }

  void _updateSelection() {
    final selection = editorState.selection;

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      if (mounted) selectionNotifierAfterLayout.value = selection;
    });

    if (currentSelection.value != selection) {
      clearSelection();

      return;
    }

    if (selection != null) {
      if (!selection.isCollapsed) {
        // updates selection area.
        AppFlowyEditorLog.selection.debug('update cursor area, $selection');
        WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
          selectionRects.clear();
          _clearSelection();
          _updateSelectionAreas(selection);
        });
      }
    }
  }

  @override
  Selection? onPanStart(
    DragStartDetails details,
    MobileSelectionDragMode mode,
  ) {
    _preserveViewing = editorState.service.keyboardService?.isEditing != true;
    _panStartOffset = details.globalPosition.translate(-3.0, 0);
    _panStartScrollDy = editorState.service.scrollService?.dy;

    final selection = editorState.selection;
    _panStartSelection = selection;

    dragMode = mode;

    // Publish gesture ownership before the first move update, so a host can
    // suspend competing page gestures and hide the selection menu immediately.
    updateSelection(selection);

    return selection;
  }

  @override
  Selection? onPanUpdate(
    DragUpdateDetails details,
    MobileSelectionDragMode mode,
  ) {
    if (_panStartOffset == null || _panStartScrollDy == null) {
      return null;
    }

    // only support selection mode now.
    if (editorState.selection == null ||
        dragMode == MobileSelectionDragMode.none) {
      return null;
    }

    final panEndOffset = details.globalPosition;

    final dy = editorState.service.scrollService?.dy;
    final panStartOffset = dy == null
        ? _panStartOffset!
        : _panStartOffset!.translate(0, _panStartScrollDy! - dy);
    final end = getNodeInOffset(panEndOffset)
        ?.selectable
        ?.getSelectionInRange(panStartOffset, panEndOffset)
        .end;

    Selection? newSelection;

    if (end != null) {
      if (dragMode == MobileSelectionDragMode.leftSelectionHandle) {
        newSelection = Selection(
          start: _panStartSelection!.normalized.end,
          end: end,
        ).normalized;
      } else if (dragMode == MobileSelectionDragMode.rightSelectionHandle) {
        newSelection = Selection(
          start: _panStartSelection!.normalized.start,
          end: end,
        ).normalized;
      } else if (dragMode == MobileSelectionDragMode.cursor) {
        newSelection = Selection.collapsed(end);
      }
      _lastPanOffset.value = panEndOffset;
    }

    if (newSelection != null) {
      updateSelection(newSelection);
    }

    return newSelection;
  }

  @override
  void onPanEnd(DragEndDetails details, MobileSelectionDragMode mode) {
    _clearPanVariables();
    dragMode = MobileSelectionDragMode.none;

    editorState.updateSelectionWithReason(
      editorState.selection,
      reason: SelectionUpdateReason.uiEvent,
      extraInfo: {
        selectionExtraInfoDoNotAttachTextService: _preserveViewing,
      },
    );
  }

  void _onTapUp(TapUpDetails details) {
    final offset = details.globalPosition;
    final editing = editorState.service.keyboardService?.isEditing == true;
    if (!editing && _isClickOnSelectionArea(offset)) return;
    final node = getNodeInOffset(offset);
    final position = node?.selectable?.getPositionInOffset(offset);
    if (position == null) return;
    final current = editorState.selection;
    final selection = defaultTargetPlatform == TargetPlatform.iOS &&
            disableIOSSelectWordEdgeOnTap
        ? Selection.collapsed(position)
        : mobileTextTapSelection(
            tapped: position,
            word: node?.selectable?.getWordBoundaryInOffset(offset),
            current: current,
            editing: editing,
          );
    _preserveViewing = false;
    clearSelection();
    editorState.updateSelectionWithReason(
      selection,
      reason: SelectionUpdateReason.uiEvent,
      customSelectionType: SelectionType.inline,
      extraInfo: {
        selectionExtraInfoDisableFloatingToolbar: !(editing &&
            current?.isCollapsed == true &&
            current!.start == position),
      },
    );
  }

  void _onDoubleTapUp(TapUpDetails details) {
    final offset = details.globalPosition;
    final node = getNodeInOffset(offset);
    // select word boundary closest to offset
    final selection = node?.selectable?.getWordBoundaryInOffset(offset);
    if (selection == null) {
      clearSelection();

      return;
    }
    _preserveViewing = editorState.service.keyboardService?.isEditing != true;
    updateSelection(selection);
  }

  void _onTripleTapUp(TapUpDetails details) {
    final offset = details.globalPosition;
    final node = getNodeInOffset(offset);
    // select node closest to offset
    final selectable = node?.selectable;
    if (selectable == null) {
      clearSelection();

      return;
    }
    final Selection selection = Selection(
      start: selectable.start(),
      end: selectable.end(),
    );
    updateSelection(selection);
  }

  void _onLongPressStart(LongPressStartDetails details) {
    final offset = details.globalPosition;
    _preserveViewing = editorState.service.keyboardService?.isEditing != true;
    final selectable = getNodeInOffset(offset)?.selectable;
    final position = selectable?.getPositionInOffset(offset);
    final selection = _preserveViewing
        ? selectable?.getWordBoundaryInOffset(offset)
        : position == null
            ? null
            : Selection.collapsed(position);
    if (selection == null) return;
    _panStartOffset = offset;
    _panStartScrollDy = editorState.service.scrollService?.dy;
    _panStartSelection = selection;
    _longPressSelectingWords = _preserveViewing;
    dragMode = _preserveViewing
        ? MobileSelectionDragMode.rightSelectionHandle
        : MobileSelectionDragMode.cursor;
    _lastPanOffset.value = offset;
    if (defaultTargetPlatform == TargetPlatform.android &&
        editorState.editorStyle.enableHapticFeedbackOnAndroid) {
      unawaited(HapticFeedback.mediumImpact());
    }
    updateSelection(selection);
  }

  void _onLongPressUpdate(LongPressMoveUpdateDetails details) {
    if (_panStartSelection == null ||
        dragMode == MobileSelectionDragMode.none) {
      return;
    }
    final offset = details.globalPosition;
    _lastPanOffset.value = offset;
    if (!_longPressSelectingWords) {
      final position = getPositionInOffset(offset);
      if (position != null) updateSelection(Selection.collapsed(position));
      return;
    }
    final word =
        getNodeInOffset(offset)?.selectable?.getWordBoundaryInOffset(offset);
    if (word == null) return;
    updateSelection(mobileWordDragSelection(_panStartSelection!, word));
  }

  void _onLongPressEnd(LongPressEndDetails details) {
    _clearPanVariables();
    dragMode = MobileSelectionDragMode.none;
    editorState.updateSelectionWithReason(
      editorState.selection,
      reason: SelectionUpdateReason.uiEvent,
      customSelectionType: SelectionType.inline,
      extraInfo: {
        selectionDragModeKey: dragMode,
        selectionExtraInfoDoNotAttachTextService: _preserveViewing,
        selectionExtraInfoDisableFloatingToolbar:
            editorState.selection?.isCollapsed != false,
      },
    );
  }

  void _onPanUpdateAndroid(DragUpdateDetails details) {
    if (editorState.service.keyboardService?.isEditing != true) return;
    // if current pan gesture is not initially horizontal, return
    if (_isPanStartHorizontal == false) {
      return;
    }
    // first call to onPanUpdate to determine if current pan gesture is horizontal
    // if not, disable future calls in the guard clause above
    if (details.delta.dx.abs() < details.delta.dy.abs() &&
        (_panStartOffset == null || _panStartScrollDy == null)) {
      _isPanStartHorizontal = false;

      return;
    }
    // first successful call to onPanUpdate, initialize pan variables
    final offset = details.globalPosition;
    if (_panStartOffset == null || _panStartScrollDy == null) {
      _panStartOffset = offset;
      _panStartScrollDy = editorState.service.scrollService?.dy;
      dragMode = MobileSelectionDragMode.cursor;
    }

    final position = getPositionInOffset(offset);

    _lastPanOffset.value = offset;
    if (position == null) {
      return;
    }

    final selection = Selection.collapsed(position);

    if (editorState.editorStyle.enableHapticFeedbackOnAndroid) {
      HapticFeedback.lightImpact();
    }
    updateSelection(selection);
  }

  void _onPanEndAndroid(DragEndDetails details) {
    _clearPanVariables();
    dragMode = MobileSelectionDragMode.none;
    _isPanStartHorizontal = null;

    editorState.updateSelectionWithReason(
      editorState.selection,
      reason: SelectionUpdateReason.uiEvent,
      extraInfo: {
        selectionExtraInfoDoNotAttachTextService: false,
        selectionExtraInfoDisableFloatingToolbar: true,
      },
    );
  }

  // delete this function in the future.
  void _updateSelectionAreas(Selection selection) {
    final nodes = editorState.getNodesInSelection(selection);

    currentSelectedNodes = nodes;

    final backwardNodes =
        selection.isBackward ? nodes : nodes.reversed.toList(growable: false);
    final normalizedSelection = selection.normalized;
    assert(normalizedSelection.isBackward);

    AppFlowyEditorLog.selection
        .debug('update selection areas, $normalizedSelection');

    for (var i = 0; i < backwardNodes.length; i++) {
      final node = backwardNodes[i];

      final selectable = node.selectable;
      if (selectable == null) {
        continue;
      }

      var newSelection = normalizedSelection.copyWith();

      /// In the case of multiple selections,
      ///  we need to return a new selection for each selected node individually.
      ///
      /// < > means selected.
      /// text: abcd<ef
      /// text: ghijkl
      /// text: mn>opqr
      ///
      if (!normalizedSelection.isSingle) {
        if (i == 0) {
          newSelection = newSelection.copyWith(end: selectable.end());
        } else if (i == nodes.length - 1) {
          newSelection = newSelection.copyWith(start: selectable.start());
        } else {
          newSelection = Selection(
            start: selectable.start(),
            end: selectable.end(),
          );
        }
      }

      final rects = selectable.getRectsInSelection(
        newSelection,
        shiftWithBaseOffset: true,
      );
      for (final rect in rects) {
        final selectionRect = selectable.transformRectToGlobal(
          rect,
          shiftWithBaseOffset: true,
        );
        selectionRects.add(selectionRect);
      }
    }
  }

  bool _isClickOnSelectionArea(Offset point) {
    for (final rect in selectionRects) {
      if (rect.contains(point)) {
        return true;
      }
    }

    return false;
  }

  @override
  void removeDropTarget() {
    // Do nothing on mobile
  }

  @override
  void renderDropTargetForOffset(
    Offset offset, {
    DragAreaBuilder? builder,
    DragTargetNodeInterceptor? interceptor,
  }) {
    // Do nothing on mobile
  }

  @override
  DropTargetRenderData? getDropTargetRenderData(
    Offset offset, {
    DragTargetNodeInterceptor? interceptor,
  }) =>
      null;
}
