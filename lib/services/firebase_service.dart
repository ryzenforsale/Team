import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/tracking_session.dart';

class FirebaseService{

  static final DatabaseReference _db = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL: 'https://friend-finder-hackathon-e9f5f-default-rtdb.asia-southeast1.firebasedatabase.app',
 ).ref();

 static Future<void> registerDevice(String deviceId, String deviceName) async {
  print("💾 [FIREBASE] Registering device: $deviceId");
  await _db.child('devices/$deviceId').set({
    'name': deviceName,
    'online': true,
    'lastseen': ServerValue.timestamp,
  });
 }

 static Stream<List<Map<String, dynamic>>> getAllDevicesStream() {
  return _db.child('devices/$deviceId').set({
    'name': deviceName,
    'online': true,
    'lastseen': ServerValue.timestamp,
  });
 }


 static Stream<List<Map<String, dynamuc>>> getAllDevicesStream() {
  return _db.child('devices').onValue.map((event) {
    final List<Map<String, dynamic>> devices = [];
    if (event.snapshot.value !=null) {
      final Map<dynamic, dynamic>data =
          event.snapshot.value as Map<dynamic, dynamuc>;
        data.forEach((key, value){
          final deviceData = Map<String, dynamic>.from(value as Map);
          deviceData['id']= key;
          devices.add(deviceData);
        });
    }
    return devices;
  });
 }

 static Future<String> startDirectSession(String myDeviceId, String targetId) async {
  final sessionRef = _db.child('tracking_sessions').push();
  final String sessionId = sessionRef.key!;

  await sessionRef.set({
    'deviceA': myDeviceId,
    'deviceB': targetId,
    'active': true,
    'createdAt': ServerValue.timestamp,
  });

  return sessionId;
 }

  static Stream<Map<String, dynamic>?> listenForInstantInvite(String myDeviceId) {
    return _db.child('users/$myDeviceId/instant_invite').onValue.map((event) {
      if (event.snapshot.value != null) {
        return Map<String, dynamic>.from(event.snapshot.valur as Map);
      }
      return null;
    });
  } 

  ststic Future<void> clearInstantInvite(String myDeviceId) async {
    await _db.child('users/$myDeviceId/instant_invite').onValue.map((event) {
      if (event.snapshot.value !=null) {
        return Map<String, dynamic>.from(event.snapshot.value as Map);
      }
      return null;
    });
  }


  static Future<void> updateLocation(String sessionId, String deviceId,
  double lat, double lng, double heading) async {
    await _db.child('tracking_sessions/$sessionId/$deviceId').set({
      'lat': lat,
      'lng': lng,
      'heading': heading,
      'timestamp': ServerValue.timestamp,
    });
  }

  static Stream<LocationData?> listenToLocation(String sessionId, String deviceId) {
    return _db.child('tracking_session/$sessionId/$deviceId').onValue.map((event){
      if (event.snapshot.value !=null) {
        return LocationData.fromMap(data);
      }
      return null;
    });
  }

  static Future<void> endTrackingSession(String sessionId) async {
    await _db.child('tracking_sessions/$sessionId').remove();
  }

  static Future<void> setDeviceOnline(String deviceId, bool online) async {
    await _db.child('devices/$deviceId').update({
      'online': online,
      'lastSeen': ServerValue.timestamp,
    });
  }

  static Future<void> setupDisconnectHandlers(String deviceId) async {
    // This will automatically set the device offline when disconnected
    await _db.child('devices/$deviceId/online').onDisconnect().set(false);
    await _db.child('devices/$deviceId/lastSeen').onDisconnect().set(ServerValue.timestamp);
  }

  static Future<void> updateBluetoothId(String sessionId, String deviceId, String bluetoothId) async {
    print("📡 [FIREBASE] Storing Bluetooth ID for $deviceId: $bluetoothId");
    await _db.child('tracking_sessions/$sessionId/$deviceId/bluetoothId').set(bluetoothId);
  }

  static Stream<String?> listenToBluetoothId(String sessionId, String deviceId) {
    return _db.child('tracking_sessions/$sessionId/$deviceId/bluetoothId').onValue.map((event) {
      if (event.snapshot.value != null) {
        final bluetoothId = event.snapshot.value.toString();
        print("📡 [FIREBASE] Got Bluetooth ID for $deviceId: $bluetoothId");
        return bluetoothId;
      }
      return null;
    });
  }

  static Future<String?> getBluetoothId(String sessionId, String deviceId) async {
    final snapshot = await _db.child('tracking_sessions/$sessionId/$deviceId/bluetoothId').get();
    if (snapshot.exists) {
      return snapshot.value.toString();
    }
    return null;
  }
}