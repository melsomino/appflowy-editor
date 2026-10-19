import 'dart:ui';

typedef BlockDropBounds = ({int index, Rect rect});

/// Indices exclude the dragged block. Direction is relative to the last slot,
/// not to the pointer or the preceding movement event.
int blockDropIndex(
  Rect dragged,
  List<BlockDropBounds> blocks, {
  required int currentIndex,
  required Rect slot,
}) {
  if (blocks.isEmpty || dragged.top == slot.top) return currentIndex;
  final upwards = dragged.top < slot.top;
  final edge = upwards ? dragged.top : dragged.bottom;
  for (final block in blocks) {
    if (edge >= block.rect.top && edge < block.rect.bottom) {
      final fraction = (edge - block.rect.top) / block.rect.height;
      return upwards
          ? (fraction < 0.4 ? block.index : block.index + 1)
          : (fraction >= 0.6 ? block.index + 1 : block.index);
    }
  }
  if (edge < blocks.first.rect.top) return blocks.first.index;
  if (edge >= blocks.last.rect.bottom) return blocks.last.index + 1;
  return currentIndex;
}
