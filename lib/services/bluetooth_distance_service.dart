import 'dart:async';
import 'dart:io';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:math';

class BluetoothDistaneService {
  static const String SERVICE_UUID = "0000181C-0000-1000-8000-00805F9B34FB";
  static const String CHAR_uuid = "00002A3D-0000-1000-8000-00805F9B34FB";

  static StreamSubscription? _scanSubscription;
  static BluetoothDevice? _connectedDevice;

  static const double REFERENCE_RSSI = -59.0;
  static const double PATH_LOSS_EXPONENT = 2.0;

  static Future<bool> requestPermissions() async {
    if (Platform.isAndroid) {
      final statuses = await [
        Permission.bluetooth,
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.bluetoothAdvertise,
        Permission.location,
      ].request();

      return statuses.values.every((status)) => status.isGrandted);
    }
    return true;
  }

  static Future<bool> isBluetoothAvailable() async {
    try {
      if (await FlutterBluePlus.isAvailable == false) {
        return false;
      }

      final state = await FlutterBluePlus.adapterState.first;
      return state == BluetoothAdapterState.on;
      } catch (e) {
        return false; 
      }
    }


    static Future<void> turnOnBluetooth() async {
      if (platform.isAndroid) {
        await FlutterBluePlus.turnOn();
      } 
    }


    static Future<void> startAdvertising(String deviceId) async{
      try {

        print('📡 Starting BLE advertising for device: $deviceId');

      } catch (e) {
        print('❌ Error starting advertising: $e');
      }
    }

    static Stream<Map<String, dynamic>> scanForDevice(String targetDeviceId) async* {
      try {
        final hasPermission = await requestPermissions();
        if (!hasPermission) {
          print('❌ Bluetooth permissions not granted');
          return;
        }
        print('🔍 Scanning for device: $targetDeviceId');

        await FlutterBluePlus.startScan(
          timeout:const Duration(seconds: 4),
          androidUsesFineLocation: true,
        );

        yield* FlutterBluePlus.scanResults.asyncMap((results)) async {
          for (ScanResult result in results) [

        if (result.device.platformName.contains(targetDeviceId) ||
          result.device.remoteId.str == targetDeviceId) {

           final rssi = result.rssi.toDouble();
           final distance = calculateDistanceFromRSSI(rssi);
           print('📶 RSSI: $rssi dBm → Distance: ${distance.toStringAsFixed(1)}m');

           return{
           'deviceId': result.device.remoteId.str,
           'deviceName': result.device.platformName,
           'rssi': rssi,
           'distance': distance,
           'timestamp': DateTime.now(),
            };
          }
        }
        
        return {
          'distance': -1.0, // Device not found
          'timestamp': DateTime.now(),
        };
      });

    } catch (e) {
      print('❌ Error scanning: $e');
      yield {
        'distance': -1.0,
        'error': e.toString(),
        'timestamp': DateTime.now(),
      };
    }
  }

  static double calculateDistanceFromRSSI(double rssi) {
    if (rssi >= 0) {
      return -1.0; // Invalid RSSI
    }

    final distance = pow(10, (REFERENCE_RSSI - rssi) / (10 * PATH_LOSS_EXPONENT));
    
    return distance.toDouble();
  }

  static double calibrateRSSI(List<double> rssiReadings) {
    final avgRSSI = rssiReadings.reduce((a, b) => a + b) / rssiReadings.length;
    print('📏 Calibrated RSSI at 1m: ${avgRSSI.toStringAsFixed(1)} dBm');
    return avgRSSI;
  }
   static Future<void> stopScanning() async {
    try {
      await FlutterBluePlus.stopScan();
      print('⏹️ Stopped BLE scanning');
    } catch (e) {
      print('❌ Error stopping scan: $e');
    }
  }

  static String getDistanceCategory(double distance) {
    if (distance < 0) return 'Unknown';
    if (distance < 2) return 'Very Close';
    if (distance < 5) return 'Close';
    if (distance < 10) return 'Near';
    if (distance < 30) return 'Medium';
    if (distance < 50) return 'Far';
    return 'Very Far';
  }

  static String formatDistance(double distance) {
    if (distance < 0) return 'Unknown';
    if (distance < 1) return '${(distance * 100).round()}cm';
    if (distance < 10) return '${distance.toStringAsFixed(1)}m';
    return '${distance.round()}m';
  }
                 
  static Future<String?> getDeviceBluetoothId() async {
    try {
      final adapterState = await FlutterBluePlus.adapterState.first;
      
      final deviceName = FlutterBluePlus.adapterName;
      return deviceName;
    } catch (e) {
      print('❌ Error getting Bluetooth ID: $e');
      return null;
    }
  }

  static Future<void> dispose() async {
    await stopScanning();
    _scanSubscription?.cancel();
  }
}          
        
      
    