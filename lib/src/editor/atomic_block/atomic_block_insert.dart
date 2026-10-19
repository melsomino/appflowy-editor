import 'package:appflowy_editor/appflowy_editor.dart';

/// Insert an atomic block at the root, splitting enclosing text/list nodes.
/// A null [position] appends without selecting. [appendIndex] lets the host
/// keep its own trailing placeholders after the inserted block.
Transaction atomicBlockInsertTransaction(
  EditorState editor,
  Node block, {
  required bool Function(Node) isAtomicBlock,
  Position? position,
  int? appendIndex,
}) {
  if (!isAtomicBlock(block) ||
      block.delta != null ||
      block.children.isNotEmpty) {
    throw ArgumentError.value(block, 'block', 'Expected an atomic leaf block');
  }
  final transaction = editor.transaction;
  var index = appendIndex ?? editor.document.root.children.length;
  if (index < 0 || index > editor.document.root.children.length) {
    throw RangeError.range(
      index,
      0,
      editor.document.root.children.length,
      'appendIndex',
    );
  }
  if (position != null) {
    final node = editor.getNodeAtPath(position.path);
    if (node == null) throw StateError('Block insertion cursor is stale');
    index = position.path.first;
    if (isAtomicBlock(node)) {
      if (position.offset > 0) index++;
    } else {
      final root = editor.document.root.children.elementAt(index);
      final parts =
          _splitTextTree(root, position.path.skip(1).toList(), position.offset);
      transaction.insertNodes(
        [index],
        [
          if (parts.before != null) parts.before!,
          block,
          if (parts.after != null) parts.after!,
        ],
      );
      transaction.deleteNode(root);
      if (parts.before != null) index++;
      transaction.afterSelection =
          Selection.collapsed(Position(path: [index], offset: 1));
      transaction.customSelectionType = SelectionType.inline;
      return transaction;
    }
  }
  transaction.insertNode([index], block);
  transaction.afterSelection = position == null
      ? null
      : Selection.collapsed(Position(path: [index], offset: 1));
  transaction.customSelectionType = SelectionType.inline;
  return transaction;
}

/// Replace a selection with clipboard blocks, preserving text on both sides.
/// Unlike text-only paste, atomic leaves must remain separate root blocks.
Transaction atomicBlockPasteTransaction(EditorState editor, List<Node> nodes) {
  if (nodes.isEmpty) throw ArgumentError.value(nodes, 'nodes', 'Empty paste');
  final selection = editor.selection?.normalized;
  if (selection == null) throw StateError('Paste requires a selection');
  final roots = editor.document.root.children.toList();
  final first = selection.start.path.first;
  final last = selection.end.path.first;

  Node? before(Position position) {
    final root = roots[position.path.first];
    if (root.delta == null) {
      return position.offset == 0 ? null : root.copyWith();
    }
    return _splitTextTree(root, position.path.skip(1).toList(), position.offset)
        .before;
  }

  Node? after(Position position) {
    final root = roots[position.path.first];
    if (root.delta == null) {
      return position.offset == 0 ? root.copyWith() : null;
    }
    return _splitTextTree(root, position.path.skip(1).toList(), position.offset)
        .after;
  }

  final prefix = before(selection.start);
  final suffix = after(selection.end);
  final inserted = nodes.map((node) => node.deepCopy()).toList();
  final index = first + (prefix == null ? 0 : 1) + inserted.length - 1;
  final transaction = editor.transaction;
  transaction.insertNodes([
    first,
  ], [
    if (prefix != null) prefix,
    ...inserted,
    if (suffix != null) suffix,
  ]);
  for (final node in roots.sublist(first, last + 1)) {
    transaction.deleteNode(node);
  }
  transaction.afterSelection = Selection.collapsed(
    Position(path: [index], offset: inserted.last.delta?.length ?? 1),
  );
  transaction.customSelectionType = SelectionType.inline;
  return transaction;
}

/// Split enclosing lists as well, keeping attachments at the document root.
({Node? before, Node? after}) _splitTextTree(Node node, Path path, int offset) {
  final delta = node.delta;
  if (delta == null) throw StateError('Expected text at attachment insertion');
  if (path.isEmpty) {
    if (offset < 0 || offset > delta.length) {
      throw RangeError.range(offset, 0, delta.length, 'offset');
    }
    return (
      before: offset == 0
          ? null
          : node.copyWith(
              attributes: {
                ...node.attributes,
                'delta': delta.slice(0, offset).toJson(),
              },
              children: [],
            ),
      after: offset == delta.length && node.children.isEmpty
          ? null
          : node.copyWith(
              attributes: {
                ...node.attributes,
                'delta': delta.slice(offset).toJson(),
              },
            ),
    );
  }
  final children = node.children.map((child) => child.copyWith()).toList();
  final index = path.first;
  final split = _splitTextTree(children[index], path.skip(1).toList(), offset);
  final before = [
    ...children.take(index),
    if (split.before != null) split.before!,
  ];
  final after = [
    if (split.after != null) split.after!,
    ...children.skip(index + 1),
  ];
  return (
    before: delta.isEmpty && before.isEmpty
        ? null
        : node.copyWith(children: before),
    after: after.isEmpty
        ? null
        : node.copyWith(
            attributes: {...node.attributes, 'delta': Delta().toJson()},
            children: after,
          ),
  );
}
