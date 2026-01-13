import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Centralized AdMob integration with safe no-ops on unsupported platforms (web/ios in this project scope).
class AdsService {
  AdsService._();
  static final AdsService instance = AdsService._();

  static const String _bannerAndroidEnv = String.fromEnvironment('ADMOB_BANNER_ANDROID');
  static const String _interstitialAndroidEnv = String.fromEnvironment('ADMOB_INTERSTITIAL_ANDROID');
  static const String _rewardedAndroidEnv = String.fromEnvironment('ADMOB_REWARDED_ANDROID');

  // AdMob test unit IDs for Android. Replace using environment variables above when you have live IDs.
  static const String _testBannerAndroid = 'ca-app-pub-3940256099942544/6300978111';
  static const String _testInterstitialAndroid = 'ca-app-pub-3940256099942544/1033173712';
  static const String _testRewardedAndroid = 'ca-app-pub-3940256099942544/5224354917';

  // We initialize the SDK only on Android. iOS is intentionally skipped to avoid TestFlight crashes.
  static bool get isSupported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Completer<void>? _initCompleter;
  bool get isInitialized => _initCompleter != null && _initCompleter!.isCompleted;

  Future<void> initialize() async {
    if (!isSupported) {
      debugPrint('AdMob initialize skipped: platform=${defaultTargetPlatform.toString()}');
      return;
    }
    if (_initCompleter != null) return _initCompleter!.future;
    _initCompleter = Completer<void>();
    try {
      await MobileAds.instance.initialize();
      debugPrint('AdMob initialized');
      _initCompleter!.complete();
    } catch (e) {
      debugPrint('AdMob initialize failed: $e');
      if (!_initCompleter!.isCompleted) _initCompleter!.complete();
    }
  }

  Future<void> ensureInitialized() async {
    if (!isSupported) return;
    if (_initCompleter == null) {
      await initialize();
      return;
    }
    await _initCompleter!.future;
  }

  // --------- Ad Unit ID helpers ---------
  String get bannerUnitIdAndroid => (_bannerAndroidEnv.isNotEmpty ? _bannerAndroidEnv : _testBannerAndroid);
  String get interstitialUnitIdAndroid => (_interstitialAndroidEnv.isNotEmpty ? _interstitialAndroidEnv : _testInterstitialAndroid);
  String get rewardedUnitIdAndroid => (_rewardedAndroidEnv.isNotEmpty ? _rewardedAndroidEnv : _testRewardedAndroid);

  // --------- Interstitial (optional use) ---------
  InterstitialAd? _interstitial;
  bool _isLoadingInterstitial = false;

  Future<void> loadInterstitial() async {
    await ensureInitialized();
    if (!isSupported || _isLoadingInterstitial || _interstitial != null) return;
    _isLoadingInterstitial = true;
    InterstitialAd.load(
      adUnitId: interstitialUnitIdAndroid,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitial = ad;
          _isLoadingInterstitial = false;
        },
        onAdFailedToLoad: (error) {
          debugPrint('Interstitial failed to load: $error');
          _isLoadingInterstitial = false;
        },
      ),
    );
  }

  Future<bool> showInterstitialIfAvailable() async {
    if (!isSupported) return false;
    await ensureInitialized();
    final ad = _interstitial;
    if (ad == null) return false;
    final c = Completer<bool>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitial = null;
        loadInterstitial();
        if (!c.isCompleted) c.complete(true);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('Interstitial failed to show: $error');
        ad.dispose();
        _interstitial = null;
        if (!c.isCompleted) c.complete(false);
      },
    );
    try {
      await ad.show();
    } catch (e) {
      debugPrint('Interstitial show error: $e');
      try { ad.dispose(); } catch (_) {}
      _interstitial = null;
      return false;
    }
    return c.future;
  }

  // --------- Rewarded (optional use) ---------
  RewardedAd? _rewarded;
  bool _isLoadingRewarded = false;

  Future<void> loadRewarded() async {
    await ensureInitialized();
    if (!isSupported || _isLoadingRewarded || _rewarded != null) return;
    _isLoadingRewarded = true;
    RewardedAd.load(
      adUnitId: rewardedUnitIdAndroid,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewarded = ad;
          _isLoadingRewarded = false;
        },
        onAdFailedToLoad: (error) {
          debugPrint('Rewarded failed to load: $error');
          _isLoadingRewarded = false;
        },
      ),
    );
  }

  Future<bool> showRewardedIfAvailable({required void Function(RewardItem reward) onRewardEarned}) async {
    if (!isSupported) return false;
    await ensureInitialized();
    final ad = _rewarded;
    if (ad == null) return false;
    final c = Completer<bool>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewarded = null;
        loadRewarded();
        if (!c.isCompleted) c.complete(true);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('Rewarded failed to show: $error');
        ad.dispose();
        _rewarded = null;
        if (!c.isCompleted) c.complete(false);
      },
    );
    try {
      await ad.show(onUserEarnedReward: (adWithoutView, reward) {
        onRewardEarned(reward);
      });
    } catch (e) {
      debugPrint('Rewarded show error: $e');
      try { ad.dispose(); } catch (_) {}
      _rewarded = null;
      return false;
    }
    return c.future;
  }
}
