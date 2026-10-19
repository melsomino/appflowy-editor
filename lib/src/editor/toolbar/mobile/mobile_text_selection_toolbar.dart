import 'dart:async';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:appflowy_editor/src/editor/toolbar/mobile/editor_system_context_menu.dart';
import 'package:flutter/material.dart';

/// Native iOS clipboard menu where supported; adaptive Flutter menu otherwise.
/// Host callbacks preserve custom rich clipboard handling when supplied.
class MobileTextSelectionToolbar extends StatelessWidget {
  const MobileTextSelectionToolbar({
    super.key,
    required this.editorState,
    required this.editorScrollController,
    required this.child,
    this.onCopy,
    this.onCut,
    this.onPaste,
    this.onSelectAll,
  });

  final EditorState editorState;
  final EditorScrollController editorScrollController;
  final Widget child;
  final VoidCallback? onCopy;
  final VoidCallback? onCut;
  final VoidCallback? onPaste;
  final VoidCallback? onSelectAll;

  void _selectAll() {
    final last = editorState.getLastSelectable();
    if (last == null || editorState.document.root.children.isEmpty) return;
    unawaited(
      editorState.updateSelectionWithReason(
        Selection(start: Position(path: [0]), end: last.$2.end(last.$1)),
        reason: SelectionUpdateReason.selectAll,
        extraInfo: {
          selectionExtraInfoDoNotAttachTextService:
              editorState.service.keyboardService?.isEditing != true,
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) => MobileFloatingToolbar(
        editorState: editorState,
        editorScrollController: editorScrollController,
        floatingToolbarHeight: 44,
        toolbarBuilder: (context, anchor, close) {
          final selection = editorState.selection;
          final editing =
              editorState.service.keyboardService?.isEditing == true;
          final labels = WidgetsLocalizations.of(context);
          VoidCallback command(
            VoidCallback action, {
            bool startEditing = false,
          }) =>
              () {
                if (startEditing) {
                  unawaited(
                    editorState.updateSelectionWithReason(
                      editorState.selection,
                      reason: SelectionUpdateReason.uiEvent,
                      extraInfo: {
                        selectionExtraInfoDoNotAttachTextService: false,
                        selectionExtraInfoDisableFloatingToolbar: true,
                      },
                    ),
                  );
                }
                action();
                close();
              };
          final items = [
            if (selection != null && !selection.isCollapsed) ...[
              ContextMenuButtonItem(
                label: labels.cutButtonLabel,
                type: ContextMenuButtonType.cut,
                onPressed: command(
                  onCut ?? () => handleCut(editorState),
                  startEditing: true,
                ),
              ),
              ContextMenuButtonItem(
                label: labels.copyButtonLabel,
                type: ContextMenuButtonType.copy,
                onPressed: command(() {
                  (onCopy ?? () => handleCopy(editorState))();
                  if (!editing) editorState.selection = null;
                }),
              ),
            ],
            ContextMenuButtonItem(
              label: labels.pasteButtonLabel,
              type: ContextMenuButtonType.paste,
              onPressed: command(
                onPaste ?? () => handlePaste(editorState),
                startEditing: true,
              ),
            ),
            ContextMenuButtonItem(
              label: labels.selectAllButtonLabel,
              type: ContextMenuButtonType.selectAll,
              onPressed: () {
                close();
                (onSelectAll ?? _selectAll)();
              },
            ),
          ];
          var lineBottom = anchor.dy;
          Rect? menuRect;
          for (final rect in editorState.selectionRects()) {
            if (rect.top == anchor.dy) {
              menuRect =
                  menuRect == null ? rect : menuRect.expandToInclude(rect);
              if (rect.bottom > lineBottom) lineBottom = rect.bottom;
            }
          }
          if (SystemContextMenu.isSupported(context)) {
            return EditorSystemContextMenu(
              editorState: editorState,
              anchor: menuRect ?? Rect.fromLTWH(anchor.dx, anchor.dy, 1, 1),
              items: items,
              onHide: close,
            );
          }
          return AdaptiveTextSelectionToolbar.buttonItems(
            anchors: TextSelectionToolbarAnchors(
              primaryAnchor: anchor - const Offset(0, 8),
              secondaryAnchor: Offset(anchor.dx, lineBottom + 24),
            ),
            buttonItems: items,
          );
        },
        child: child,
      );
}
