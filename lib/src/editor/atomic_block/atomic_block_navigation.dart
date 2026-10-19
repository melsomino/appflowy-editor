import 'package:appflowy_editor/appflowy_editor.dart';

enum AtomicBlockArrow { left, right, up, down }

/// Shift moves the active end without normalizing/reversing the anchor.
Selection? atomicBlockArrowSelection(
  Document document,
  Selection selection,
  AtomicBlockArrow arrow, {
  required bool Function(Node) isAtomicBlock,
  bool extend = false,
  Position? verticalTarget,
}) {
  if (!extend && !selection.isCollapsed) return null;
  final target = atomicBlockCursorTarget(
    document,
    Selection.collapsed(extend ? selection.end : selection.start),
    arrow,
    isAtomicBlock: isAtomicBlock,
    verticalTarget: verticalTarget,
  );
  if (target == null) return null;
  return extend ? selection.copyWith(end: target) : Selection.collapsed(target);
}

/// Returns null when ordinary text navigation should handle the arrow.
Position? atomicBlockCursorTarget(
  Document document,
  Selection selection,
  AtomicBlockArrow arrow, {
  Position? verticalTarget,
  required bool Function(Node) isAtomicBlock,
}) {
  if (!selection.isCollapsed) return null;
  final position = selection.start;
  final node = document.nodeAtPath(position.path);
  if (node == null) return null;
  final backwards =
      arrow == AtomicBlockArrow.left || arrow == AtomicBlockArrow.up;
  bool navigable(Node node) => node.delta != null || isAtomicBlock(node);
  Node? neighbour() => backwards
      ? node.previousNodeWhere(navigable)
      : node.nextNodeWhere(navigable);
  Position? adjacentPosition() {
    final adjacent = neighbour();
    if (adjacent == null) return position;
    return Position(
      path: adjacent.path,
      offset: backwards ? adjacent.delta?.length ?? 1 : 0,
    );
  }

  if (isAtomicBlock(node)) {
    if (arrow == AtomicBlockArrow.left && position.offset > 0) {
      return Position(path: node.path);
    }
    if (arrow == AtomicBlockArrow.right && position.offset < 1) {
      return Position(path: node.path, offset: 1);
    }
    return adjacentPosition();
  }
  if (arrow == AtomicBlockArrow.up || arrow == AtomicBlockArrow.down) {
    final targetNode = verticalTarget == null
        ? null
        : document.nodeAtPath(verticalTarget.path);
    if (targetNode != null && isAtomicBlock(targetNode)) {
      return Position(path: targetNode.path, offset: backwards ? 1 : 0);
    }
    return null;
  }
  final atBoundary =
      backwards ? position.offset == 0 : position.offset == node.delta?.length;
  if (!atBoundary) return null;
  final adjacent = neighbour();
  if (adjacent == null || !isAtomicBlock(adjacent)) return null;
  return Position(path: adjacent.path, offset: backwards ? 1 : 0);
}
