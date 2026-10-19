import 'dart:async';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:appflowy_editor/src/editor/toolbar/mobile/editor_native_menu.dart';
import 'package:flutter/material.dart';

/// Platform-rendered iOS menu with callbacks owned by the document editor.
class EditorSystemContextMenu extends StatefulWidget {
  const EditorSystemContextMenu({
    super.key,
    required this.editorState,
    required this.anchor,
    required this.items,
    required this.onHide,
  });

  final EditorState editorState;
  final Rect anchor;
  final List<ContextMenuButtonItem> items;
  final VoidCallback onHide;

  @override
  State<EditorSystemContextMenu> createState() =>
      _EditorSystemContextMenuState();
}

class _EditorSystemContextMenuState extends State<EditorSystemContextMenu> {
  final _menu = EditorNativeMenu();
  late final AppFlowyKeyboardService _keyboard;

  @override
  void initState() {
    super.initState();
    final keyboard = widget.editorState.service.keyboardService;
    if (keyboard == null) {
      throw StateError('System menu requires a keyboard service');
    }
    _keyboard = keyboard;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_showMenu());
    });
  }

  Future<void> _showMenu() async {
    if (!mounted) return;
    _keyboard.beginSelectionMenuSession();
    final result = await _menu.show(widget.anchor, widget.items);
    if (!mounted) return;
    final index = result?['index'] as int?;
    final item = index == null ? null : widget.items[index];
    final editor = widget.editorState;
    final clipboard = result?['clipboard'] as Map<Object?, Object?>?;
    widget.onHide();
    if (clipboard?['archiveError'] case final String error) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: FormatException(error),
          context: ErrorDescription('reading Safari clipboard resources'),
        ),
      );
    }
    // UIKit finishes dismissing the old menu before a command changes the
    // selection and potentially opens a replacement (for example Select All).
    if (item?.type == ContextMenuButtonType.paste && clipboard != null) {
      unawaited(
        editor.updateSelectionWithReason(
          editor.selection,
          reason: SelectionUpdateReason.uiEvent,
          extraInfo: {
            selectionExtraInfoDoNotAttachTextService: false,
            selectionExtraInfoDisableFloatingToolbar: true,
          },
        ),
      );
      await handlePaste(
        editor,
        data: AppFlowyClipboard.fromSystemData(
          text: clipboard['text'] as String?,
          html: clipboard['html'] as String?,
          images: [
            for (final value in clipboard['images'] as List<Object?>? ?? [])
              AppFlowyClipboardImage.fromMap(
                value! as Map<Object?, Object?>,
              ),
          ],
        ),
      );
    } else {
      item?.onPressed?.call();
    }
  }

  @override
  void dispose() {
    unawaited(_menu.hide());
    _keyboard.endSelectionMenuSession();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
