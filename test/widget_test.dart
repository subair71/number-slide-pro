import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
// The mock native channel must use the same wire format as the Android plugin.
// ignore: implementation_imports
import 'package:google_mobile_ads/src/ad_instance_manager.dart' show AdMessageCodec;
import 'package:number_slide_pro/main.dart';
import 'package:number_slide_pro/run_results.dart';
import 'package:number_slide_pro/vault_items.dart';
import 'package:number_slide_pro/theme_vault.dart';
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

  testWidgets('Solving the daily puzzle sweeps the board and only pays the daily reward once', (tester) async {
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
    await tester.tap(find.text('3×3'));
    await tester.pump();
    await tester.tap(find.text('Daily Challenge'));
    await tester.pumpAndSettle();
    final route = _solution(tester.widget<PuzzleBoard>(find.byType(PuzzleBoard)).tiles);
    final prefs = await SharedPreferences.getInstance();
    for (int round = 0; round < 2; round++) {
      if (round == 1) {
        tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
        addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
        await tester.pump();
      }
      for (int step = 0; step < route.length; step++) {
        await tester.tap(find.byKey(ValueKey(route[step])));
        await tester.pump();
        if (step + 1 < route.length) {
          await tester.pump(const Duration(milliseconds: 170));
        }
      }
      if (round == 0) {
        await tester.pump(const Duration(milliseconds: 240));
        expect(find.byType(RunResults), findsNothing);
      }
      await tester.pumpAndSettle();
      final result = tester.widget<RunResults>(find.byType(RunResults)).run;
      expect(result.moves, route.length);
      expect(result.coins, round == 0 ? 100 : 0);
      expect(result.gems, round == 0 ? 25 : 0);
      expect(PlayerProgress.read(prefs).coins, 100);
      expect(PlayerProgress.read(prefs).gems, 25);
      expect(prefs.getInt('best_3'), 900 - route.length * 5);
      await tester.scrollUntilVisible(find.text('Next Puzzle'), 350,
        scrollable: find.descendant(of: find.byKey(const Key('results-scroll')), matching: find.byType(Scrollable)).first);
      await tester.tap(find.text('Next Puzzle'));
      await tester.pumpAndSettle();
      if (round == 0) {
        await tester.ensureVisible(find.text('Daily Challenge'));
        await tester.tap(find.text('Daily Challenge'));
        await tester.pumpAndSettle();
      }
    }
    // No Firebase platform channel responds in this widget test.
    await tester.pump(const Duration(seconds: 9));
  });

  testWidgets('Vault previews a locked skin and charges only once when equipped', (tester) async {
    SharedPreferences.setMockInitialValues({'coins': 900});
    tester.binding.defaultBinaryMessenger.setMockMessageHandler(
      'plugins.flutter.io/google_mobile_ads', (_) async => const StandardMethodCodec().encodeSuccessEnvelope(null));
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(const PuzzleApp());
    await tester.pumpAndSettle();
    final prefs = await SharedPreferences.getInstance();
    await tester.tap(find.text('SHOP'));
    await tester.pumpAndSettle();
    expect(find.text('THEME VAULT'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Synthwave Sunset'), 160, scrollable:
      find.descendant(of: find.byKey(const Key('vault-list')), matching: find.byType(Scrollable)).first);
    await tester.tap(find.text('Synthwave Sunset'));
    await tester.pump();
    await tester.tap(find.text('Preview on Board'));
    await tester.pumpAndSettle();
    expect(tester.widget<PuzzleBoard>(find.byType(PuzzleBoard)).skin.id, 'sunset');
    expect(PlayerProgress.read(prefs).coins, 900);
    await tester.tap(find.textContaining('Back to vault'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Equip Theme ✓'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unlock & Equip'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Equip Theme ✓'));
    await tester.pumpAndSettle();
    final saved = PlayerProgress.read(prefs);
    expect(saved.active(VaultTab.skins).id, 'sunset');
    expect(saved.coins, 100);
    await tester.tap(find.byTooltip('Close vault'));
    await tester.pumpAndSettle();
    expect(find.byType(ThemeVault), findsNothing);
    expect(tester.widget<PuzzleBoard>(find.byType(PuzzleBoard)).skin.id, 'sunset');
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

List<int> _solution(List<int> board) {
  const goal = '123456780';
  final start = board.join();
  final next = {goal: goal};
  final queue = [goal];
  for (int cursor = 0; !next.containsKey(start); cursor++) {
    final state = queue[cursor];
    final gap = state.indexOf('0');
    for (final pos in [if (gap % 3 > 0) gap - 1, if (gap % 3 < 2) gap + 1,
      if (gap >= 3) gap - 3, if (gap < 6) gap + 3]) {
      final cells = state.split('');
      cells[gap] = cells[pos];
      cells[pos] = '0';
      final previous = cells.join();
      if (next.containsKey(previous)) continue;
      next[previous] = state;
      queue.add(previous);
    }
  }
  final moves = <int>[];
  for (var state = start; state != goal; state = next[state]!) {
    moves.add(int.parse(state[next[state]!.indexOf('0')]));
  }
  return moves;
}
