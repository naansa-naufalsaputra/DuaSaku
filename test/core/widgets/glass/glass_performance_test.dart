import 'package:duasaku_app/core/theme/liquid_glass_theme.dart';
import 'package:duasaku_app/core/widgets/glass/glass_card.dart';
import 'package:duasaku_app/core/widgets/glass/glass_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Custom matcher: verifies that a Finder finds at most [n] widgets.
Matcher _findsAtMost(int n) => _FindsAtMostMatcher(n);

class _FindsAtMostMatcher extends Matcher {
  final int maxCount;
  const _FindsAtMostMatcher(this.maxCount);

  @override
  bool matches(dynamic item, Map matchState) {
    final finder = item as Finder;
    final count = finder.evaluate().length;
    return count <= maxCount;
  }

  @override
  Description describe(Description description) =>
      description.add('finds at most $maxCount widget(s)');

  @override
  Description describeMismatch(
    dynamic item,
    Description mismatchDescription,
    Map matchState,
    bool verbose,
  ) {
    final finder = item as Finder;
    final count = finder.evaluate().length;
    return mismatchDescription.add('found $count widget(s)');
  }
}

/// Helper to wrap a widget in a MaterialApp with LiquidGlassTheme registered.
Widget _buildApp(Widget child) {
  return MaterialApp(
    theme: ThemeData.dark().copyWith(
      extensions: [LiquidGlassTheme.defaultPurpleDark()],
    ),
    home: Scaffold(body: child),
  );
}

