# Mobile text interaction

The selection service distinguishes viewing from editing through
`AppFlowyKeyboardService.isEditing`: editing means this editor owns an active
text input connection. Selecting text while viewing does not open the keyboard.

In viewing mode, a single tap waits for Flutter's double-tap timeout before
starting editing. A second tap cancels that pending action, so selecting a word
never briefly opens the keyboard. Taps while editing remain immediate.

| Gesture | Viewing | Editing |
| --- | --- | --- |
| Tap a word | Start editing at the nearest word boundary | Place the caret at the word end |
| Tap a word whose end already has the caret | Start editing | Place the caret at the exact tap position |
| Tap at the caret | Start editing | Request the clipboard menu |
| Long press and move | Select the initial word and extend selection across words | Move the caret continuously |
| Double tap | Select a word and preserve viewing | Select a word |
| Tap inside a range | Preserve the selection and menu | Collapse to the tapped word end |

The selection service marks ongoing gestures with
`selectionExtraInfoDisableFloatingToolbar`. Range menus appear after the
gesture ends, including when either selection handle is released. A collapsed
selection after a long press does not request a menu.

Wrap the editor in `MobileTextSelectionToolbar` for Cut/Copy/Paste/Select All.
On iOS devices that report system-menu support (iOS 16+), it uses
the package's UIKit `UIEditMenuInteraction` bridge with document-owned callbacks.
Paste uses `UIAction.Identifier.paste` and reads HTML inside that native action,
while iOS recognizes the user's paste intent. The authorized text/HTML payload
is passed directly to the document importer; cached editor blocks are retained
when their clipboard text still matches. No clipboard read occurs when opening
the menu. Commands run after dismissal so Select All can open its new menu.
The native payload also includes copied image bytes and image resources from
Safari web archives, with their source URLs. `EditorState.onPaste` lets a host
store external assets and translate them into its own block types before any
document mutation. Return `true` after handling the complete paste, or `false`
to use the editor's built-in paste path. The host owns downloading missing
resources, persistence, error reporting and cleanup of staged assets.
Other platforms use Flutter's adaptive toolbar with optional host callbacks.
The adaptive menu places itself below the text
and handles when there is insufficient space above it.

An iOS menu requires a text input connection. The keyboard service's paired
`beginSelectionMenuSession` / `endSelectionMenuSession` methods provide a
menu-only connection without showing the keyboard or reporting `isEditing`.
Viewing exposes only Copy and Select All. Cut and Paste are available only
while editing.
Closing the menu does not close an editing connection or clear the selection.

iOS selection handles use Flutter's standard Cupertino handle painter, sizes,
and anchor geometry, with a minimum 44-point touch target. Gesture handling,
word selection, cursor dragging and auto-scroll remain owned by the editor.

The iOS bridge is registered as an editor plugin. After adding or changing its
Swift code, rebuild the iOS app; a Dart hot reload does not install native code.

The pure helpers `mobileTextTapSelection` and `mobileWordDragSelection` implement
the position decisions without depending on rendering. UI platform decisions
use Flutter's target platform, so widget tests can exercise the actual iOS and
Android services using `TargetPlatformVariant`.
