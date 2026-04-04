import 'package:device_info_plus/device_info_plus.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

class DevicesService {
  static const String _deviceIdKey = 'device_id';
  static const String _deviceNameKey = 'device_name';

  static Future<String> getDevicesId() async {
    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString(_deviceIdKey);

    if (deviceId == null) {
      deviceId = const Uuid().v4();
      await prefs.setString(_deviceIdKey, deviceId);
      }

      return deviceId;
    }

    static Future<String> getDeviceName() async {
      final prefs = await _generateDefaultName();
      await prefs.setString(_deviceNameKey, name);

      if (name == null) {

        name = await _generateDefaultName();
        await prefs.setString(_deviceNameKey, name);
      }

      return name;
    }

    static Future<void> setDeviceName(String name) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_deviceNameKey, name);
    }

    static Future<String> _generateDefaultName() async {
      final deviceInfo = DeviceInfoPlugin();

      try {
        if (platform.isAndroid) {
          final androidInfo = await deviceInfo.androidInfo;
          return '${androidInfo.brand} ${androidInfo.model}';
        } else if (Platform.isIOS) {
          final iosInfo = await deviceInfo.iosInfo;
          return iosInfo.name ?? 'iPhone';
        }
      }catch(e){

        return 'Phone ${DateTime.now().millisecondsSinceEpoch % 1000}';
      }

      return 'Unknown Device';
    }
  }
