import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';

/// A selectable leaf block with caret positions before (0) and after (1).
/// The outer fifth on either side places the caret; the centre belongs to
/// [onTap] callback. Interactive content takes priority over caret placement.
/// Pair with [AtomicBlockKeyboardInput] for editing.
class AtomicBlockComponentBuilder extends BlockComponentBuilder {
  AtomicBlockComponentBuilder({
    required this.editorState,
    required this.editorFocus,
    required this.contentBuilder,
    required BlockComponentValidate validate,
    this.edgeKeyBuilder,
    this.onTap,
  }) {
    this.validate = validate;
  }

  final EditorState editorState;
  final FocusNode editorFocus;
  final Widget Function(BuildContext, Node) contentBuilder;

  final Key Function(Node, bool)? edgeKeyBuilder;
  final ValueChanged<Node>? onTap;

  @override
  BlockComponentWidget build(BlockComponentContext blockComponentContext) =>
      _AtomicBlockComponent(
        key: blockComponentContext.node.key,
        node: blockComponentContext.node,
        editorState: editorState,
        editorFocus: editorFocus,
        contentBuilder: contentBuilder,
        edgeKeyBuilder: edgeKeyBuilder,
        onTap: onTap,
      );
}

class _AtomicBlockComponent extends BlockComponentStatefulWidget {
  const _AtomicBlockComponent({
    super.key,
    required super.node,
    required this.editorState,
    required this.editorFocus,
    required this.contentBuilder,
    this.edgeKeyBuilder,
    this.onTap,
  }) : super(configuration: const BlockComponentConfiguration());

  final EditorState editorState;
  final FocusNode editorFocus;
  final Widget Function(BuildContext, Node) contentBuilder;
  final Key Function(Node, bool)? edgeKeyBuilder;
  final ValueChanged<Node>? onTap;

  @override
  State<_AtomicBlockComponent> createState() => _AtomicBlockComponentState();
}

class _AtomicBlockComponentState extends State<_AtomicBlockComponent>
    with SelectableMixin, BlockComponentConfigurable {
  RenderBox? get _box => context.findRenderObject() as RenderBox?;

  @override
  Node get node => widget.node;

  @override
  BlockComponentConfiguration get configuration => widget.configuration;

  @override
  Widget build(BuildContext context) => BlockSelectionContainer(
        node: node,
        delegate: this,
        listenable: widget.editorState.selectionNotifier,
        remoteSelection: widget.editorState.remoteSelections,
        blockColor: widget.editorState.editorStyle.selectionColor,
        cursorColor: widget.editorState.editorStyle.cursorColor,
        selectionColor: widget.editorState.editorStyle.selectionColor,
        selectionAboveBlock: true,
        supportTypes: const [
          BlockSelectionType.block,
          BlockSelectionType.cursor,
          BlockSelectionType.selection,
        ],
        child: LayoutBuilder(
          builder: (context, constraints) => SizedBox(
            width: constraints.maxWidth,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: widget.editorState.editable
                  ? (details) {
                      final x = details.localPosition.dx;
                      final width = constraints.maxWidth;
                      if (x < width / 5) {
                        _placeCursor(true);
                      } else if (x > width * 4 / 5) {
                        _placeCursor(false);
                      } else {
                        widget.onTap?.call(node);
                      }
                    }
                  : null,
              child: Stack(
                children: [
                  widget.contentBuilder(context, node),
                  if (widget.editorState.editable)
                    for (final before in [true, false])
                      Positioned(
                        left: before ? 0 : null,
                        right: before ? null : 0,
                        top: 0,
                        bottom: 0,
                        width: constraints.maxWidth / 5,
                        child: IgnorePointer(
                          child: SizedBox.expand(
                            key: widget.edgeKeyBuilder?.call(node, before) ??
                                ValueKey(
                                  'atomic-block-${node.id}-${before ? 'before' : 'after'}',
                                ),
                          ),
                        ),
                      ),
                ],
              ),
            ),
          ),
        ),
      );

  void _placeCursor(bool before) {
    final selection = Selection.collapsed(before ? start() : end());
    widget.editorFocus.requestFocus();
    widget.editorState.updateSelectionWithReason(
      selection,
      reason: SelectionUpdateReason.uiEvent,
    );
    widget.editorState.service.keyboardService?.enableKeyboardForAtomicBlock();
  }

  @override
  Position start() => Position(path: node.path);

  @override
  Position end() => Position(path: node.path, offset: 1);

  @override
  Position getPositionInOffset(Offset offset) {
    final box = _box;
    if (box == null) return start();
    return box.globalToLocal(offset).dx < box.size.width / 2 ? start() : end();
  }

  @override
  bool get shouldCursorBlink => true;

  @override
  CursorStyle get cursorStyle => CursorStyle.verticalLine;

  @override
  Rect getBlockRect({bool shiftWithBaseOffset = false}) =>
      Offset.zero & (_box?.size ?? Size.zero);

  @override
  Rect? getCursorRectInPosition(
    Position position, {
    bool shiftWithBaseOffset = false,
  }) =>
      _box == null
          ? null
          : Rect.fromLTWH(
              position.offset == 0
                  ? 0
                  : (_box!.size.width - 2).clamp(0.0, double.infinity),
              0,
              2,
              _box!.size.height,
            );

  @override
  List<Rect> getRectsInSelection(
    Selection selection, {
    bool shiftWithBaseOffset = false,
  }) =>
      _box == null ? [] : [getBlockRect()];

  @override
  Selection getSelectionInRange(Offset start, Offset end) => Selection.single(
        path: node.path,
        startOffset: 0,
        endOffset: 1,
      );

  @override
  Offset localToGlobal(Offset offset, {bool shiftWithBaseOffset = false}) =>
      _box?.localToGlobal(offset) ?? offset;

  @override
  TextDirection textDirection() => Directionality.of(context);
}
