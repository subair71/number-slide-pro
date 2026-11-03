import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
// The mock native channel must use the same wire format as the Android plugin.
// ignore: implementation_imports
import 'package:google_mobile_ads/src/ad_instance_manager.dart' show AdMessageCodec;
import 'package:number_slide_pro/main.dart';
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
    tester.view.physicalSize = const Size(412, 915);
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
    expect(widths, [412]);
    expect(bannerIds, hasLength(1));
    expect(find.byType(AdWidget), findsNothing);
    await adEvent('onAdLoaded');
    expect(find.byType(AdWidget), findsOneWidget);
    expect(tester.getRect(find.byType(AdWidget)).height, 50);
    expect(tester.getBottomLeft(find.text('Watch Ad • +50 🪙')).dy,
        lessThan(tester.getTopLeft(find.byType(AdWidget)).dy));

    tester.view.physicalSize = const Size(915, 412);
    await tester.pump();
    await tester.pump();
    expect(widths, [412, 915]);
    expect(bannerIds, hasLength(2));
    expect(disposed, contains(bannerIds.first));
    await adEvent('onAdFailedToLoad', _NoFill());
    expect(find.byType(AdWidget), findsNothing);
    expect(disposed, contains(bannerIds.last));
    expect(find.text('New Game'), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}

class _NoFill extends LoadAdError {
  _NoFill() : super(3, 'test', 'No fill', null);
}
