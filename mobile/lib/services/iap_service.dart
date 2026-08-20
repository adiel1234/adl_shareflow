import 'dart:async';
import 'dart:io';

import 'package:in_app_purchase/in_app_purchase.dart';

/// Maps ILS price amounts to App Store / Play Store product IDs.
/// These IDs must be created manually in:
///   • App Store Connect → Your App → In-App Purchases
///   • Google Play Console → Monetize → In-app products
const Map<int, String> kPriceToProductId = {
  // Tier upgrades (price diffs)
  5: 'com.adl.shareflow.tier_5',
  10: 'com.adl.shareflow.tier_10',
  // Event activation / extension
  15: 'com.adl.shareflow.tier_15',
  20: 'com.adl.shareflow.tier_20',
  25: 'com.adl.shareflow.tier_25',
  30: 'com.adl.shareflow.tier_30',
  35: 'com.adl.shareflow.tier_35',
  45: 'com.adl.shareflow.tier_45',
  // Ongoing
  49: 'com.adl.shareflow.tier_49',
  69: 'com.adl.shareflow.tier_69',
  79: 'com.adl.shareflow.tier_79',
  89: 'com.adl.shareflow.tier_89',
};

/// Result of a completed in-app purchase.
class IapPurchaseResult {
  final String productId;
  /// iOS: base64 app receipt; Android: purchase token
  final String serverVerificationData;
  final String platform;

  IapPurchaseResult({
    required this.productId,
    required this.serverVerificationData,
    required this.platform,
  });
}

/// Manages the in-app purchase flow.
///
/// Usage:
///   final result = await IapService.instance.purchase(priceIls: 49);
///   // result is null if user cancelled or IAP unavailable
class IapService {
  IapService._();
  static final IapService instance = IapService._();

  final _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;
  Completer<IapPurchaseResult?>? _completer;

  /// Returns the product ID for the given ILS price, or null if unsupported.
  String? productIdForPrice(int priceIls) => kPriceToProductId[priceIls];

  /// Initiates a consumable purchase for the given ILS price.
  /// Returns null if:
  ///   - IAP is not available on this device
  ///   - The product is not found in the store
  ///   - The user cancelled
  Future<IapPurchaseResult?> purchase({required int priceIls}) async {
    final productId = productIdForPrice(priceIls);
    if (productId == null) return null;

    final available = await _iap.isAvailable();
    if (!available) return null;

    // Load product details from the store
    final response = await _iap.queryProductDetails({productId});
    if (response.notFoundIDs.contains(productId)) return null;
    final product = response.productDetails.firstWhere(
      (p) => p.id == productId,
      orElse: () => response.productDetails.first,
    );

    // Cancel any pending purchase listener
    await _sub?.cancel();
    _completer = Completer<IapPurchaseResult?>();

    _sub = _iap.purchaseStream.listen(
      (purchases) => _handlePurchases(purchases),
      onError: (_) => _completer?.complete(null),
    );

    final purchaseParam = PurchaseParam(productDetails: product);
    await _iap.buyConsumable(purchaseParam: purchaseParam);

    return _completer!.future.timeout(
      const Duration(minutes: 5),
      onTimeout: () {
        _sub?.cancel();
        return null;
      },
    );
  }

  void _handlePurchases(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        // Complete the purchase with the server to deliver content
        _iap.completePurchase(purchase);

        if (!(_completer?.isCompleted ?? true)) {
          _completer!.complete(IapPurchaseResult(
            productId: purchase.productID,
            serverVerificationData:
                purchase.verificationData.serverVerificationData,
            platform: Platform.isIOS ? 'ios' : 'android',
          ));
          _sub?.cancel();
        }
      } else if (purchase.status == PurchaseStatus.error ||
          purchase.status == PurchaseStatus.canceled) {
        if (!(_completer?.isCompleted ?? true)) {
          _completer!.complete(null);
          _sub?.cancel();
        }
      } else if (purchase.pendingCompletePurchase) {
        _iap.completePurchase(purchase);
      }
    }
  }

  void dispose() {
    _sub?.cancel();
  }
}
