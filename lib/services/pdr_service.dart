import 'dart:async';
import 'dart:math';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';

class DeadReckoningService {
  // Current integrated position
  double? _currentLat;
  double? _currentLng;
  double _currentHeading = 0.0;

  // Streams
  StreamSubscription<UserAccelerometerEvent>? _accelSubscription;
  StreamSubscription<CompassEvent>? _compassSubscription;
  
  // Expose the calculated position
  final _positionController = StreamController<Position>.broadcast();
  Stream<Position> get pdrPositionStream => _positionController.stream;

  // Step detection parameters
  static const double _stepThreshold = 1.8; // m/s^2 (tuning required per device, 1.8 is generally OK)
  static const double _stepLength = 0.74; // Average human step length in meters
  static const int _minStepCooldownMs = 300; // Minimum time between consecutive steps
  DateTime _lastStepTime = DateTime.fromMillisecondsSinceEpoch(0);
  
  bool _isTracking = false;

  /// Anchor the PDR system to a known good absolute GPS coordinate
  void anchorPosition(double lat, double lng) {
    _currentLat = lat;
    _currentLng = lng;
    // Emit initial anchor position
    _emitPosition();
  }

  /// Start Dead Reckoning
  void start() {
    if (_isTracking) return;
    _isTracking = true;

    // Listen to device compass to know which way we are pointing
    _compassSubscription = FlutterCompass.events?.listen((event) {
      if (event.heading != null) {
        // Average out wild swings
        _currentHeading = _smoothAngle(_currentHeading, event.heading!, 0.15);
      }
    });

    // Listen to linear acceleration (excludes gravity)
    _accelSubscription = userAccelerometerEventStream().listen((event) {
      if (_currentLat == null || _currentLng == null) return; // Cannot PDR without an anchor

      // Calculate vector magnitude
      double magnitude = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);

      // Simple Peak Detection for a "Step"
      if (magnitude > _stepThreshold) {
        final now = DateTime.now();
        if (now.difference(_lastStepTime).inMilliseconds > _minStepCooldownMs) {
          _lastStepTime = now;
          _onStepDetected();
        }
      }
    });
  }

  void _onStepDetected() {
    if (_currentLat == null || _currentLng == null) return;

    // Earth radius in meters
    const double earthRadius = 6378137.0;

    // Convert heading to radians
    double headingRad = _currentHeading * pi / 180.0;

    // Calculate displacement in meters
    double dX = _stepLength * sin(headingRad); // East/West
    double dY = _stepLength * cos(headingRad); // North/South

    // Convert displacement to Lat/Lng delta
    double dLat = (dY / earthRadius) * (180.0 / pi);
    double dLng = (dX / (earthRadius * cos(_currentLat! * pi / 180.0))) * (180.0 / pi);

    // Update coordinate
    _currentLat = _currentLat! + dLat;
    _currentLng = _currentLng! + dLng;

    _emitPosition();
  }

  void _emitPosition() {
    if (_currentLat == null || _currentLng == null) return;
    
    _positionController.add(Position(
      latitude: _currentLat!,
      longitude: _currentLng!,
      timestamp: DateTime.now(),
      accuracy: 1.0, // High synthetic accuracy
      altitude: 0.0,
      altitudeAccuracy: 0.0,
      heading: _currentHeading,
      headingAccuracy: 0.0,
      speed: 0.0,
      speedAccuracy: 0.0,
    ));
  }

  /// Stop tracking and cleanup
  void stop() {
    _isTracking = false;
    _accelSubscription?.cancel();
    _compassSubscription?.cancel();
  }

  void dispose() {
    stop();
    _positionController.close();
  }
  
  /// Circular EMA to keep heading steady
  double _smoothAngle(double oldAngle, double newAngle, double alpha) {
    double oldRad = oldAngle * pi / 180.0;
    double newRad = newAngle * pi / 180.0;
    double smoothX = cos(oldRad) + alpha * (cos(newRad) - cos(oldRad));
    double smoothY = sin(oldRad) + alpha * (sin(newRad) - sin(oldRad));
    return (atan2(smoothY, smoothX) * 180.0 / pi + 360) % 360;
  }
}