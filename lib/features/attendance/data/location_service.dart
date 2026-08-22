import 'package:geolocator/geolocator.dart';
import 'package:vistora_mobile/core/errors/app_exception.dart';

class LocationService {
  const LocationService();

  Future<Position> currentPosition() async {
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
        message: 'Location permission is required for geofence attendance.',
      );
    }
    if (permission == LocationPermission.deniedForever) {
      throw const AppException(
        message:
            'Location permission is permanently denied. Enable it in device settings.',
      );
    }
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      ),
    );
  }
}
