import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class GameBanner extends StatefulWidget {
  const GameBanner({super.key, required this.width});

  final int width;

  @override
  State<GameBanner> createState() => _GameBannerState();
}

class _GameBannerState extends State<GameBanner> {
  static const _unitId = kReleaseMode
      ? String.fromEnvironment('ADMOB_ANDROID_BANNER_UNIT_ID')
      : 'ca-app-pub-3940256099942544/9214589741';

  late final AppLifecycleListener _lifecycle;
  BannerAd? _ad;
  bool _loading = false;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _load);
    _load();
  }

  Future<void> _load() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android ||
        _unitId.isEmpty || widget.width <= 0 || _loading || _ad != null) {
      return;
    }
    _loading = true;
    try {
      final size = await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(widget.width);
      if (!mounted || size == null) return;
      final ad = BannerAd(
        adUnitId: _unitId,
        size: size,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (ad) {
            if (mounted && identical(_ad, ad)) setState(() => _visible = true);
          },
          onAdFailedToLoad: (ad, error) {
            debugPrint('Banner unavailable: ${error.message}');
            _discard(ad);
          },
        ),
      );
      setState(() => _ad = ad);
      await ad.load();
    } on Exception catch (error) {
      debugPrint('Banner unavailable: $error');
      final ad = _ad;
      if (ad != null) _discard(ad);
    } finally {
      _loading = false;
    }
  }

  void _discard(Ad ad) {
    if (!identical(_ad, ad)) return;
    _ad = null;
    unawaited(ad.dispose());
    if (mounted) setState(() => _visible = false);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _ad?.dispose();
    _ad = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (ad == null) return const SizedBox.shrink();
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Center(
          heightFactor: 1,
          child: SizedBox(
            width: ad.size.width.toDouble(),
            height: ad.size.height.toDouble(),
            child: _visible ? AdWidget(ad: ad) : null,
          ),
        ),
      ),
    );
  }
}
