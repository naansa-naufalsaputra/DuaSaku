import 'package:duasaku_app/features/goals/presentation/widgets/goal_progress_bar.dart';
import 'package:duasaku_app/features/goals/presentation/widgets/milestone_marker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Helper to wrap GoalProgressBar in a MaterialApp with constrained size.
Widget buildTestWidget({
  required double progress,
  Set<int> notifiedMilestones = const {},
  double width = 300.0,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: width,
          child: GoalProgressBar(
            progress: progress,
            notifiedMilestones: notifiedMilestones,
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('GoalProgressBar rendering', () {
    testWidgets('renders with 0% progress', (tester) async {
      await tester.pumpWidget(buildTestWidget(progress: 0.0));
      await tester.pumpAndSettle();

      expect(find.byType(GoalProgressBar), findsOneWidget);
    });

    testWidgets('renders with 50% progress', (tester) async {
      await tester.pumpWidget(buildTestWidget(progress: 0.5));
      await tester.pumpAndSettle();

      expect(find.byType(GoalProgressBar), findsOneWidget);
    });

    testWidgets('renders with 100% progress', (tester) async {
      await tester.pumpWidget(buildTestWidget(progress: 1.0));
      await tester.pumpAndSettle();

      expect(find.byType(GoalProgressBar), findsOneWidget);
    });
  });

  group('MilestoneMarker presence and state', () {
    testWidgets('displays 4 milestone markers at 25/50/75/100%', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget(progress: 0.5));
      await tester.pumpAndSettle();

      expect(find.byType(MilestoneMarker), findsNWidgets(4));
    });

    testWidgets('at 0% progress, no milestones are reached', (tester) async {
      await tester.pumpWidget(buildTestWidget(progress: 0.0));
      await tester.pumpAndSettle();

      // All 4 markers should exist but none should be in reached state
      final markers = tester.widgetList<MilestoneMarker>(
        find.byType(MilestoneMarker),
      );
      for (final marker in markers) {
        expect(
          marker.isReached,
          isFalse,
          reason: 'Milestone ${marker.milestone}% should not be reached',
        );
      }
    });

    testWidgets('at 50% progress, 25% and 50% milestones are reached', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget(progress: 0.5));
      await tester.pumpAndSettle();

      final markers = tester.widgetList<MilestoneMarker>(
        find.byType(MilestoneMarker),
      );
      for (final marker in markers) {
        if (marker.milestone <= 50) {
          expect(
            marker.isReached,
            isTrue,
            reason: 'Milestone ${marker.milestone}% should be reached',
          );
        } else {
          expect(
            marker.isReached,
            isFalse,
            reason: 'Milestone ${marker.milestone}% should not be reached',
          );
        }
      }
    });

    testWidgets('at 100% progress, all milestones are reached', (tester) async {
      await tester.pumpWidget(buildTestWidget(progress: 1.0));
      await tester.pumpAndSettle();

      final markers = tester.widgetList<MilestoneMarker>(
        find.byType(MilestoneMarker),
      );
      for (final marker in markers) {
        expect(
          marker.isReached,
          isTrue,
          reason: 'Milestone ${marker.milestone}% should be reached',
        );
      }
    });

    testWidgets(
      'milestone markers show correct reached state based on progress',
      (tester) async {
        // At 75% progress: 25, 50, 75 reached; 100 not reached
        await tester.pumpWidget(buildTestWidget(progress: 0.75));
        await tester.pumpAndSettle();

        final markers = tester.widgetList<MilestoneMarker>(
          find.byType(MilestoneMarker),
        );
        for (final marker in markers) {
          if (marker.milestone <= 75) {
            expect(
              marker.isReached,
              isTrue,
              reason: 'Milestone ${marker.milestone}% should be reached',
            );
          } else {
            expect(
              marker.isReached,
              isFalse,
              reason: 'Milestone ${marker.milestone}% should not be reached',
            );
          }
        }
      },
    );
  });

  group('Celebration animation at 100%', () {
    testWidgets(
      'at 100% with unnotified milestones, celebration animation triggers',
      (tester) async {
        // When isReached=true and isNotified=false, the celebration animation
        // plays on MilestoneMarker. We verify this by checking that all markers
        // are reached and not notified (which triggers the animate chain).
        await tester.pumpWidget(
          buildTestWidget(progress: 1.0, notifiedMilestones: {}),
        );
        // Pump a few frames to start animations
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        final markers = tester.widgetList<MilestoneMarker>(
          find.byType(MilestoneMarker),
        );
        for (final marker in markers) {
          expect(marker.isReached, isTrue);
          expect(
            marker.isNotified,
            isFalse,
            reason: 'Milestone ${marker.milestone}% should trigger celebration',
          );
        }
      },
    );

    testWidgets(
      'at 100% with all milestones already notified, no celebration triggers',
      (tester) async {
        await tester.pumpWidget(
          buildTestWidget(progress: 1.0, notifiedMilestones: {25, 50, 75, 100}),
        );
        await tester.pumpAndSettle();

        final markers = tester.widgetList<MilestoneMarker>(
          find.byType(MilestoneMarker),
        );
        for (final marker in markers) {
          expect(marker.isReached, isTrue);
          expect(
            marker.isNotified,
            isTrue,
            reason:
                'Milestone ${marker.milestone}% already notified — no celebration',
          );
        }
      },
    );
  });
}
