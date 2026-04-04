import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:math';

class LocationService {

  static Position? _lastPosition;
  static double _processNoise = 0.5;
  static double _measurementNoise = 4.0;

  static const double MAX_DEMO_DISTANCE = 10.0;
  static bool _demoMode = true;

  static Future<bool> requestPermission() async {
    final status = await Permission.location.request();
    return status.isGranted;
  }

  static Future<bool> isLocationEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }


  static Future<Position?> getCurrentPosition() async {
    try {
      final hasPermission = await requestPermission();
      if (!hasPermission) return null;

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
        timeLimit: const Duration(seconds: 10),
      );

      final filteredPosition = _applyKalmanFilter(position);

      return filteredPosition;
    } catch (e) {
      print ('❌ Error getting position: $e');
      return null;
    }
   }


   static Stream<Position> getPositionStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 1,
        timeLimit: Duration(seconds: 10),
      ),
    ).map((position) {

      if (position.accuracy> 50) {
        print('⚠️ Very low accuracy: ${position.accuracy}m - using last known position');
        return _lastPosition ?? position;
      }
      return _applyKalmanFilter(position);
    });
   }

   static Position _applyKalmanFilter(Position newPosition) {
    if (_lastPosition == null) {
      _lastPosition = newPosition;
      return newPosition;
    }


    final kalmanGain = _processNoise / (_processNoise + _measurementNoise);
    
    final filteredLat = _lastPosition!.latitude + 
        kalmanGain * (newPosition.latitude - _lastPosition!.latitude);
    final filteredLon = _lastPosition!.longitude + 
        kalmanGain * (newPosition.longitude - _lastPosition!.longitude); 


    final filteredPosition = Position(
        latitude: filteredLat,
        longitude: filteredLon,
        timestamp: newPosition.timestamp,
        accuracy: newPosition.accuracy,
        altitude: newPosition.altitude,
        altitudeAccuracy: newPosition.altitudeAccuracy,
        heading: newPosition.heading,
        headingAccuracy: newPosition.headingAccuracy,
        speed: newPosition.speed,
        speedAccuracy: newPosition.speedAccuracy,
      );

      _lastPosition = filteredPosition;
      return filteredPosition;
   }


   static double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371000; 


    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a = sin(dLat / 2) * sin(dLat / 2) +
       cos(_toRadians(lat1)) *
           cos(_toRadians(lat2))*
           sin(dLon / 2) *
           sin(dLon / 2);

           final c = 2 * atan2(sqrt(a), sqrt(1-a));

           var distance = earthRadius * c;

           if (_demoMode && distance > MAX_DEMO_DISTANCE) {
            print('🎯 [DEMO] Distance capped: ${distance.toStringAsFixed(1)}m → ${MAX_DEMO_DISTANCE}m');
            distance = MAX_DEMO_DISTANCE;
           }

           if (distance < 100) {
            return (distance / 5).round() *5.0;
           }
           return distance;
          } 

          static double calculateBearing(
            double lat1,
            double lon2,
            double lat2,
            double lon2,
          ) {
            final dLon = _toRadians(lon2 - lon1);

             final y = sin(dLon) * cos(_toRadians(lat2));
             final x = cos(_toRadians(lat1)) * sin(_toRadians(lat2)) -
                 sin(_toRadians(lat1)) * cos(_toRadians(lat2)) * cos(dLon);

            final bearing = atan2(y, x);
            return (_toDegrees(bearing) + 360) % 360; // Normalize to 0-360
          }


          static String formatDistance(double meters) {
            if (meters < 8) {
             return '<10m'; // Show "less than 10m" for very close distances
           } else if (meters < 100) {
             return '${(meters / 5).round() * 5}m'; // Round to nearest 5m
           } else if (meters < 1000) {
             return '${meters.round()}m';
           } else if (meters < 10000) {
             return '${(meters / 1000).toStringAsFixed(1)}km';
           } else {
             return '${(meters / 1000).round()}km';
           }
         } 


           static String getDirectionText(double bearing) {
            if (bearing >= 337.5 || bearing < 22.5) {
              return 'ahead';
            } else if (bearing >= 22.5 && bearing < 67.5) {
              return 'ahead-right';
            } else if (bearing >= 67.5 && bearing < 112.5) {
              return 'right';
            } else if (bearing >= 112.5 && bearing < 157.5) {
              return 'behind-right';
            } else if (bearing >= 157.5 && bearing < 202.5) {
              return 'behind';
            } else if (bearing >= 202.5 && bearing < 247.5) {
              return 'behind-left';
            } else if (bearing >= 247.5 && bearing < 292.5) {
              return 'left';
            } else {
              return 'ahead-left';
            }
          }



            static Future<Position?> getAveragedPosition({int samples = 3}) async {
             try {
              final hasPermission = await requestPermission();
              if (!hasPermission) return null;

            List<Position> positions = [];
      
            for (int i = 0; i < samples; i++) {
              final pos = await Geolocator.getCurrentPosition(
               desiredAccuracy: LocationAccuracy.bestForNavigation,
            );
        
              if (pos.accuracy <= 40) {
                 positions.add(pos);
             }
        
             if (i < samples - 1) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }

       if (positions.isEmpty) {
        print('⚠️ No accurate positions found');
        return await getCurrentPosition();
      }


      double avgLat = positions.map((p) => p.latitude).reduce((a, b) => a + b) / positions.length;
      double avgLon = positions.map((p) => p.longitude).reduce((a, b) => a + b) / positions.length;
      double avgAcc = positions.map((p) => p.accuracy).reduce((a, b) => a + b) / positions.length;

      print('✅ Averaged ${positions.length} positions. Accuracy: ${avgAcc.toStringAsFixed(1)}m');

      return Position(
        latitude: avgLat,
        longitude: avgLon,
        timestamp: DateTime.now(),
        accuracy: avgAcc,
        altitude: positions.last.altitude,
        altitudeAccuracy: positions.last.altitudeAccuracy,
        heading: positions.last.heading,
        headingAccuracy: positions.last.headingAccuracy,
        speed: positions.last.speed,
        speedAccuracy: positions.last.speedAccuracy,
      );
    } catch (e) {
      print('❌ Error getting averaged position: $e');
      return null;
    } 
  }      


   static bool isDistanceReliable(double distance, double accuracy1, double accuracy2) {
    final combinedAccuracy = accuracy1 + accuracy2;
    return distance > combinedAccuracy;
  }

    static void resetFilter() {
    _lastPosition = null;
  }


    static void setDemoMode(bool enabled) {
    _demoMode = enabled;
     print('🎯 [DEMO] Demo mode ${enabled ? "ENABLED" : "DISABLED"} - Max distance: ${enabled ? "${MAX_DEMO_DISTANCE}m" : "unlimited"}');
  }
  
    static bool get isDemoMode => _demoMode;

    static double _toRadians(double degree) {
      return degree * pi / 180;
  }

    static double _toDegrees(double radians) {
      return radians * 180 / pi;
  }
}