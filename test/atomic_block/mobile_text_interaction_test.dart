import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Position position(int offset, {int paragraph = 0}) =>
      Position(path: [paragraph], offset: offset);
  Selection word(int start, int end, {int paragraph = 0}) => Selection(
        start: position(start, paragraph: paragraph),
        end: position(end, paragraph: paragraph),
      );

  test('viewing tap chooses the nearest word boundary', () {
    for (final offset in [1, 8]) {
      expect(
        mobileTextTapSelection(
          tapped: position(offset),
          word: word(0, 10),
          current: null,
          editing: false,
        ),
        Selection.collapsed(position(offset == 1 ? 0 : 10)),
      );
    }
  });

  test('editing tap chooses the end of a different word', () {
    expect(
      mobileTextTapSelection(
        tapped: position(13),
        word: word(11, 20),
        current: Selection.collapsed(position(10)),
        editing: true,
      ),
      Selection.collapsed(position(20)),
    );
  });

  test('caret inside or at either word boundary enables exact taps', () {
    for (final caret in [0, 5, 10]) {
      for (final tapped in [0, 3, 10]) {
        expect(
          mobileTextTapSelection(
            tapped: position(tapped),
            word: word(0, 10),
            current: Selection.collapsed(position(caret)),
            editing: true,
          ),
          Selection.collapsed(position(tapped)),
        );
      }
    }
  });

  test('a caret in another paragraph does not enable exact taps', () {
    expect(
      mobileTextTapSelection(
        tapped: position(3),
        word: word(0, 10),
        current: Selection.collapsed(position(5, paragraph: 1)),
        editing: true,
      ),
      Selection.collapsed(position(10)),
    );
  });

  test('a range selection does not enable exact taps', () {
    expect(
      mobileTextTapSelection(
        tapped: position(3),
        word: word(0, 10),
        current: word(0, 10),
        editing: true,
      ),
      Selection.collapsed(position(10)),
    );
  });

  test('tap at the caret preserves its position for the menu', () {
    final current = Selection.collapsed(position(3));
    expect(
      mobileTextTapSelection(
        tapped: position(3),
        word: word(0, 10),
        current: current,
        editing: true,
      ),
      current,
    );
  });

  test('non-text targets retain their exact tap position', () {
    expect(
      mobileTextTapSelection(
        tapped: position(1),
        word: null,
        current: null,
        editing: false,
      ),
      Selection.collapsed(position(1)),
    );
  });

  test('word drag extends in both directions and restores the anchor word', () {
    final anchor = word(10, 20);
    expect(mobileWordDragSelection(anchor, word(21, 30)), word(10, 30));
    expect(mobileWordDragSelection(anchor, word(0, 9)), word(20, 0));
    expect(mobileWordDragSelection(anchor, anchor), anchor);
    expect(
      mobileWordDragSelection(anchor, word(0, 9, paragraph: 1)),
      Selection(start: position(10), end: position(9, paragraph: 1)),
    );
  });
}
