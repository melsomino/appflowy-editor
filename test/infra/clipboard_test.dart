import 'package:appflowy_editor/appflowy_editor.dart' show Node;
import 'package:appflowy_editor/src/infra/clipboard.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_test/flutter_test.dart';

class MockClipboard {
  const MockClipboard({required this.text, required this.html});
  final String? text;
  final String? html;

  MockClipboard copyWith({
    String? text,
    String? html,
  }) =>
      MockClipboard(
        text: text,
        html: html,
      );

  Map<String, String?> get getData => {"html": html, "text": text};
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockClipboard mockClipboard;

  setUp(() {
    mockClipboard = const MockClipboard(html: null, text: null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (message) async {
      switch (message.method) {
        case "Clipboard.getData":
          return mockClipboard.text == null ? null : mockClipboard.getData;

        case "Clipboard.setData":
          final args = message.arguments as Map<String, dynamic>;
          mockClipboard = mockClipboard.copyWith(
            text: args['text'],
          );
      }

      return null;
    });
  });

  group('Clipboard tests', () {
    group('explicit rich paste on iOS', () {
      const channel = MethodChannel('appflowy_editor/selection_menu');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

      setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.iOS);
      tearDown(() {
        debugDefaultTargetPlatformOverride = null;
        messenger.setMockMethodCallHandler(channel, null);
      });

      test('reads HTML and cached image bytes without a second text read',
          () async {
        var reads = 0;
        final bytes = Uint8List.fromList([1, 2, 3]);
        messenger.setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'readClipboard');
          reads++;
          return {
            'text': 'Rich',
            'html':
                '<p><strong>Rich</strong><img src="https://example.com/a.png"></p>',
            'images': [
              {'bytes': bytes, 'source': 'https://example.com/a.png'},
            ],
          };
        });
        messenger.setMockMethodCallHandler(SystemChannels.platform,
            (call) async {
          fail('Rich paste must read every representation together');
        });
        final data = await AppFlowyClipboard.getRichData();
        expect(reads, 1);
        expect(data.text, 'Rich');
        expect(data.html, contains('<strong>Rich</strong>'));
        expect(data.images.single.bytes, bytes);
        expect(data.images.single.source, 'https://example.com/a.png');
      });

      test('preserves copied editor blocks while native text still matches',
          () async {
        await AppFlowyClipboard.setData(
          text: 'Copied',
          nodes: [
            Node(type: 'test_password', attributes: {'content': 'payload'}),
          ],
        );
        messenger.setMockMethodCallHandler(
          channel,
          (_) async => {'text': 'Copied'},
        );
        final data = await AppFlowyClipboard.getRichData();
        expect(data.nodes!.single.type, 'test_password');
        expect(data.nodes!.single.attributes['content'], 'payload');
      });

      test('reads an image-only clipboard and clears stale local blocks',
          () async {
        await AppFlowyClipboard.setData(text: '', nodes: [Node(type: 'old')]);
        final bytes = Uint8List.fromList([4, 5, 6]);
        messenger.setMockMethodCallHandler(
          channel,
          (_) async => {
            'images': [
              {'bytes': bytes},
            ],
          },
        );
        final data = await AppFlowyClipboard.getRichData();
        expect(data.nodes, isNull);
        expect(data.images.single.bytes, bytes);
      });

      test('reports invalid web archive data', () async {
        messenger.setMockMethodCallHandler(
          channel,
          (_) async => {'archiveError': 'Invalid property list'},
        );
        await expectLater(
          AppFlowyClipboard.getRichData(),
          throwsFormatException,
        );
      });
    });

    test('native image bytes and source are passed through the clipboard', () {
      final bytes = Uint8List.fromList([1, 2, 3]);
      final image = AppFlowyClipboardImage.fromMap({
        'bytes': bytes,
        'source': 'https://example.com/image.png',
      });
      final data = AppFlowyClipboard.fromSystemData(images: [image]);
      expect(data.images.single.bytes, bytes);
      expect(data.images.single.source, 'https://example.com/image.png');
      expect(data.nodes, isNull);
    });
    test('native paste uses authorized HTML without reading clipboard again',
        () async {
      await AppFlowyClipboard.setData(text: 'Plain text');
      var readCount = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.getData') readCount++;
        return null;
      });
      final data = AppFlowyClipboard.fromSystemData(
        text: 'External',
        html: '<p><b>External</b></p>',
      );
      expect(data.html, '<p><b>External</b></p>');
      expect(readCount, 0);
    });

    test('native data retains editor HTML only while clipboard text matches',
        () async {
      await AppFlowyClipboard.setData(
        text: 'Bold',
        html: '<p><strong>Bold</strong></p>',
      );
      expect(
        AppFlowyClipboard.fromSystemData(text: 'Bold').html,
        '<p><strong>Bold</strong></p>',
      );
      expect(AppFlowyClipboard.fromSystemData().html, isNull);
    });

    test('retains rich text until the system clipboard changes', () async {
      const html = '<p><strong>Bold</strong></p>';
      await AppFlowyClipboard.setData(text: 'Bold', html: html);
      expect((await AppFlowyClipboard.getData()).html, html);
      await Clipboard.setData(const ClipboardData(text: 'External'));
      expect((await AppFlowyClipboard.getData()).html, isNull);
    });
    test('AppFlowyClipboardData constructor', () {
      const data = AppFlowyClipboardData();

      expect(data.text, null);
      expect(data.html, null);
    });

    testWidgets('AppFlowyClipboard setData and getData', (tester) async {
      const rawText = "Hello World";

      AppFlowyClipboardData? clipboardData;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.windows),
          home: Column(
            children: [
              TextButton(
                onPressed: () async => AppFlowyClipboard.setData(text: rawText),
                child: const Text('setData'),
              ),
              TextButton(
                onPressed: () async =>
                    clipboardData = await AppFlowyClipboard.getData(),
                child: const Text('getData'),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('setData'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('getData'));
      await tester.pumpAndSettle();

      expect(clipboardData?.text, rawText);
    });
  });
}
