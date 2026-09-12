import 'package:flutter_test/flutter_test.dart';
import 'package:geocoding/geocoding.dart';
import 'package:vistora_mobile/features/attendance/data/location_service.dart';

void main() {
  test('formats native placemark parts into a readable address', () {
    final address = formatAttendanceAddress(
      const Placemark(
        name: '12 Park Street',
        street: 'Park Street',
        subLocality: 'Park Street',
        locality: 'Kolkata',
        administrativeArea: 'West Bengal',
        postalCode: '700016',
        country: 'India',
      ),
    );

    expect(address, '12 Park Street, Kolkata, West Bengal, 700016, India');
  });

  test('returns null when the native placemark has no address parts', () {
    expect(formatAttendanceAddress(const Placemark()), isNull);
  });
}
