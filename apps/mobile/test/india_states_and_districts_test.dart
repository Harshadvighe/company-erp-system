import 'package:flutter_test/flutter_test.dart';
import 'package:saark_erp_mobile/core/constants/india_states_and_districts.dart';

void main() {
  group('IndiaStatesAndDistricts Comprehensive Suite', () {
    test('Contains all 28 states and 8 union territories (36 total)', () {
      expect(IndiaStatesAndDistricts.allStates.length, 36);
      expect(IndiaStatesAndDistricts.allStates.contains('Maharashtra'), isTrue);
      expect(IndiaStatesAndDistricts.allStates.contains('Karnataka'), isTrue);
      expect(IndiaStatesAndDistricts.allStates.contains('Gujarat'), isTrue);
      expect(IndiaStatesAndDistricts.allStates.contains('Tamil Nadu'), isTrue);
      expect(IndiaStatesAndDistricts.allStates.contains('Telangana'), isTrue);
      expect(IndiaStatesAndDistricts.allStates.contains('Delhi'), isTrue);
      expect(IndiaStatesAndDistricts.allStates.contains('Uttar Pradesh'), isTrue);
      expect(IndiaStatesAndDistricts.allStates.contains('Rajasthan'), isTrue);
      expect(IndiaStatesAndDistricts.allStates.contains('Madhya Pradesh'), isTrue);
      expect(IndiaStatesAndDistricts.allStates.contains('West Bengal'), isTrue);
      expect(IndiaStatesAndDistricts.allStates.contains('Andhra Pradesh'), isTrue);
      expect(IndiaStatesAndDistricts.allStates.contains('Kerala'), isTrue);
      expect(IndiaStatesAndDistricts.allStates.contains('Goa'), isTrue);
      expect(IndiaStatesAndDistricts.allStates.contains('Punjab'), isTrue);
      expect(IndiaStatesAndDistricts.allStates.contains('Haryana'), isTrue);
      expect(IndiaStatesAndDistricts.allStates.contains('Bihar'), isTrue);
      expect(IndiaStatesAndDistricts.allStates.contains('Odisha'), isTrue);
      expect(IndiaStatesAndDistricts.allStates.contains('Assam'), isTrue);
      expect(IndiaStatesAndDistricts.allStates.contains('Jammu and Kashmir'), isTrue);
      expect(IndiaStatesAndDistricts.allStates.contains('Ladakh'), isTrue);
    });

    test('Returns correct districts for Maharashtra', () {
      final mhDistricts = IndiaStatesAndDistricts.getDistrictsForState('Maharashtra');
      expect(mhDistricts, contains('Pune'));
      expect(mhDistricts, contains('Mumbai'));
      expect(mhDistricts, contains('Thane'));
      expect(mhDistricts, contains('Nashik'));
      expect(mhDistricts, contains('Nagpur'));
      expect(mhDistricts, contains('Chhatrapati Sambhaji Nagar'));
      expect(mhDistricts, contains('Kolhapur'));
    });

    test('Returns correct districts for Karnataka', () {
      final kaDistricts = IndiaStatesAndDistricts.getDistrictsForState('Karnataka');
      expect(kaDistricts, contains('Bangalore'));
      expect(kaDistricts, contains('Bengaluru Urban'));
      expect(kaDistricts, contains('Mysuru'));
      expect(kaDistricts, contains('Belagavi'));
      expect(kaDistricts, contains('Tumakuru'));
    });

    test('Returns correct districts for Gujarat', () {
      final gjDistricts = IndiaStatesAndDistricts.getDistrictsForState('Gujarat');
      expect(gjDistricts, contains('Ahmedabad'));
      expect(gjDistricts, contains('Surat'));
      expect(gjDistricts, contains('Vadodara'));
      expect(gjDistricts, contains('Rajkot'));
    });

    test('Returns correct districts for Tamil Nadu', () {
      final tnDistricts = IndiaStatesAndDistricts.getDistrictsForState('Tamil Nadu');
      expect(tnDistricts, contains('Chennai'));
      expect(tnDistricts, contains('Coimbatore'));
      expect(tnDistricts, contains('Madurai'));
      expect(tnDistricts, contains('Salem'));
    });

    test('Normalizes state names case-insensitively', () {
      expect(IndiaStatesAndDistricts.normalizeState('maharashtra'), 'Maharashtra');
      expect(IndiaStatesAndDistricts.normalizeState('KARNATAKA'), 'Karnataka');
      expect(IndiaStatesAndDistricts.normalizeState('gujarat'), 'Gujarat');
      expect(IndiaStatesAndDistricts.normalizeState('tamil nadu'), 'Tamil Nadu');
    });

    test('Preserves custom district if provided', () {
      final districts = IndiaStatesAndDistricts.getDistrictsForState('Maharashtra', customDistrict: 'CustomMIDC');
      expect(districts.first, 'CustomMIDC');
      expect(districts, contains('Pune'));
    });
  });
}

