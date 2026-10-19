import 'package:appflowy_editor/appflowy_editor.dart';

/// Resolve a tap without depending on rendering or keyboard widgets.
Selection mobileTextTapSelection({
  required Position tapped,
  required Selection? word,
  required Selection? current,
  required bool editing,
}) {
  if (editing && current?.isCollapsed == true && current!.start == tapped) {
    return current;
  }
  if (word == null || !word.isSingle) return Selection.collapsed(tapped);
  final boundary = word.normalized;
  if (editing) {
    return Selection.collapsed(
      current?.isCollapsed == true &&
              current!.start.path.equals(boundary.start.path) &&
              current.start.offset >= boundary.start.offset &&
              current.start.offset <= boundary.end.offset
          ? tapped
          : boundary.end,
    );
  }
  return Selection.collapsed(
    tapped.offset - boundary.start.offset < boundary.end.offset - tapped.offset
        ? boundary.start
        : boundary.end,
  );
}

/// Extend from the original word, preserving it when the drag reverses.
Selection mobileWordDragSelection(Selection anchor, Selection word) {
  final initial = anchor.normalized;
  final target = word.normalized;
  if (target.end.path > initial.end.path ||
      target.end.path.equals(initial.end.path) &&
          target.end.offset > initial.end.offset) {
    return Selection(start: initial.start, end: target.end);
  }
  if (target.start.path < initial.start.path ||
      target.start.path.equals(initial.start.path) &&
          target.start.offset < initial.start.offset) {
    return Selection(start: initial.end, end: target.start);
  }
  return initial;
}
