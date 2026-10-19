import 'package:appflowy_editor/appflowy_editor.dart';

/// Handle the two caret boundaries immediately before/after an attachment.
/// Ranges and its trailing edge retain normal deletion behaviour.
Transaction? atomicBlockBackspaceTransaction(
  EditorState editor, {
  required bool Function(Node) isAtomicBlock,
}) {
  final selection = editor.selection;
  if (selection == null ||
      !selection.isCollapsed ||
      selection.start.offset != 0) {
    return null;
  }
  final node = editor.getNodeAtPath(selection.start.path);
  if (node == null) return null;
  final previous = node.previousNodeWhere(
    (candidate) => candidate.delta != null || isAtomicBlock(candidate),
  );
  final transaction = editor.transaction;
  transaction.afterSelection = selection;
  if (!isAtomicBlock(node)) {
    if (node.delta == null || previous == null || !isAtomicBlock(previous)) {
      return null;
    }
    transaction.afterSelection = Selection.collapsed(
      Position(path: previous.path, offset: 1),
    );
    transaction.customSelectionType = SelectionType.inline;
    return transaction;
  }
  if (previous == null) return transaction;
  transaction.afterSelection = Selection.collapsed(
    Position(path: previous.path, offset: previous.delta?.length ?? 1),
  );
  transaction.customSelectionType = SelectionType.inline;
  return transaction;
}
