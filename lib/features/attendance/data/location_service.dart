import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:vistora_mobile/core/errors/app_exception.dart';

class AttendancePunchLocation {
  const AttendancePunchLocation({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    this.address,
  });

  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final String? address;
}

class LocationService {
  const LocationService();

  Future<Position> currentPosition({
    LocationAccuracy accuracy = LocationAccuracy.high,
  }) async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const AppException(
        message: 'Turn on location services before recording attendance.',
      );
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw const AppException(
        message: 'Location permission is required to record attendance.',
      );
    }
    if (permission == LocationPermission.deniedForever) {
      throw const AppException(
        message:
            'Location permission is permanently denied. Enable it in device settings.',
      );
    }
    return Geolocator.getCurrentPosition(
      locationSettings: LocationSettings(
        accuracy: accuracy,
        timeLimit: Duration(seconds: 15),
      ),
    );
  }

  Future<AttendancePunchLocation> currentAttendanceLocation() async {
    final position = await currentPosition(accuracy: LocationAccuracy.best);
    String? address;

    try {
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      ).timeout(const Duration(seconds: 8));
      if (placemarks.isNotEmpty) {
        address = formatAttendanceAddress(placemarks.first);
      }
    } catch (_) {
      // Native geocoders can be unavailable, offline or rate-limited. A
      // resolved address is helpful but must never prevent an attendance punch.
    }

    return AttendancePunchLocation(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracyMeters: position.accuracy,
      address: address,
    );
  }
}

String? formatAttendanceAddress(Placemark placemark) {
  final name = placemark.name?.trim();
  final street = placemark.street?.trim();
  final nameLower = name?.toLowerCase() ?? '';
  final streetLower = street?.toLowerCase() ?? '';
  final streetIsAlreadyInName =
      streetLower.isNotEmpty &&
      nameLower.isNotEmpty &&
      (nameLower.endsWith(streetLower) || streetLower.endsWith(nameLower));
  final parts = <String?>[
    placemark.name,
    streetIsAlreadyInName ? null : placemark.street,
    placemark.subLocality,
    placemark.locality,
    placemark.subAdministrativeArea,
    placemark.administrativeArea,
    placemark.postalCode,
    placemark.country,
  ];
  final seen = <String>[];
  final address = parts
      .map((part) => part?.trim() ?? '')
      .where((part) {
        if (part.isEmpty) return false;
        final normalized = part.toLowerCase();
        final duplicatesExistingPart = seen.any(
          (existing) =>
              existing == normalized ||
              existing.endsWith(' $normalized') ||
              normalized.endsWith(' $existing'),
        );
        if (duplicatesExistingPart) return false;
        seen.add(normalized);
        return true;
      })
      .join(', ');
  return address.isEmpty ? null : address;
}
