import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mermaid/flutter_mermaid.dart';

void main() {
  group('TimelineParser', () {
    test('parses basic timeline', () {
      const source = '''
timeline
    title History of Social Media Platform
    2002 : LinkedIn
    2004 : Facebook
         : Google
    2005 : Youtube
    2006 : Twitter
''';

      final parser = TimelineParser();
      final result = parser.parse(source.split('\n').skip(1).toList());

      expect(result, isNotNull);
      expect(result!.$1.type, DiagramType.timeline);
      expect(result.$1.title, 'History of Social Media Platform');
      expect(result.$2.title, 'History of Social Media Platform');
      expect(result.$2.sections, isNotEmpty);
    });

    test('parses timeline with sections', () {
      const source = '''
timeline
    2002 : LinkedIn
    2004 : Facebook
    2005 : Youtube
''';

      final parser = TimelineParser();
      final result = parser.parse(source.split('\n').skip(1).toList());

      expect(result, isNotNull);
      final sections = result!.$2.sections;
      expect(sections.length, greaterThan(0));

      // Check first section
      expect(sections.first.title, '2002');
      expect(sections.first.events.length, 1);
      expect(sections.first.events.first.title, 'LinkedIn');
    });

    test('parses timeline with multiple events in one period', () {
      const source = '''
timeline
    2004 : Facebook
         : Google
         : MySpace
''';

      final parser = TimelineParser();
      final result = parser.parse(source.split('\n').skip(1).toList());

      expect(result, isNotNull);
      final sections = result!.$2.sections;
      expect(sections.length, 1);
      expect(sections.first.title, '2004');
      expect(sections.first.events.length, 3);
      expect(sections.first.events[0].title, 'Facebook');
      expect(sections.first.events[1].title, 'Google');
      expect(sections.first.events[2].title, 'MySpace');
    });

    test('parses timeline without title', () {
      const source = '''
timeline
    2002 : LinkedIn
    2004 : Facebook
''';

      final parser = TimelineParser();
      final result = parser.parse(source.split('\n').skip(1).toList());

      expect(result, isNotNull);
      expect(result!.$2.title, isNull);
      expect(result.$2.sections, isNotEmpty);
    });

    test('handles empty timeline', () {
      const source = '''
timeline
    title Empty Timeline
''';

      final parser = TimelineParser();
      final result = parser.parse(source.split('\n').skip(1).toList());

      expect(result, isNull);
    });

    test('parses timeline with date ranges', () {
      const source = '''
timeline
    title Technology Evolution
    1970-1980 : Personal Computing Era
    1990-2000 : Internet Revolution
    2000-2010 : Mobile Era
    2010-2020 : Cloud Computing
''';

      final parser = TimelineParser();
      final result = parser.parse(source.split('\n').skip(1).toList());

      expect(result, isNotNull);
      expect(result!.$2.sections.length, 4);
      expect(result.$2.sections[0].title, '1970-1980');
      expect(result.$2.sections[0].events.first.title, 'Personal Computing Era');
    });

    test('parses complex timeline', () {
      const source = '''
timeline
    title History of Programming Languages
    1950s : Fortran
          : LISP
    1960s : COBOL
          : BASIC
    1970s : C
          : SQL
    1980s : C++
          : Perl
    1990s : Python
          : Java
          : JavaScript
    2000s : C#
          : Go
    2010s : Rust
          : Swift
          : Kotlin
''';

      final parser = TimelineParser();
      final result = parser.parse(source.split('\n').skip(1).toList());

      expect(result, isNotNull);
      expect(result!.$2.title, 'History of Programming Languages');
      expect(result.$2.sections.length, greaterThanOrEqualTo(6));

      // Verify some sections
      final events1990s = result.$2.sections
          .firstWhere((s) => s.title == '1990s')
          .events;
      expect(events1990s.length, 3);
      expect(events1990s.map((e) => e.title).toList(),
          containsAll(['Python', 'Java', 'JavaScript']));
    });

    test('parses timeline with text descriptions', () {
      const source = '''
timeline
    title Product Releases
    Q1 2024 : Feature A
    Q2 2024 : Feature B
              Major update
    Q3 2024 : Feature C
''';

      final parser = TimelineParser();
      final result = parser.parse(source.split('\n').skip(1).toList());

      expect(result, isNotNull);
      expect(result!.$2.sections.length, greaterThan(0));
    });

    test('ignores empty lines and whitespace', () {
      const source = '''
timeline
    title Test Timeline

    2020 : Event 1

    2021 : Event 2

''';

      final parser = TimelineParser();
      final result = parser.parse(source.split('\n').skip(1).toList());

      expect(result, isNotNull);
      expect(result!.$2.sections.length, 2);
    });
  });
}
