import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// UIKit reads rich clipboard formats inside its user-initiated Paste action.
class EditorNativeMenu {
  static const channel = MethodChannel('appflowy_editor/selection_menu');
  static int _nextSession = 0;
  final int _session = _nextSession++;
  bool _showing = false;

  Future<Map<Object?, Object?>?> show(
    Rect anchor,
    List<ContextMenuButtonItem> items,
  ) async {
    _showing = true;
    try {
      return await channel.invokeMapMethod<Object?, Object?>('show', {
        'session': _session,
        'anchor': [anchor.left, anchor.top, anchor.width, anchor.height],
        'items': [
          for (final item in items)
            {'title': item.label!, 'type': item.type.name},
        ],
      });
    } finally {
      _showing = false;
    }
  }

  Future<void> hide() async {
    if (!_showing) return;
    await channel.invokeMethod<void>('hide', {'session': _session});
  }
}