void main() {
  group('GPU Performance Constraints', () {
    // -------------------------------------------------------------------------
    // Requirement 13.1: Max 3 BackdropFilter layers per screen composition
    // -------------------------------------------------------------------------
    group('max 3 BackdropFilter layers per screen', () {
      testWidgets(
        'screen with 3 GlassSurface widgets (enableBlur: true) has at most 3 BackdropFilters',
        (tester) async {
          await tester.pumpWidget(
            _buildApp(
              const Column(
                children: [
                  Expanded(
                    child: GlassSurface(
                      enableBlur: true,
                      child: Text('Surface 1'),
                    ),
                  ),
                  Expanded(
                    child: GlassSurface(
                      enableBlur: true,
                      child: Text('Surface 2'),
                    ),
                  ),
                  Expanded(
                    child: GlassSurface(
                      enableBlur: true,
                      child: Text('Surface 3'),
                    ),
                  ),
                ],
              ),
            ),
          );

          final backdropFilters = find.byType(BackdropFilter);
          expect(
            backdropFilters,
            _findsAtMost(3),
            reason:
                'Requirement 13.1: Max 3 simultaneous BackdropFilter layers per screen',
          );
        },
      );

      testWidgets(
        'mixing enableBlur true/false keeps BackdropFilter count within limit',
        (tester) async {
          await tester.pumpWidget(
            _buildApp(
              const Column(
                children: [
                  Expanded(
                    child: GlassSurface(
                      enableBlur: true,
                      child: Text('Blur 1'),
                    ),
                  ),
                  Expanded(
                    child: GlassSurface(
                      enableBlur: false,
                      child: Text('No Blur'),
                    ),
                  ),
                  Expanded(
                    child: GlassSurface(
                      enableBlur: true,
                      child: Text('Blur 2'),
                    ),
                  ),
                  Expanded(
                    child: GlassSurface(
                      enableBlur: true,
                      child: Text('Blur 3'),
                    ),
                  ),
                  Expanded(
                    child: GlassSurface(
                      enableBlur: false,
                      child: Text('No Blur 2'),
                    ),
                  ),
                ],
              ),
            ),
          );

          final backdropFilters = find.byType(BackdropFilter);
          expect(
            backdropFilters,
            _findsAtMost(3),
            reason:
                'Requirement 13.1: Only enableBlur: true surfaces produce BackdropFilter; '
                'total should not exceed 3',
          );
        },
      );
    });

    // -------------------------------------------------------------------------
    // Requirement 13.5: GlassCard in scrollable list — no BackdropFilter
    // -------------------------------------------------------------------------
    group('GlassCard in scrollable list renders without BackdropFilter', () {
      testWidgets(
        'GlassCard with enableBlur: false in ListView has no BackdropFilter',
        (tester) async {
          await tester.pumpWidget(
            _buildApp(
              ListView.builder(
                itemCount: 5,
                itemBuilder: (context, index) {
                  return GlassCard(
                    enableBlur: false,
                    child: Text('Item $index'),
                  );
                },
              ),
            ),
          );

          // No BackdropFilter should exist in the entire tree since all
          // GlassCards use enableBlur: false (scroll performance optimization).
          expect(
            find.byType(BackdropFilter),
            findsNothing,
            reason:
                'Requirement 13.5: GlassCards in scrollable lists must not use '
                'BackdropFilter for scroll performance',
          );
        },
      );

      testWidgets(
        'multiple GlassCards with enableBlur: false in CustomScrollView have no BackdropFilter',
        (tester) async {
          await tester.pumpWidget(
            _buildApp(
              CustomScrollView(
                slivers: [
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        return GlassCard(
                          enableBlur: false,
                          child: Text('Sliver Item $index'),
                        );
                      },
                      childCount: 5,
                    ),
                  ),
                ],
              ),
            ),
          );

          expect(
            find.byType(BackdropFilter),
            findsNothing,
            reason:
                'Requirement 13.5: GlassCards in CustomScrollView must not use '
                'BackdropFilter',
          );
        },
      );
    });

    // -------------------------------------------------------------------------
    // Requirement 13.2: RepaintBoundary around GlassSurface instances
    // -------------------------------------------------------------------------
    group('RepaintBoundary is present around GlassSurface instances', () {
      testWidgets(
        'GlassSurface with enableBlur: true wraps in RepaintBoundary',
        (tester) async {
          await tester.pumpWidget(
            _buildApp(
              const GlassSurface(
                enableBlur: true,
                child: Text('Content'),
              ),
            ),
          );

          // GlassSurface wraps its output in RepaintBoundary for GPU isolation.
          final repaintBoundaries = find.descendant(
            of: find.byType(GlassSurface),
            matching: find.byType(RepaintBoundary),
          );
          expect(
            repaintBoundaries,
            findsAtLeast(1),
            reason:
                'Requirement 13.2: GlassSurface must wrap in RepaintBoundary '
                'for GPU isolation',
          );
        },
      );

      testWidgets(
        'GlassSurface with enableBlur: false still wraps in RepaintBoundary',
        (tester) async {
          await tester.pumpWidget(
            _buildApp(
              const GlassSurface(
                enableBlur: false,
                child: Text('Content'),
              ),
            ),
          );

          final repaintBoundaries = find.descendant(
            of: find.byType(GlassSurface),
            matching: find.byType(RepaintBoundary),
          );
          expect(
            repaintBoundaries,
            findsAtLeast(1),
            reason:
                'Requirement 13.2: RepaintBoundary must be present regardless '
                'of blur state',
          );
        },
      );

      testWidgets(
        'GlassCard wraps in RepaintBoundary for GPU isolation',
        (tester) async {
          await tester.pumpWidget(
            _buildApp(
              const GlassCard(
                enableBlur: true,
                child: Text('Card Content'),
              ),
            ),
          );

          final repaintBoundaries = find.descendant(
            of: find.byType(GlassCard),
            matching: find.byType(RepaintBoundary),
          );
          expect(
            repaintBoundaries,
            findsAtLeast(1),
            reason:
                'Requirement 13.2: GlassCard must include RepaintBoundary '
                'for GPU isolation',
          );
        },
      );
    });

    // -------------------------------------------------------------------------
    // Requirement 13.5 (enableBlur: false path): No BackdropFilter in tree
    // -------------------------------------------------------------------------
    group('enableBlur: false path produces no BackdropFilter', () {
      testWidgets(
        'GlassSurface with enableBlur: false has no BackdropFilter',
        (tester) async {
          await tester.pumpWidget(
            _buildApp(
              const GlassSurface(
                enableBlur: false,
                child: Text('No blur'),
              ),
            ),
          );

          expect(
            find.descendant(
              of: find.byType(GlassSurface),
              matching: find.byType(BackdropFilter),
            ),
            findsNothing,
            reason:
                'enableBlur: false must not produce any BackdropFilter widget',
          );
        },
      );

      testWidgets(
        'GlassSurface with enableBlur: true DOES have BackdropFilter',
        (tester) async {
          await tester.pumpWidget(
            _buildApp(
              const GlassSurface(
                enableBlur: true,
                child: Text('With blur'),
              ),
            ),
          );

          expect(
            find.descendant(
              of: find.byType(GlassSurface),
              matching: find.byType(BackdropFilter),
            ),
            findsOneWidget,
            reason:
                'enableBlur: true must produce exactly one BackdropFilter widget',
          );
        },
      );

      testWidgets(
        'GlassCard with enableBlur: false has no BackdropFilter',
        (tester) async {
          await tester.pumpWidget(
            _buildApp(
              const GlassCard(
                enableBlur: false,
                child: Text('No blur card'),
              ),
            ),
          );

          expect(
            find.descendant(
              of: find.byType(GlassCard),
              matching: find.byType(BackdropFilter),
            ),
            findsNothing,
            reason:
                'GlassCard with enableBlur: false must not produce BackdropFilter',
          );
        },
      );

      testWidgets(
        'GlassCard with enableBlur: true DOES have BackdropFilter',
        (tester) async {
          await tester.pumpWidget(
            _buildApp(
              const GlassCard(
                enableBlur: true,
                child: Text('With blur card'),
              ),
            ),
          );

          expect(
            find.descendant(
              of: find.byType(GlassCard),
              matching: find.byType(BackdropFilter),
            ),
            findsOneWidget,
            reason:
                'GlassCard with enableBlur: true must produce BackdropFilter',
          );
        },
      );
    });
  });
}
