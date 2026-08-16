import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart'; // You will need this for the buy button!
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:confetti/confetti.dart';
import 'dart:math' as math;
import 'dart:io';
import '../../widgets/package_card.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../navigation/main_navigation_screen.dart';
import '../../widgets/common/paywall_video_background.dart';
import '../../widgets/common/gradient_pill_button.dart';
import '../../widgets/paywall/paywall_feature_row.dart';
import '../../theme/orbit_tokens.dart';

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  // Shrinks each legal-link button's padding/tap target so all 4 fit
  // without overflowing on narrower devices.
  static final ButtonStyle _legalLinkButtonStyle = TextButton.styleFrom(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    minimumSize: Size.zero,
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  );

  late ConfettiController _confettiController;
  // NEW SUBSCRIPTIONS VARIABLES
  List<Package> _packages = []; // Holds both Monthly and Annual
  Package? _selectedPackage; // Track which card is currently tapped
  bool _isLoadingPrice = true; // Shows a loading spinner until we get the price
  bool _isPurchasing = false; // For the main purchase button
  bool _isRestoring = false; // For the restore button
  bool _isVerifying = false; // True while polling for entitlement post-purchase
  // Whether the signed-in user is known to be ineligible for the annual
  // package's free trial (already used it, or already an active/past
  // subscriber) -- default false so pricing is unaffected until the iOS-only
  // eligibility check below (if it can even run) resolves.
  bool _annualTrialIneligible = false;
  String _paywallTitle = "Unlock Your\nFull Potential.";
  String _paywallSubtitle =
      "Get unlimited access to all premium features, personalized plans, and deep insights.";
  String _paywallLayout = "standard";

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 2),
    );

    // FETCH THE PRICES WHEN THE SCREEN LOADS!
    _fetchPackages();
    _fetchRemoteConfig();
  }

  Future<void> _fetchRemoteConfig() async {
    try {
      final remoteConfig = FirebaseRemoteConfig.instance;
      await remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 10),
          minimumFetchInterval: const Duration(
            hours: 1,
          ), // Adjust for production
        ),
      );

      await remoteConfig.setDefaults({
        'paywall_title': 'Unlock Your\\nFull Potential.',
        'paywall_subtitle':
            'Get unlimited access to all premium features, personalized plans, and deep insights.',
        'paywall_layout': 'standard',
      });

      await remoteConfig.fetchAndActivate();
      if (mounted) {
        setState(() {
          _paywallTitle = remoteConfig
              .getString('paywall_title')
              .replaceAll('\\n', '\n');
          _paywallSubtitle = remoteConfig.getString('paywall_subtitle');
          _paywallLayout = remoteConfig.getString('paywall_layout');
        });
      }
    } catch (e) {
      debugPrint('Failed to fetch remote config: $e');
    }
  }

  // THE REVENUECAT FETCH FUNCTION

  Future<void> _fetchPackages() async {
    try {
      Offerings offerings = await Purchases.getOfferings();
      if (offerings.current != null &&
          offerings.current!.availablePackages.isNotEmpty) {
        setState(() {
          _packages = offerings.current!.availablePackages;

          // Automatically pre select the annual plan if it exists, otherwise picks the first one
          _selectedPackage = _packages.firstWhere(
            (p) => p.packageType == PackageType.annual,
            orElse: () => _packages.first,
          );
        });
      }
    } catch (e) {
      debugPrint("Error fetching packages: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoadingPrice = false);
      }
    }
    await _checkTrialEligibility();
  }

  // "START 7-DAY FREE TRIAL" was previously shown unconditionally to
  // everyone who selected the annual plan -- including a returning user,
  // reinstaller, or anyone who already consumed the trial and is not
  // actually entitled to another one, which is both a bad surprise at
  // charge time and an App Store pricing-accuracy risk. RevenueCat's
  // eligibility API is iOS-only (Android always returns
  // introEligibilityStatusUnknown per its own docs), so this only ever
  // narrows the trial copy on iOS; Android keeps showing it, matching prior
  // behavior, since there's no way to distinguish there.
  Future<void> _checkTrialEligibility() async {
    if (kIsWeb || !Platform.isIOS || _packages.isEmpty) return;
    try {
      final ids = _packages.map((p) => p.storeProduct.identifier).toList();
      final eligibility =
          await Purchases.checkTrialOrIntroductoryPriceEligibility(ids);
      final annual = _packages.firstWhere(
        (p) => p.packageType == PackageType.annual,
        orElse: () => _packages.first,
      );
      final status = eligibility[annual.storeProduct.identifier]?.status;
      // Per RevenueCat's own guidance: on an unknown/unresolvable status,
      // show the non-trial price rather than risk a misleading trial offer.
      final ineligible =
          status != null &&
          status != IntroEligibilityStatus.introEligibilityStatusEligible;
      if (mounted) {
        setState(() => _annualTrialIneligible = ineligible);
      }
    } catch (e) {
      debugPrint("Error checking trial eligibility: $e");
    }
  }

  Future<void> _performPurchase() async {
    if (_selectedPackage == null) {
      // DEVELOPER BYPASS: If RevenueCat failed to load products (e.g., testing on Desktop or an Emulator),
      // clicking "CONTINUE" will gracefully simulate a successful purchase so you can test the app right now!
      if (kDebugMode) {
        setState(() => _isPurchasing = true);
        try {
          await Future.delayed(const Duration(seconds: 1));
          if (mounted) {
            _confettiController.play();
            await _showPremiumSuccessModal();

            if (mounted) {
              await _finishOnboardingAndGoToDashboard(context);
            }
          }
        } finally {
          if (mounted) setState(() => _isPurchasing = false);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Subscription packages haven't loaded yet. Please wait a moment or restart the app.",
            ),
          ),
        );
      }
      return;
    }

    setState(() => _isPurchasing = true);
    try {
      PurchaseResult result = await Purchases.purchase(
        PurchaseParams.package(_selectedPackage!),
      );
      CustomerInfo customerInfo = result.customerInfo;
      final isPro =
          customerInfo.entitlements.all["Orbit Pro"]?.isActive == true;

      if (isPro) {
        if (mounted) await _handlePurchaseConfirmed();
      } else {
        // Sandbox/StoreKit entitlement sync can lag a few seconds behind the
        // transaction itself. This is what tripped App Review under
        // Guideline 2.1(b) — the purchase completed but the UI never
        // reacted. Show a "verifying" state instead of silently stalling.
        setState(() => _isVerifying = true);
        final confirmed = await _pollForEntitlement();
        if (!mounted) return;
        setState(() => _isVerifying = false);

        if (confirmed) {
          await _handlePurchaseConfirmed();
        } else {
          // Still couldn't confirm the entitlement after polling. The
          // transaction itself succeeded (no exception was thrown), so give
          // the user actionable next steps rather than a dead-end SnackBar.
          await _showResolutionOptions();
        }
      }
    } on PlatformException catch (e) {
      final errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode != PurchasesErrorCode.purchaseCancelledError) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.redAccent,
              content: Text("Purchase failed: ${e.message}"),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text("An unexpected error occurred: $e"),
          ),
        );
      }
    } finally {
      // Also resets _isVerifying: if Purchases.getCustomerInfo() throws
      // inside _pollForEntitlement, control skips the line-172 reset above
      // and lands in the catch blocks, which never touched _isVerifying --
      // leaving it stuck true forever and the Close button (gated on
      // _isPurchasing || _isVerifying) permanently disabled. Same trapped-
      // paywall failure mode as the Guideline 2.1(b) rejection, different path.
      if (mounted) {
        setState(() {
          _isPurchasing = false;
          _isVerifying = false;
        });
      }
    }
  }

  /// Polls RevenueCat for the "Orbit Pro" entitlement to catch up after a
  /// purchase whose initial [CustomerInfo] doesn't yet reflect it (a known
  /// sandbox/StoreKit sync delay). Returns true once confirmed active, or
  /// false after [maxRetries] attempts. Backs off between attempts since
  /// this is waiting on a server-to-server webhook, not a fixed-latency call.
  Future<bool> _pollForEntitlement({int maxRetries = 8}) async {
    for (var attempt = 0; attempt < maxRetries; attempt++) {
      final delay = Duration(seconds: attempt < 4 ? 1 : 2); // ~1,1,1,1,2,2,2,2s = 12s total
      await Future.delayed(delay);
      if (!mounted) return false;
      final refreshed = await Purchases.getCustomerInfo();
      if (refreshed.entitlements.all["Orbit Pro"]?.isActive == true) {
        return true;
      }
    }
    return false;
  }

  Future<void> _handlePurchaseConfirmed() async {
    if (!mounted) return;
    _confettiController.play();
    await _showPremiumSuccessModal();
    if (mounted) {
      await _finishOnboardingAndGoToDashboard(context);
    }
  }

  /// Shown when a purchase transaction succeeded but the entitlement still
  /// hasn't synced after polling. Gives the user actionable next steps
  /// instead of leaving them stuck on the paywall with just a SnackBar.
  Future<void> _showResolutionOptions() async {
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: OrbitTokens.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'Almost there!',
          style: TextStyle(color: OrbitTokens.ink, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          "Your payment went through, but we're still waiting on confirmation "
          "from the App Store. Try Restore Purchases, or contact support if "
          "this doesn't resolve in a few minutes.",
          style: TextStyle(color: OrbitTokens.inkDim),
        ),
        actions: [
          TextButton(
            onPressed: () => _sendPurchaseSupportRequest(),
            child: const Text('Contact Support'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _performRestore();
            },
            child: const Text('Restore Purchases'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendPurchaseSupportRequest() async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final user = FirebaseAuth.instance.currentUser;
    final userEmail = user?.email ?? 'No Email Provided';
    final uid = user?.uid ?? 'Unknown UID';

    navigator.pop(); // close the resolution dialog

    try {
      await FirebaseFirestore.instance.collection('mail').add({
        'to': 'contact@orbitroutine.com',
        'message': {
          'subject': 'Orbit Pro purchase not unlocking for $userEmail',
          'html':
              '''
          <h3>Purchase entitlement did not sync</h3>
          <p><strong>User:</strong> $userEmail</p>
          <p><strong>UID:</strong> $uid</p>
          <p>The customer completed a purchase in the app, but the "Orbit Pro"
          entitlement had not activated after polling RevenueCat. Please check
          their RevenueCat/App Store transaction history.</p>
        ''',
          'replyTo': userEmail,
        },
      });
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Support request sent successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Failed to send request: $e')),
        );
      }
    }
  }

  Future<void> _showPremiumSuccessModal() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: OrbitTokens.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.all(32),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
                  Icons.workspace_premium_rounded,
                  color: OrbitTokens.gold,
                  size: 80,
                )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scaleXY(begin: 0.9, end: 1.1, duration: 1.seconds),
            const SizedBox(height: 24),
            const Text(
              'Welcome to Pro!',
              style: TextStyle(
                color: OrbitTokens.ink,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your journey has just begun.',
              style: TextStyle(
                color: OrbitTokens.teal,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'You now have unlimited access to premium coaching, custom app icons, and all focus areas.',
              textAlign: TextAlign.center,
              style: TextStyle(color: OrbitTokens.inkDim, fontSize: 14),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: OrbitTokens.teal,
                  foregroundColor: OrbitTokens.ground,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Enter Orbit',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
          ],
        ).animate().scaleXY(begin: 0.8, end: 1.0, curve: Curves.easeOutBack),
      ),
    );
  }

  Future<void> _performRestore() async {
    setState(() => _isRestoring = true);
    try {
      CustomerInfo customerInfo = await Purchases.restorePurchases();
      final isPro =
          customerInfo.entitlements.all["Orbit Pro"]?.isActive == true;

      if (isPro) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Colors.green,
              content: Text(
                "Purchases restored successfully! Orbit Pro is active.",
              ),
            ),
          );
          await _finishOnboardingAndGoToDashboard(context);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("No active subscriptions found to restore."),
            ),
          );
        }
      }
    } on PlatformException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text("Error restoring purchases: ${e.message}"),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text("An unexpected error occurred: $e"),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isRestoring = false);
    }
  }

  Future<void> _finishOnboardingAndGoToDashboard(BuildContext context) async {
    // 1. Mark onboarding as complete
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_onboarding', true);

    // 2. Navigate to the root path
    if (context.mounted) {
      if (Navigator.canPop(context)) {
        // If opened from the Dashboard as a popup, simply close it
        Navigator.pop(context);
      } else {
        // End of the guest-onboarding chain: every step used
        // pushReplacement, so this paywall is the ONLY route on the stack
        // and go_router still thinks the location is '/'. context.go('/')
        // is a same-location no-op there — the close button did nothing.
        // Replace ourselves with the app shell instead (same pattern as
        // WhatsNewScreen).
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const MainNavigationScreen(),
          ),
        );
      }
    }
  }

  // Call this function when the user taps the "Redeem Code" button.
  Future<void> redeemPromoCode() async {
    try {
      if (Platform.isIOS) {
        // Apple provides a native bottom sheet for code redemption
        await Purchases.presentCodeRedemptionSheet();
      } else if (Platform.isAndroid) {
        // Android requires deep-linking out to the Play Store redemption page
        final url = Uri.parse('https://play.google.com/redeem');
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
        } else {
          throw Exception('No app available to open the Play Store link');
        }
      }
    } catch (e) {
      debugPrint("Error presenting code redemption: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text("Couldn't open code redemption. Please try again."),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Determine the button text based on the selected package
    String buttonText = "LOADING...";

    // Apple Guideline 3.1.2 requires auto-renewal terms to be disclosed
    // in-app, not just in the App Store description.
    String renewalDisclosure = "";
    // A short, high-contrast version shown directly ABOVE the buy button so the
    // trial length + post-trial price + auto-renewal are unmissable at the point
    // of purchase (Guideline 3.1.2(c), flagged more than once when this only
    // lived in low-contrast fine print below the button).
    String priceSummary = "";
    if (!_isLoadingPrice) {
      if (_selectedPackage != null) {
        final priceString = _selectedPackage!.storeProduct.priceString;
        if (_selectedPackage!.packageType == PackageType.annual &&
            !_annualTrialIneligible) {
          buttonText = "START 7-DAY FREE TRIAL"; // Make it clear!
          priceSummary =
              "7 days free, then $priceString/year. Auto-renews until "
              "cancelled.";
          // Apple Guideline 3.1.2(c): state title, length, and price of the
          // subscription in-app, not just in the App Store listing.
          renewalDisclosure =
              "Orbit Pro (Annual, 12 months): 7-day free trial, then "
              "$priceString/year. Subscription automatically renews unless "
              "canceled at least 24 hours before the end of the current "
              "period. Any unused portion of a free trial is forfeited once "
              "you purchase a subscription.";
        } else if (_selectedPackage!.packageType == PackageType.annual) {
          // Known-ineligible for the trial -- show plain annual pricing
          // instead of promising a trial that won't actually apply.
          buttonText = "SUBSCRIBE (ANNUAL)";
          priceSummary = "$priceString/year. Auto-renews until cancelled.";
          renewalDisclosure =
              "Orbit Pro (Annual, 12 months): $priceString/year. "
              "Subscription automatically renews unless canceled at least "
              "24 hours before the end of the current period.";
        } else {
          buttonText = "SUBSCRIBE MONTHLY";
          priceSummary =
              "$priceString/month. Auto-renews until cancelled.";
          renewalDisclosure =
              "Orbit Pro (Monthly): $priceString/month. Subscription "
              "automatically renews unless canceled at least 24 hours "
              "before the end of the current period.";
        }
      } else {
        buttonText = "CONTINUE";
      }
    }
    return Scaffold(
      backgroundColor: OrbitTokens.ground, // Fallback color
      body: Stack(
        children: [
          // LAYER 1: THE VIDEO BACKGROUND
          const PaywallVideoBackground(),

          // LAYER 2: THE DARK OVERLAY (So you can actually read the white text)
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  OrbitTokens.ground.withValues(alpha: 0.35),
                  OrbitTokens.ground.withValues(
                    alpha: 0.94,
                  ), // Gets darker at the bottom near the button
                ],
              ),
            ),
          ),

          // LAYER 3: YOUR FROSTY UI & REVENUECAT BUTTON
          SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          reverse: true,
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                      // "ORBIT PRO" eyebrow badge
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: OrbitTokens.signal,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "ORBIT PRO",
                              style: TextStyle(
                                color: OrbitTokens.inkDim,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Your Marketing Text
                      Text(
                        _paywallTitle,
                        style: const TextStyle(
                          color: OrbitTokens.ink,
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          height: 1.12,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _paywallSubtitle,
                        style: TextStyle(
                          color: OrbitTokens.inkDim,
                          fontSize: 14.5,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 22),

                      // Grounded, concrete feature list — what Pro actually
                      // unlocks, not generic "unlimited everything" copy.
                      const PaywallFeatureRow(
                        icon: Icons.auto_awesome_rounded,
                        title: "Daily AI coaching",
                        subtitle:
                            "Personalized insight from your streaks & skips",
                      ),
                      const SizedBox(height: 10),
                      const PaywallFeatureRow(
                        icon: Icons.self_improvement_rounded,
                        title: "Sanctuary & guided audio",
                        subtitle: "Full ambient library, always unlocked",
                      ),
                      const SizedBox(height: 10),
                      const PaywallFeatureRow(
                        icon: Icons.forum_rounded,
                        title: "Pro coaching sessions",
                        subtitle: "Structured sessions in the Coaching hub",
                      ),
                      const SizedBox(height: 22),

                      // THE DYNAMIC PRICE DISPLAY
                      Builder(
                        builder: (context) {
                          final displayPackages =
                              _paywallLayout == 'annual_only'
                              ? _packages
                                    .where(
                                      (p) =>
                                          p.packageType == PackageType.annual,
                                    )
                                    .toList()
                              : _packages;

                          if (_isLoadingPrice) {
                            return const Center(
                              child: CircularProgressIndicator(
                                color: OrbitTokens.teal,
                              ),
                            );
                          } else if (displayPackages.isNotEmpty) {
                            return Column(
                              children: displayPackages
                                  .map((package) {
                                    return PackageCard(
                                      package: package,
                                      isSelected:
                                          _selectedPackage?.identifier ==
                                          package.identifier,
                                      onSelect: (selected) => setState(
                                        () => _selectedPackage = selected,
                                      ),
                                      trialIneligible: _annualTrialIneligible,
                                    );
                                  })
                                  .toList()
                                  .animate(interval: 150.ms)
                                  .fade(duration: 500.ms)
                                  .slideY(
                                    begin: 0.2,
                                    end: 0,
                                    curve: Curves.easeOutCubic,
                                  ),
                            );
                          } else if (_packages.isEmpty) {
                            // DEBUG TEXT: This will show up if RevenueCat fails!
                            // Inside your build method where the debug container used to be:

                            return Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: OrbitTokens.surface,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: OrbitTokens.hairline),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.cloud_off_rounded,
                                    color: OrbitTokens.inkDim,
                                    size: 40,
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    "Unable to load plans",
                                    style: TextStyle(
                                      color: OrbitTokens.ink,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    "Please check your internet connection or ${defaultTargetPlatform == TargetPlatform.iOS ? 'Apple' : 'Google Play'} account status and try again.",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: OrbitTokens.inkDim,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  TextButton.icon(
                                    onPressed: () {
                                      setState(() => _isLoadingPrice = true);
                                      _fetchPackages(); // Let them manually retry!
                                    },
                                    icon: Icon(
                                      Icons.refresh_rounded,
                                      color: OrbitTokens.teal,
                                    ),
                                    label: Text(
                                      "Retry",
                                      style: TextStyle(
                                        color: OrbitTokens.teal,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          return const SizedBox.shrink();
                        },
                      ),

                      const SizedBox(height: 6),

                      // High-contrast trial/price/renewal summary directly
                      // above the CTA -- guarantees the reviewer (and user)
                      // sees the terms at the point of purchase, not just in
                      // fine print below. (Guideline 3.1.2(c).)
                      if (priceSummary.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            priceSummary,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: OrbitTokens.ink,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              height: 1.3,
                            ),
                          ),
                        ),

                      // THE REVENUECAT BUY BUTTON
                      GradientPillButton(
                            text: buttonText,
                            isLoading: _isPurchasing,
                            onPressed:
                                _isLoadingPrice || _isPurchasing || _isRestoring
                                ? null
                                : _performPurchase,
                          )
                          .animate(target: _isLoadingPrice ? 0 : 1)
                          .fade(begin: 0.8, end: 1.0, duration: 400.ms)
                          .scaleXY(
                            begin: 0.95,
                            end: 1.0,
                            duration: 500.ms,
                            curve: Curves.easeOutBack,
                          ),

                      if (_isVerifying)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            "Verifying your purchase...",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: OrbitTokens.inkDim,
                              fontSize: 13,
                            ),
                          ),
                        ),

                      if (renewalDisclosure.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            renewalDisclosure,
                            textAlign: TextAlign.center,
                            // Was inkFaint/11 -- the lowest-contrast color
                            // and smallest size in the whole design system,
                            // on top of a video background. This is the text
                            // that states trial length + post-trial price,
                            // which App Review flagged twice as not clear.
                            // Bumped to inkDim/12.5 with more weight so it
                            // actually reads as a disclosure, not filler.
                            style: TextStyle(
                              color: OrbitTokens.inkDim,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              height: 1.4,
                            ),
                          ),
                        ),

                      // --- LEGAL & RESTORE LINKS ---
                      const SizedBox(height: 16),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 4,
                        runSpacing: 4,
                        children: [
                          TextButton(
                            style: _legalLinkButtonStyle,
                            onPressed: _isPurchasing || _isRestoring
                                ? null
                                : _performRestore,
                            child: _isRestoring
                                ? SizedBox(
                                    height: 12,
                                    width: 12,
                                    child: CircularProgressIndicator(
                                      color: OrbitTokens.inkDim,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    "Restore",
                                    style: TextStyle(
                                      color: OrbitTokens.inkDim,
                                      fontSize: 12,
                                    ),
                                  ),
                          ),
                          TextButton(
                            style: _legalLinkButtonStyle,
                            onPressed: () async {
                              final url = Uri.parse(
                                'https://orbitroutine.com/terms.html',
                              );
                              if (!await launchUrl(url)) {
                                debugPrint('Could not launch $url');
                              }
                            },
                            child: Text(
                              "Terms",
                              style: TextStyle(
                                color: OrbitTokens.inkDim,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          TextButton(
                            style: _legalLinkButtonStyle,
                            onPressed: () async {
                              final url = Uri.parse(
                                'https://orbitroutine.com/privacy.html',
                              );
                              if (!await launchUrl(url)) {
                                debugPrint('Could not launch $url');
                              }
                            },
                            child: Text(
                              "Privacy",
                              style: TextStyle(
                                color: OrbitTokens.inkDim,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          TextButton(
                            style: _legalLinkButtonStyle,
                            onPressed: () async {
                              // Apple Guideline 3.1.2(c) requires a functional
                              // link to the EULA. Orbit uses Apple's standard
                              // EULA rather than a custom one.
                              final url = Uri.parse(
                                'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/',
                              );
                              if (!await launchUrl(url)) {
                                debugPrint('Could not launch $url');
                              }
                            },
                            child: Text(
                              "EULA",
                              style: TextStyle(
                                color: OrbitTokens.inkDim,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          TextButton(
                            style: _legalLinkButtonStyle,
                            onPressed: redeemPromoCode,
                            child: Text(
                              "Promo Code",
                              style: TextStyle(
                                color: OrbitTokens.teal,
                                fontSize: 12,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .animate(delay: 500.ms)
              .fade(duration: 800.ms)
              .slideY(begin: 0.1, end: 0, curve: Curves.easeOutCubic),

          // LAYER 4: CLOSE BUTTON
          //
          // Disabled while a purchase is in flight (_isPurchasing) or its
          // entitlement is still being polled (_isVerifying) -- previously
          // this always navigated away immediately regardless of state, so
          // tapping Close right after tapping a purchase button would yank
          // the user out of the flow before _pollForEntitlement ever
          // resolved. The purchase could still succeed in the background,
          // but the UI never showed it, and Apple flagged exactly this
          // shape of bug under Guideline 2.1(b) in sandbox review.
          SafeArea(
                child: Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: (_isPurchasing || _isVerifying)
                          ? null
                          : () async {
                              HapticFeedback.lightImpact();
                              await _finishOnboardingAndGoToDashboard(context);
                            },
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: OrbitTokens.surface2,
                          border: Border.all(color: OrbitTokens.hairline),
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          color: (_isPurchasing || _isVerifying)
                              ? OrbitTokens.inkDim.withValues(alpha: 0.3)
                              : OrbitTokens.inkDim,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
              )
              .animate(delay: 1300.ms) // After the main content has faded in
              .fade(duration: 500.ms),

          // LAYER 5: CELEBRATORY CONFETTI (STARS)
          // IgnorePointer: ConfettiWidget lays out an unconstrained
          // CustomPaint that expands to fill the whole screen and hit-tests
          // across its full area even when idle/invisible. Being the
          // topmost layer, it was silently swallowing every tap on the
          // paywall — including the close button — with zero visual
          // feedback. Purely decorative, so it must never intercept touches.
          IgnorePointer(
            child: Align(
              alignment: Alignment.center,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                shouldLoop: false,
                colors: const [
                  OrbitTokens.teal,
                  OrbitTokens.gold,
                  OrbitTokens.ink,
                ],
                createParticlePath: _drawStar, // Epic star explosion!
                numberOfParticles: 40,
                maxBlastForce: 100, // Massive room-filling blast
                minBlastForce: 20,
                gravity: 0.15,
              ),
            ),
          ),

          // LAYER 6: CELEBRATORY CONFETTI (PLANETS)
          IgnorePointer(
            child: Align(
              alignment: Alignment.center,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                shouldLoop: false,
                colors: const [
                  OrbitTokens.violet,
                  OrbitTokens.surface2,
                ],
                createParticlePath: _drawPlanet, // Saturn-style planets!
                numberOfParticles: 40, // 40 stars + 40 planets = 80 total
                maxBlastForce: 100,
                minBlastForce: 20,
                gravity: 0.12, // Planets float just a tiny bit differently
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Custom Star Shape for the Confetti!
  Path _drawStar(Size size) {
    double degToRad(double deg) => deg * (math.pi / 180.0);
    const numberOfPoints = 5;
    final halfWidth = size.width / 2;
    final externalRadius = halfWidth;
    final internalRadius = halfWidth / 2.5;
    final degreesPerStep = degToRad(360 / numberOfPoints);
    final halfDegreesPerStep = degreesPerStep / 2;
    final path = Path();
    final fullAngle = degToRad(360);
    path.moveTo(size.width, halfWidth);

    for (double step = 0; step < fullAngle; step += degreesPerStep) {
      path.lineTo(
        halfWidth + externalRadius * math.cos(step),
        halfWidth + externalRadius * math.sin(step),
      );
      path.lineTo(
        halfWidth + internalRadius * math.cos(step + halfDegreesPerStep),
        halfWidth + internalRadius * math.sin(step + halfDegreesPerStep),
      );
    }
    path.close();
    return path;
  }

  // Custom Planet Shape (Saturn style) for the Confetti!
  Path _drawPlanet(Size size) {
    final path = Path();
    final halfWidth = size.width / 2;

    // The main planet body
    path.addOval(
      Rect.fromCircle(
        center: Offset(halfWidth, halfWidth),
        radius: halfWidth * 0.6,
      ),
    );

    // The planet's ring (a flat ellipse)
    path.addOval(
      Rect.fromCenter(
        center: Offset(halfWidth, halfWidth),
        width: size.width * 1.4,
        height: size.width * 0.3,
      ),
    );

    return path;
  }
}
