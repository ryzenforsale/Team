import 'package:geolocator/geolocator.dart';
import 'bluetooth_distance_service.dart';
import 'location_service.dart';
import 'dart:async';

class HybridLocationService {

  static const double BLUETOOTH_RANGE_THRESHOLD = 50.0;
  
  static StreamSubscription? _bluetoothSubscription;
  static StreamSubscription? _gpsSubscription;

  static Future<Map<String, dynamic>> getDistance({
    required String targetDeviceId,
    required double targetLat,
    required double targetLon,
  }) async {
    try{

      final bluetoothAvailable = await BluetoothDistanceService.isBluetoothAvailable();

      if (bluetoothAvailable) {

        await BluetoothDistanceService.stopScanning();

        final scanResults = BluetoothDistanceService.scannForDevice(targetDeviceId);

        final result = await scanResults.timeout(
          const Duration(seconds: 5),
          onTimeout: (sink){
            sink.close();
          },
        ).first;

        if(result['distance'] !=null && result ['distance'] > 0) {
          final distance = result['distance'] as double;

          print('✅ Using BLUETOOTH distance: ${distance.toStringAsFixed(1)}m');
          
          return {
            'distance': distance,
            'method': 'bluetooth',
            'accuracy': distance < 10 / 'high' : 'medium',
            'rssi': result['rssi'],
            'bearing':0.0,
          };
        }
      }


       print('⚠️ Bluetooth unavailable, falling back to GPS');
       return await _getGPSDistance(targetLat, targetLon);

     } catch (e) {
       print('❌ Error in hybrid distance: $e');
    
      return await _getGPSDistance(targetLat, targetLon);
    }
  }

      static Future<Map<String, dynamic>> _getGPSDistance(
        double targetLat,
        double targetLon,
      ) async {
        final myPosition = await LocationService.getAveragedPosition(samples: 3);

        if (myPosition == null) {
          return {
            'distance': -1.0,
            'method':'none',
            'accuracy': 'none',
            'error': 'could not get GPS position',
          };
        }
    
        final distance = LocationService.calculateDistance(
          myPosition.latitude,
          myPosition.longitude,
          targetLat,
          targetLon,
        );

        print('✅ Using GPS distance: ${distance.toStringAsFixed(1)}m');

        return {
          'distance': distance,
          'method': 'gps',
          'accuracy': myPosition.accuracy <= 10? 'medium : 'low',
          'bearing': bearing,
          'gpsAccuracy':myPosition.accuracy,
        };
      }

      static Stream<Map<String, dynamic>> getDistanceStream({
      required String targetDeviceId,
      required Stream<Position> targetPositionStream,
    }) async* {
      try {
       final bluetoothAvailable = await BluetoothDistanceService.isBluetoothAvailable();
      
      if (bluetoothAvailable) {
        yield* BluetoothDistanceService.scanForDevice(targetDeviceId).map((result) {
          if (result['distance'] != null && result['distance'] > 0) {
            return {
              'distance': result['distance'],
              'method': 'bluetooth',
              'accuracy': 'high',
              'rssi': result['rssi'],
              'bearing': 0.0,
            };
          }
          return {
            'distance': -1.0,
            'method': 'bluetooth',
            'accuracy': 'none',
          };
        });
      } else {
        // Use GPS stream
        yield* targetPositionStream.asyncMap((targetPosition) async {
          final myPosition = await LocationService.getCurrentPosition();
          
          if (myPosition == null) {
            return {
              'distance': -1.0,
              'method': 'gps',
              'accuracy': 'none',
            };
          }

          final distance = LocationService.calculateDistance(
            myPosition.latitude,
            myPosition.longitude,
            targetPosition.latitude,
            targetPosition.longitude,
          );

           return {
            'distance': distance,
            'method': 'gps',
            'accuracy': myPosition.accuracy <= 10 ? 'medium' : 'low',
            'bearing': bearing,
            'gpsAccuracy': myPosition.accuracy,
          };
        }); 
      }
    } catch (e) {
      print('❌ Error in distance stream: $e');
      yield {
        'distance': -1.0,
        'method': 'error',
        'accuracy': 'none',
        'error': e.toString(),
      };
    }
  }

  static Future<String> getBestMethod({
    required double targetLat,
    required double targetLon,
  }) async { 
    final myPosition = await LocationService.getCurrentPosition();
    
    if (myPosition == null) {
      return 'bluetooth'; 
    }
    
    final roughDistance = LocationService.calculateDistance(
      myPosition.latitude,
      myPosition.longitude,
      targetLat,
      targetLon,
    );
     
     if (roughDistance < BLUETOOTH_RANGE_THRESHOLD) {
     final bluetoothAvailable = await BluetoothDistanceService.isBluetoothAvailable();
     return bluetoothAvailable ? 'bluetooth' : 'gps';
     }
     return 'gps';
    }


    static String formatDistanceWithMethod(Map<String, dynamic> result) {
    final distance = result['distance'] as double;
    final method = result['method'] as String;
    final accuracy = result['accuracy'] as String;
    
    if (distance < 0) return 'Unknown';
    
    String distanceStr;
    if (distance < 1) {
      distanceStr = '${(distance * 100).round()}cm';
    } else if (distance < 10) {
      distanceStr = '${distance.toStringAsFixed(1)}m';
    } else {
      distanceStr = '${distance.round()}m';
    }
    
    String accuracyEmoji = '';
    switch (accuracy) {
      case 'high':
        accuracyEmoji = '🎯'; 
        break;
      case 'medium':
        accuracyEmoji = '📍'; 
        break;
      case 'low':
        accuracyEmoji = '⚠️'; 
        break;
    }
    
    return '$accuracyEmoji $distanceStr';
  }

  static Future<void> dispose() async {
    await BluetoothDistanceService.dispose();
    _bluetoothSubscription?.cancel();
    _gpsSubscription?.cancel();
  }
}