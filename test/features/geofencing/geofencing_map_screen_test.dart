import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:duasaku_app/features/geofencing/presentation/screens/geofencing_map_screen.dart';
import 'package:duasaku_app/features/geofencing/domain/geofence_hotspot.dart';

// Simple Test Localization Loader
class TestAssetLoader extends AssetLoader {
  const TestAssetLoader();

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async {
    return {
      'profile': {'geofencing_alerts': 'Hotspot Alerts'},
      'error': {'general': 'An error occurred.'},
    };
  }
}

Widget buildTestWidget({
  required List<GeofenceHotspot> hotspots,
  bool isLoading = false,
  bool isError = false,
}) {
  return EasyLocalization(
    supportedLocales: const [Locale('en')],
    path: 'assets/translations',
    assetLoader: const TestAssetLoader(),
    fallbackLocale: const Locale('en'),
    startLocale: const Locale('en'),
    child: Builder(
      builder: (context) {
        return ProviderScope(
          overrides: [
            geofencingMapHotspotsProvider.overrideWith((ref) {
              if (isLoading) {
                final completer = Completer<List<GeofenceHotspot>>();
                return completer.future;
              }
              if (isError) {
                throw Exception('Test Database error');
              }
              return hotspots;
            }),
          ],
          child: MaterialApp(
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            locale: context.locale,
            home: const GeofencingMapScreen(),
          ),
        );
      },
    ),
  );
}

void main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  await EasyLocalization.ensureInitialized();

  group('GeofencingMapScreen Widget Tests', () {
    testWidgets('renders loading indicator when state is loading', (
      tester,
    ) async {
      await tester.pumpWidget(
        EasyLocalization(
          supportedLocales: const [Locale('en')],
          path: 'assets/translations',
          assetLoader: const TestAssetLoader(),
          fallbackLocale: const Locale('en'),
          startLocale: const Locale('en'),
          child: Builder(
            builder: (context) {
              return ProviderScope(
                overrides: [
                  geofencingMapHotspotsProvider.overrideWith((ref) {
                    final completer = Completer<List<GeofenceHotspot>>();
                    return completer.future;
                  }),
                ],
                child: MaterialApp(
                  localizationsDelegates: context.localizationDelegates,
                  supportedLocales: context.supportedLocales,
                  locale: context.locale,
                  home: const GeofencingMapScreen(),
                ),
              );
            },
          ),
        ),
      );

      // Wait for EasyLocalization to finish loading translations
      await tester.pump();
      await tester.idle();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify progress indicator is displayed
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('renders error text when provider throws an error', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget(hotspots: [], isError: true));
      await tester.pump(); // Start easy_localization load
      await tester.idle();
      await tester.pumpAndSettle();

      expect(find.text('An error occurred.'), findsOneWidget);
    });

    testWidgets('renders empty placeholder when no hotspots are detected', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget(hotspots: []));
      await tester.pump();
      await tester.idle();
      await tester.pumpAndSettle();

      expect(find.text('No spending hotspots detected yet.'), findsOneWidget);
      expect(
        find.textContaining('Spend money at 3+ locations'),
        findsOneWidget,
      );
      expect(find.byType(FlutterMap), findsNothing);
    });

    testWidgets('renders map and markers when hotspots are detected', (
      tester,
    ) async {
      final mockHotspots = [
        const GeofenceHotspot(
          id: 'hotspot_1',
          latitude: -6.200000,
          longitude: 106.816666,
          name: 'Grand Indonesia Mall',
        ),
      ];

      await tester.pumpWidget(buildTestWidget(hotspots: mockHotspots));
      await tester.pump();
      await tester.idle();
      await tester.pumpAndSettle();

      // Verify map is displayed
      expect(find.byType(FlutterMap), findsOneWidget);
      // Verify hotspot location marker is visible
      expect(find.byIcon(Icons.location_on_rounded), findsOneWidget);
    });

    testWidgets(
      'tapping location marker displays hotspot details bottom sheet',
      (tester) async {
        final mockHotspots = [
          const GeofenceHotspot(
            id: 'hotspot_1',
            latitude: -6.200000,
            longitude: 106.816666,
            name: 'Grand Indonesia Mall',
          ),
        ];

        await tester.pumpWidget(buildTestWidget(hotspots: mockHotspots));
        await tester.pump();
        await tester.idle();
        await tester.pumpAndSettle();

        // Tap location marker
        await tester.tap(find.byIcon(Icons.location_on_rounded));
        await tester.pumpAndSettle(); // Wait for bottom sheet presentation

        // Verify bottom sheet title and text
        expect(find.text('Grand Indonesia Mall'), findsOneWidget);
        expect(find.text('Spending Warning Zone'), findsOneWidget);
        expect(
          find.textContaining('Radius: 150m from centroid'),
          findsOneWidget,
        );
        expect(find.textContaining('Latitude: -6.200000'), findsOneWidget);
        expect(find.textContaining('Longitude: 106.816666'), findsOneWidget);

        // Close bottom sheet
        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();

        // Verify bottom sheet has closed
        expect(find.text('Spending Warning Zone'), findsNothing);
      },
    );
  });
}
