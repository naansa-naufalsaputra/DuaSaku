import 'package:flutter_test/flutter_test.dart';
import 'package:duasaku_app/core/utils/local_date_parser.dart';

void main() {
  group('LocalDateParser Tests', () {
    // 17 June 2026 is a Wednesday (ref.weekday == 3)
    final ref = DateTime(2026, 6, 17, 10, 30);

    test('should parse relative dates with typos correctly', () {
      expect(
        LocalDateParser.parse('hari ini', referenceDate: ref),
        DateTime(2026, 6, 17, 10, 30),
      );
      expect(
        LocalDateParser.parse('sekarang', referenceDate: ref),
        DateTime(2026, 6, 17, 10, 30),
      );
      expect(
        LocalDateParser.parse('kemarin', referenceDate: ref),
        DateTime(2026, 6, 16, 10, 30),
      );
      expect(
        LocalDateParser.parse('kemaren', referenceDate: ref),
        DateTime(2026, 6, 16, 10, 30),
      );
      expect(
        LocalDateParser.parse('lusa', referenceDate: ref),
        DateTime(2026, 6, 19, 10, 30),
      );
      expect(
        LocalDateParser.parse('kemarin lusa', referenceDate: ref),
        DateTime(2026, 6, 15, 10, 30),
      );
      expect(
        LocalDateParser.parse('kemaren lusa', referenceDate: ref),
        DateTime(2026, 6, 15, 10, 30),
      );
    });

    test('should parse abbreviated time anchors correctly', () {
      expect(
        LocalDateParser.parse('tadi pagi', referenceDate: ref),
        DateTime(2026, 6, 17, 8, 0),
      );
      expect(
        LocalDateParser.parse('td pagi', referenceDate: ref),
        DateTime(2026, 6, 17, 8, 0),
      );
      expect(
        LocalDateParser.parse('tadi siang', referenceDate: ref),
        DateTime(2026, 6, 17, 12, 0),
      );
      expect(
        LocalDateParser.parse('td siang', referenceDate: ref),
        DateTime(2026, 6, 17, 12, 0),
      );
      expect(
        LocalDateParser.parse('tadi sore', referenceDate: ref),
        DateTime(2026, 6, 17, 16, 0),
      );
      expect(
        LocalDateParser.parse('td sore', referenceDate: ref),
        DateTime(2026, 6, 17, 16, 0),
      );
      expect(
        LocalDateParser.parse('tadi malam', referenceDate: ref),
        DateTime(2026, 6, 16, 20, 0),
      );
      expect(
        LocalDateParser.parse('td malam', referenceDate: ref),
        DateTime(2026, 6, 16, 20, 0),
      );
    });

    test('should parse days / weeks / months ago patterns correctly', () {
      expect(
        LocalDateParser.parse('2 hari lalu', referenceDate: ref),
        DateTime(2026, 6, 15, 10, 30),
      );
      expect(
        LocalDateParser.parse('3 minggu kemaren', referenceDate: ref),
        DateTime(2026, 5, 27, 10, 30),
      );
      expect(
        LocalDateParser.parse('1 bulan yang lalu', referenceDate: ref),
        DateTime(2026, 5, 17, 10, 30),
      );
      expect(
        LocalDateParser.parse('minggu lalu', referenceDate: ref),
        DateTime(2026, 6, 10, 10, 30),
      );
      expect(
        LocalDateParser.parse('bulan kemaren', referenceDate: ref),
        DateTime(2026, 5, 17, 10, 30),
      );
    });

    test('should parse closest past weekdays correctly', () {
      // Wednesday (ref.weekday == 3)
      expect(
        LocalDateParser.parse('rabu', referenceDate: ref),
        DateTime(2026, 6, 17, 10, 30),
      );
      expect(
        LocalDateParser.parse('selasa', referenceDate: ref),
        DateTime(2026, 6, 16, 10, 30),
      );
      expect(
        LocalDateParser.parse('senin', referenceDate: ref),
        DateTime(2026, 6, 15, 10, 30),
      );
      expect(
        LocalDateParser.parse('kamis', referenceDate: ref),
        DateTime(2026, 6, 11, 10, 30),
      );
      expect(
        LocalDateParser.parse('jumat', referenceDate: ref),
        DateTime(2026, 6, 12, 10, 30),
      );
      expect(
        LocalDateParser.parse('sabtu', referenceDate: ref),
        DateTime(2026, 6, 13, 10, 30),
      );
      expect(
        LocalDateParser.parse('minggu', referenceDate: ref),
        DateTime(2026, 6, 14, 10, 30),
      );
    });

    test('should parse numeric formats correctly', () {
      expect(
        LocalDateParser.parse('12/06/2026', referenceDate: ref),
        DateTime(2026, 6, 12, 12, 0),
      );
      expect(
        LocalDateParser.parse('12-06', referenceDate: ref),
        DateTime(2026, 6, 12, 12, 0),
      );
      expect(
        LocalDateParser.parse('12.06.2026', referenceDate: ref),
        DateTime(2026, 6, 12, 12, 0),
      );
      expect(
        LocalDateParser.parse('12/06/26', referenceDate: ref),
        DateTime(2026, 6, 12, 12, 0),
      );
    });

    test('should parse Indonesian named months correctly', () {
      expect(
        LocalDateParser.parse('12 Juni', referenceDate: ref),
        DateTime(2026, 6, 12, 12, 0),
      );
      expect(
        LocalDateParser.parse('12 Juni 2026', referenceDate: ref),
        DateTime(2026, 6, 12, 12, 0),
      );
      expect(
        LocalDateParser.parse('12 jun', referenceDate: ref),
        DateTime(2026, 6, 12, 12, 0),
      );
      expect(
        LocalDateParser.parse('12 des', referenceDate: ref),
        DateTime(2026, 12, 12, 12, 0),
      );
    });
  });
}
