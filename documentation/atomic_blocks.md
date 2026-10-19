# Atomic blocks

An atomic block is a leaf without a text Delta. It has two caret positions:
offset `0` before the block and offset `1` after it. Node types and payload
attributes belong to the embedding application; these APIs do not introduce
a new document format.

## Editing and keyboard input

Create one `AtomicBlockKeyboardInput` for the editor with an explicit predicate:

```dart
final atomicInput = AtomicBlockKeyboardInput(
  isAtomicBlock: (node) => node.type == 'custom_media',
);
```

Prepend `atomicInput.commandShortcutEvents` and
`atomicInput.characterShortcutEvents` to the corresponding standard shortcut
lists passed to `AppFlowyEditor`. Call `atomicInput.register(editorState)` once
the keyboard service has mounted. Re-register after replacing the editor state;
registration automatically detaches from the previous service. Call
`atomicInput.dispose()` when the host is disposed.

The handlers provide:

- Arrow navigation across both edges, including Shift selection that keeps its
  original anchor.
- Enter or typing at either edge creates an adjacent paragraph.
- Backspace before an atomic block moves to the preceding block's end.
- Backspace at the beginning of text following an atomic block moves to that
  block's trailing edge. These caret-only moves create no undo entry.

Ranges, normal text editing, and Backspace at an atomic block's trailing edge
continue through the editor's standard handlers. Unregistered types are not
treated as atomic blocks.

`AtomicBlockComponentBuilder` supplies selection geometry and edge tap targets
for custom content. Pass the editor state, focus node, content builder, and a
node validator, then register it under your custom type in
`blockComponentBuilders`. The outer fifth on each side places the caret; the
centre remains available to the content's gestures. Use it together with the
keyboard handlers above.

Custom components may request an empty IME buffer with
`editorState.service.keyboardService?.enableKeyboardForAtomicBlock()` after
placing the caret. Access to the keyboard widget's internal state is unnecessary.

## Inserting blocks

`atomicBlockInsertTransaction` inserts a caller-supplied node. At a text cursor,
it splits the text and enclosing lists while retaining formatting and custom
attributes. The inserted block stays at the document root. A null position
appends without selecting; an explicit `appendIndex` can leave an application
placeholder after the block. The host applies the transaction and controls
history grouping and persistence.

## Drag helpers

These helpers can be used with a host's custom drag surface:

- `blockDropIndex` selects an insertion slot from the moving block's edges and
  the previous slot. Neighbour indices exclude the dragged node. Upward motion
  crosses in the upper 40 percent; downward motion crosses in the lower 40
  percent. The host should commit the selected index without recalculating it
  from the pointer on release.
- `blockDragBounds` progressively resists overshoot at either document edge.
- `BlockGapAnimation` animates neighbouring paint offsets while their layout
  remains at the authoritative drop geometry.

The helpers do not replace the standard page renderer or drag implementation.
Toolbars, drag activation gestures, content appearance and screen transitions
remain under the host's control.
