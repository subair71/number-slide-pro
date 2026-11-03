import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
// The mock native channel must use the same wire format as the Android plugin.
// ignore: implementation_imports
import 'package:google_mobile_ads/src/ad_instance_manager.dart' show AdMessageCodec;
import 'package:number_slide_pro/main.dart';
import 'package:number_slide_pro/puzzle_board.dart';
import 'package:number_slide_pro/leaderboard.dart';
import 'package:number_slide_pro/leaderboard_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('The game renders before an online leaderboard is available', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.binding.defaultBinaryMessenger.setMockMessageHandler(
      'plugins.flutter.io/google_mobile_ads',
      (_) async => const StandardMethodCodec().encodeSuccessEnvelope(null),
    );
    await tester.pumpWidget(const PuzzleApp());
    await tester.pump();
    expect(find.text('Number Slide'), findsOneWidget);
    expect(find.text('PRO'), findsOneWidget);
    expect(find.text('New Game'), findsOneWidget);
  });

  testWidgets('The banner loads below the controls and releases its slot on no fill', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final messenger = tester.binding.defaultBinaryMessenger;
    final channel = MethodChannel('plugins.flutter.io/google_mobile_ads', StandardMethodCodec(AdMessageCodec()));
    final widths = <int>[];
    final bannerIds = <int>[];
    final disposed = <int>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'AdSize#getAnchoredAdaptiveBannerAdSize':
          widths.add(call.arguments['width'] as int);
          return 50;
        case 'loadBannerAd':
          expect(call.arguments['adUnitId'], 'ca-app-pub-3940256099942544/9214589741');
          bannerIds.add(call.arguments['adId'] as int);
        case 'disposeAd':
          disposed.add(call.arguments['adId'] as int);
      }
      return null;
    });
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, (_) async => null);

    Future<void> adEvent(String event, [LoadAdError? error]) async {
      await messenger.handlePlatformMessage(channel.name, channel.codec.encodeMethodCall(
        MethodCall('onAdEvent', {
          'adId': bannerIds.last,
          'eventName': event,
          if (error != null) 'loadAdError': error,
        }),
      ), null);
      await tester.pump();
    }

    await tester.pumpWidget(const PuzzleApp());
    await tester.pump();
    expect(widths, [390]);
    expect(bannerIds, hasLength(1));
    expect(find.byType(AdWidget), findsNothing);
    await adEvent('onAdLoaded');
    expect(find.byType(AdWidget), findsOneWidget);
    expect(tester.getRect(find.byType(AdWidget)).height, 50);
    expect(tester.getBottomLeft(find.text('Watch Ad · +50 coins')).dy,
        lessThan(tester.getTopLeft(find.byType(AdWidget)).dy));

    tester.view.physicalSize = const Size(844, 390);
    await tester.pump();
    await tester.pump();
    expect(widths, [390, 844]);
    expect(bannerIds, hasLength(2));
    expect(disposed, contains(bannerIds.first));
    await adEvent('onAdFailedToLoad', _NoFill());
    expect(find.byType(AdWidget), findsNothing);
    expect(disposed, contains(bannerIds.last));
    expect(find.text('New Game'), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('All five-by-five tiles fit, move into the gap, and respect reduced motion', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.binding.defaultBinaryMessenger.setMockMessageHandler(
      'plugins.flutter.io/google_mobile_ads', (_) async => const StandardMethodCodec().encodeSuccessEnvelope(null),
    );
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(const PuzzleApp());
    await tester.pump();
    await tester.tap(find.text('5×5'));
    await tester.pumpAndSettle();
    final board = tester.widget<PuzzleBoard>(find.byType(PuzzleBoard));
    expect(board.tiles.toSet(), {for (int i = 0; i < 25; i++) i});
    final empty = board.tiles.indexOf(0);
    final source = empty % 5 == 0 ? empty + 1 : empty - 1;
    final tile = board.tiles[source];
    final finder = find.byKey(ValueKey(tile));
    final origin = tester.getCenter(finder);
    expect(tester.getSize(finder).shortestSide, greaterThanOrEqualTo(48));
    await tester.tap(finder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 70));
    final midway = tester.getCenter(finder);
    await tester.pump(const Duration(milliseconds: 90));
    final landed = tester.getCenter(finder);
    expect((midway - origin).distance, greaterThan(0));
    expect((midway - origin).distance, lessThan((landed - origin).distance));
    expect(tester.widget<PuzzleBoard>(find.byType(PuzzleBoard)).tiles[empty], tile);

    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pump();
    await tester.tap(finder);
    await tester.pump();
    expect(tester.widget<AnimatedPositioned>(finder).duration, Duration.zero);
    expect(tester.getCenter(finder), origin);

    for (final viewport in [const Size(844, 390), const Size(320, 568)]) {
      tester.view.physicalSize = viewport;
      await tester.pumpAndSettle();
      for (final n in [10, 24]) {
        expect(tester.getSize(find.byKey(ValueKey(n))).shortestSide, greaterThanOrEqualTo(48));
      }
      await tester.ensureVisible(find.text('Watch Ad · +50 coins'));
      expect(find.text('Watch Ad · +50 coins').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('Leaderboard tabs replace the feed and distinguish cached, empty and personal scores', (tester) async {
    final feeds = <int, StreamController<Standings>>{};
    addTearDown(() async {
      for (final feed in feeds.values) { await feed.close(); }
    });
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: LeaderboardSheet(initialSize: 4,
      watch: (n) => (feeds[n] = StreamController<Standings>()).stream))));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    feeds[4]!.add(const Standings(entries: [], cached: false));
    await tester.pumpAndSettle();
    expect(find.text('No scores yet'), findsOneWidget);
    await tester.tap(find.text('5×5'));
    await tester.pump();
    expect(find.text('No scores yet'), findsNothing);
    feeds[5]!.add(const Standings(entries: [], cached: true));
    await tester.pumpAndSettle();
    expect(find.text('Waiting for a connection'), findsOneWidget);
    feeds[5]!.add(const Standings(entries: [(name: 'Player A', score: 2200, mine: true)], cached: true));
    await tester.pumpAndSettle();
    expect(find.text('YOU'), findsOneWidget);
    expect(find.text('2200'), findsOneWidget);
    expect(find.text('SAVED STANDINGS'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _NoFill extends LoadAdError {
  _NoFill() : super(3, 'test', 'No fill', null);
}
