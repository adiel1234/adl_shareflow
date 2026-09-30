import 'package:adl_shareflow/features/groups/domain/group_model.dart';
import 'package:adl_shareflow/services/iap_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const expectedIds = [
    'com.adl.shareflow.tier_5',
    'com.adl.shareflow.tier_10',
    'com.adl.shareflow.tier_15',
    'com.adl.shareflow.tier_20',
    'com.adl.shareflow.tier_25',
    'com.adl.shareflow.tier_30',
    'com.adl.shareflow.tier_35',
    'com.adl.shareflow.tier_40',
    'com.adl.shareflow.tier_45',
    'com.adl.shareflow.tier_49',
    'com.adl.shareflow.tier_69',
    'com.adl.shareflow.tier_79',
    'com.adl.shareflow.tier_89',
  ];

  test('maps all 13 Apple consumable tiers including tier_25 and tier_40', () {
    expect(kPriceToProductId.length, 13);
    expect(kAppleProductIds.length, 13);
    expect(kPriceToProductId[25], 'com.adl.shareflow.tier_25');
    expect(kPriceToProductId[40], 'com.adl.shareflow.tier_40');
    expect(kAppleProductIds, expectedIds.toSet());

    for (final price in [5, 10, 15, 20, 25, 30, 35, 40, 45, 49, 69, 79, 89]) {
      expect(kPriceToProductId[price], 'com.adl.shareflow.tier_$price');
    }
  });

  test('does not expose Pro, subscription, or test product IDs', () {
    for (final id in kAppleProductIds) {
      expect(id.startsWith('com.adl.shareflow.tier_'), isTrue);
      expect(id.toLowerCase().contains('pro'), isFalse);
      expect(id.toLowerCase().contains('sub'), isFalse);
      expect(id.toLowerCase().contains('test'), isFalse);
    }
    expect(kPriceToProductId[0], isNull);
  });

  test('activation and upgrade prices map to a store product', () {
    Group event(int members) => Group(
          id: 'e',
          name: 'e',
          baseCurrency: 'ILS',
          groupType: 'event',
          memberCount: members,
        );
    Group ongoing(int members) => Group(
          id: 'o',
          name: 'o',
          baseCurrency: 'ILS',
          groupType: 'ongoing',
          memberCount: members,
        );

    expect(event(5).estimatedPrice(), 15);
    expect(event(10).estimatedPrice(), 20);
    expect(event(15).estimatedPrice(), 30);
    expect(event(39).estimatedPrice(), 35);
    expect(event(40).estimatedPrice(), 45);
    expect(ongoing(5).estimatedPrice(), 49);
    expect(ongoing(8).estimatedPrice(), 69);
    expect(ongoing(11).estimatedPrice(), 79);
    expect(ongoing(12).estimatedPrice(), 89);

    for (final price in [15, 20, 25, 30, 35, 40, 45, 49, 69, 79, 89, 5, 10]) {
      expect(kPriceToProductId.containsKey(price), isTrue);
    }
  });
}
