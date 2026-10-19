import 'dart:async';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Supplies an empty IME buffer while the caret is beside an atomic attachment.
class AtomicBlockKeyboardInput extends AppFlowyKeyboardServiceInterceptor {
  AtomicBlockKeyboardInput({required this.isAtomicBlock});

  final bool Function(Node) isAtomicBlock;
  AppFlowyKeyboardService? _keyboard;

  void register(EditorState editor) {
    final keyboard = editor.service.keyboardService;
    if (keyboard == null) {
      throw StateError('Atomic block keyboard service is unavailable');
    }
    if (!identical(_keyboard, keyboard)) {
      _keyboard?.unregisterInterceptor(this);
      _keyboard = keyboard;
      keyboard.registerInterceptor(this);
    }
  }

  void show(EditorState editor) {
    final keyboard = editor.service.keyboardService;
    if (keyboard == null) {
      throw StateError('Atomic block keyboard service is unavailable');
    }
    register(editor);
    keyboard.enableKeyboardForAtomicBlock();
  }

  /// Prepend these handlers to the standard editor shortcuts.
  List<CommandShortcutEvent> get commandShortcutEvents => [
        CommandShortcutEvent(
          key: 'Backspace before atomic block',
          getDescription: () => 'Move to previous block end',
          command: 'backspace, shift+backspace',
          handler: (editor) {
            final transaction = atomicBlockBackspaceTransaction(
              editor,
              isAtomicBlock: isAtomicBlock,
            );
            if (transaction == null) return KeyEventResult.ignored;
            unawaited(
              applyBackspace(
                editor,
                transaction,
              ),
            );
            return KeyEventResult.handled;
          },
        ),
        CommandShortcutEvent(
          key: 'Insert paragraph beside atomic block',
          getDescription: () => 'Insert paragraph beside atomic block',
          command: 'enter',
          handler: (editor) {
            final transaction = atomicBlockEnterTransaction(
              editor,
              isAtomicBlock: isAtomicBlock,
            );
            if (transaction == null) return KeyEventResult.ignored;
            unawaited(editor.apply(transaction));
            return KeyEventResult.handled;
          },
        ),
        for (final arrow in AtomicBlockArrow.values)
          for (final extend in [false, true])
            CommandShortcutEvent(
              key: 'Move around atomic block ${arrow.name} extend=$extend',
              getDescription: () => 'Move cursor ${arrow.name}',
              command: '${extend ? 'shift+' : ''}arrow ${arrow.name}',
              handler: (editor) {
                final selection = editor.selection;
                if (selection == null || (!extend && !selection.isCollapsed)) {
                  return KeyEventResult.ignored;
                }
                final active = extend ? selection.end : selection.start;
                final current = editor.getNodeAtPath(active.path);
                final vertical = arrow == AtomicBlockArrow.up ||
                    arrow == AtomicBlockArrow.down;
                final target = atomicBlockArrowSelection(
                  editor.document,
                  selection,
                  arrow,
                  isAtomicBlock: isAtomicBlock,
                  extend: extend,
                  verticalTarget:
                      vertical && current != null && !isAtomicBlock(current)
                          ? active.moveVertical(
                              editor,
                              upwards: arrow == AtomicBlockArrow.up,
                            )
                          : null,
                );
                if (target == null) return KeyEventResult.ignored;
                editor.updateSelectionWithReason(
                  target,
                  reason: SelectionUpdateReason.uiEvent,
                );
                return KeyEventResult.handled;
              },
            ),
      ];

  List<CharacterShortcutEvent> get characterShortcutEvents => [
        CharacterShortcutEvent(
          key: 'Insert paragraph beside atomic block',
          character: '\n',
          handler: (editor) async {
            final transaction = atomicBlockEnterTransaction(
              editor,
              isAtomicBlock: isAtomicBlock,
            );
            if (transaction == null) return false;
            await editor.apply(transaction);
            return true;
          },
        ),
      ];

  void dispose() => _keyboard?.unregisterInterceptor(this);

  Future<void> applyBackspace(
    EditorState editor,
    Transaction transaction,
  ) async {
    if (transaction.operations.isNotEmpty) {
      await editor.apply(transaction);
    } else if (transaction.afterSelection != editor.selection) {
      unawaited(
        editor.updateSelectionWithReason(
          transaction.afterSelection,
          reason: SelectionUpdateReason.uiEvent,
        ),
      );
    }
    final position = editor.selection?.end;
    final node = position == null ? null : editor.getNodeAtPath(position.path);
    if (node != null && isAtomicBlock(node)) {
      final keyboard = editor.service.keyboardService;
      if (keyboard == null) {
        throw StateError('Atomic block keyboard service is unavailable');
      }
      keyboard.enableKeyboardForAtomicBlock();
    }
  }

  Future<bool> _insert(EditorState editor, String text) async {
    final transaction = atomicBlockEnterTransaction(
      editor,
      isAtomicBlock: isAtomicBlock,
      text: text == '\n' || text == ' \n' ? '' : text,
    );
    if (transaction == null) return false;
    await editor.apply(transaction);
    return true;
  }

  @override
  Future<bool> interceptInsert(
    TextEditingDeltaInsertion insertion,
    EditorState editorState,
    List<CharacterShortcutEvent> characterShortcutEvents,
  ) =>
      _insert(editorState, insertion.textInserted);

  @override
  Future<bool> interceptDelete(
    TextEditingDeltaDeletion deletion,
    EditorState editorState,
  ) async {
    final transaction = atomicBlockBackspaceTransaction(
      editorState,
      isAtomicBlock: isAtomicBlock,
    );
    if (transaction == null) return false;
    await applyBackspace(editorState, transaction);
    return true;
  }

  @override
  Future<bool> interceptReplace(
    TextEditingDeltaReplacement replacement,
    EditorState editorState,
    List<CharacterShortcutEvent> characterShortcutEvents,
  ) =>
      _insert(editorState, replacement.replacementText);
}
