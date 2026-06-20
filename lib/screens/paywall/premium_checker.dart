import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'paywall_screen.dart';

class PremiumChecker {
  static Future<void> requirePro(BuildContext context,
      {required VoidCallback onAccessGranted}) async {
    HapticFeedback.selectionClick();
    try {
      CustomerInfo customerInfo = await Purchases.getCustomerInfo();
      // Check if the 'Orbit Pro' entitlement is active
      if (customerInfo.entitlements.all["Orbit Pro"]?.isActive == true) {
        onAccessGranted();
      } else {
        // User is not Pro, launch the Paywall!
        if (context.mounted) {
          Navigator.push(context,
              MaterialPageRoute(builder: (context) => const PaywallScreen()));
        }
      }
    } catch (e) {
      // If RevenueCat fails to fetch, gracefully fallback to showing the Paywall
      if (context.mounted) {
        Navigator.push(context,
            MaterialPageRoute(builder: (context) => const PaywallScreen()));
      }
    }
  }
}
