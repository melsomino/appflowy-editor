import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:appflowy_editor/appflowy_editor.dart';

class AppFlowyClipboardImage {
  const AppFlowyClipboardImage({required this.bytes, this.source});
  factory AppFlowyClipboardImage.fromMap(Map<Object?, Object?> data) =>
      AppFlowyClipboardImage(
        bytes: data['bytes']! as Uint8List,
        source: data['source'] as String?,
      );
  final Uint8List bytes;
  final String? source;
}

class AppFlowyClipboardData {
  const AppFlowyClipboardData({
    this.text,
    this.html,
    this.nodes,
    this.images = const [],
  });
  final String? text;
  final String? html;
  final List<Node>? nodes;
  final List<AppFlowyClipboardImage> images;
}

class AppFlowyClipboard {
  static AppFlowyClipboardData? _mockData;
  static AppFlowyClipboardData? _localData;

  @visibleForTesting
  static String? lastText;

  static Future<void> setData({
    String? text,
    String? html,
    List<Node>? nodes,
  }) async {
    if (text == null) {
      return;
    }

    lastText = text;
    _localData = null;

    await Clipboard.setData(
      ClipboardData(
        text: text,
      ),
    );
    _localData = AppFlowyClipboardData(
      text: text,
      html: html,
      nodes: nodes?.map((node) => node.deepCopy()).toList(),
    );
  }

  static Future<AppFlowyClipboardData> getData() async {
    if (_mockData != null) {
      return _mockData!;
    }

    final data = await Clipboard.getData(Clipboard.kTextPlain);
    return fromSystemData(text: data?.text);
  }

  /// Read native HTML and images for an explicit user-initiated paste command.
  /// iOS may request clipboard access when invoked outside its Paste menu.
  static Future<AppFlowyClipboardData> getRichData() async {
    if (_mockData != null) return _mockData!;
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      return getData();
    }
    final data = await const MethodChannel('appflowy_editor/selection_menu')
        .invokeMapMethod<Object?, Object?>('readClipboard');
    if (data?['archiveError'] case final String error) {
      throw FormatException('Could not read clipboard web archive: $error');
    }
    final images = data?['images'] as List<Object?>? ?? const [];
    return fromSystemData(
      text: data?['text'] as String?,
      html: data?['html'] as String?,
      images: [
        for (final image in images)
          AppFlowyClipboardImage.fromMap(image! as Map<Object?, Object?>),
      ],
    );
  }

  /// Combine native formats with editor-owned blocks only while text matches.
  /// Native menu payloads are already authorized; do not read the buffer again.
  static AppFlowyClipboardData fromSystemData({
    String? text,
    String? html,
    List<AppFlowyClipboardImage> images = const [],
  }) {
    if (text != _localData?.text || images.isNotEmpty) _localData = null;
    return AppFlowyClipboardData(
      text: text,
      html: _localData?.html ?? html,
      nodes: _localData?.nodes?.map((node) => node.deepCopy()).toList(),
      images: images,
    );
  }

  @visibleForTesting
  static void mockSetData(AppFlowyClipboardData? data) {
    _mockData = data;
  }
}
