import 'package:appflowy_editor/appflowy_editor.dart';

/// Leaves text and range selections to AppFlowy's normal Enter handling.
Transaction? atomicBlockEnterTransaction(
  EditorState editor, {
  required bool Function(Node) isAtomicBlock,
  String text = '',
}) {
  final selection = editor.selection;
  if (selection == null || !selection.isCollapsed) return null;
  final position = selection.start;
  final node = editor.getNodeAtPath(position.path);
  if (node == null || !isAtomicBlock(node)) return null;
  final path = position.offset == 0 ? node.path : node.path.next;
  final transaction = editor.transaction;
  transaction.insertNode(path, paragraphNode(text: text));
  transaction.afterSelection =
      Selection.collapsed(Position(path: path, offset: text.length));
  transaction.selectionExtraInfo = {};
  transaction.customSelectionType = SelectionType.inline;
  return transaction;
}
