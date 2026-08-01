import 'package:app/core/utils/text_direction_detector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TextDirectionDetector.detect', () {
    test('detects pure Arabic text as RTL', () {
      expect(
        TextDirectionDetector.detect('مراجعة المشروع'),
        TextDirection.rtl,
      );
    });

    test('detects pure English text as LTR', () {
      expect(
        TextDirectionDetector.detect('Finish the report'),
        TextDirection.ltr,
      );
    });

    test('uses first strong character when text is mixed (Arabic first)', () {
      expect(
        TextDirectionDetector.detect('مراجعة Flutter app'),
        TextDirection.rtl,
      );
    });

    test('uses first strong character when text is mixed (English first)', () {
      expect(
        TextDirectionDetector.detect('Flutter مراجعة'),
        TextDirection.ltr,
      );
    });

    test('skips neutral characters (digits/punctuation) to find first strong char', () {
      expect(
        TextDirectionDetector.detect('123 - مهمة عاجلة'),
        TextDirection.rtl,
      );
    });

    test('falls back to ltr for text with no strong characters', () {
      expect(
        TextDirectionDetector.detect('123 456'),
        TextDirection.ltr,
      );
    });

    test('respects a custom fallback direction', () {
      expect(
        TextDirectionDetector.detect('123', fallback: TextDirection.rtl),
        TextDirection.rtl,
      );
    });

    test('returns fallback for null or empty text', () {
      expect(TextDirectionDetector.detect(null), TextDirection.ltr);
      expect(TextDirectionDetector.detect(''), TextDirection.ltr);
    });

    test('isRtl helper works as expected', () {
      expect(TextDirectionDetector.isRtl('مرحبا'), isTrue);
      expect(TextDirectionDetector.isRtl('hello'), isFalse);
    });
  });
}