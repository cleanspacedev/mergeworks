import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:mergeworks/services/ads_service.dart';
import 'package:provider/provider.dart';
import 'package:mergeworks/services/game_service.dart';

/// Simple bottom banner that auto-hides on web/non-Android or when ads are removed.
class AdsBanner extends StatefulWidget {
  const AdsBanner({super.key, this.alignment = Alignment.center});
  final Alignment alignment;

  @override
  State<AdsBanner> createState() => _AdsBannerState();
}

class _AdsBannerState extends State<AdsBanner> {
  BannerAd? _banner;
  bool _isLoaded = false;

  bool get _shouldHide {
    // Hide on web
    if (kIsWeb) return true;
    // Only serve on Android
    if (defaultTargetPlatform != TargetPlatform.android) return true;
    // Respect Remove Ads purchase
    final game = context.read<GameService>();
    if (game.playerStats.adRemovalPurchased) return true;
    return false;
  }

  @override
  void initState() {
    super.initState();
    if (_shouldHide) return;
    final ads = AdsService.instance;
    _banner = BannerAd(
      size: AdSize.banner,
      adUnitId: ads.bannerUnitIdAndroid,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) => setState(() => _isLoaded = true),
        onAdFailedToLoad: (ad, error) {
          debugPrint('Banner failed to load: $error');
          ad.dispose();
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    try { _banner?.dispose(); } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_shouldHide || _banner == null || !_isLoaded) return const SizedBox.shrink();
    final adWidget = AdWidget(ad: _banner!);
    return Container(
      color: Theme.of(context).colorScheme.surface,
      alignment: widget.alignment,
      height: _banner!.size.height.toDouble(),
      child: adWidget,
    );
  }
}
