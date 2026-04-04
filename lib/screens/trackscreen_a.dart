import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'dart:math';
import '../services/firebase_service.dart';
import '../services/location_service.dart';
import '../models/tracking_session.dart';

class TrackingScreenA extends StatefulWidget {
  final String sessionId;
  final String friendId;
  final String friendName;
  final String myDeviceId;

  const TrackingScreenA({
    super.key,
    required this.sessionId,
    required this.friendId,
    required this.friendName,
    required this.myDeviceId,
  });

  @override
  State<TrackingScreenA> createState() => _TrackingScreenAState();
}

class _TrackingScreenAState extends State<TrackingScreenA>
    with TickerProviderStateMixin {
  StreamSubscription<Position>? _locationSubscription;
  StreamSubscription<CompassEvent>? _compassSubscription;
  StreamSubscription<LocationData?>? _friendLocationSubscription;

  double? myLat;
  double? myLng;
  double myHeading = 0;

  double? friendLat;
  double? friendLng;

  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _startTracking();
  }

  Future<void> _startTracking() async {
    final hasPermission = await LocationService.requestPermission();
    if (!hasPermission) return;

    _locationSubscription =
        LocationService.getPositionStream().listen((position) {
      if (!mounted) return;

      setState(() {
        myLat = position.latitude;
        myLng = position.longitude;
      });

      FirebaseService.updateLocation(
        widget.sessionId,
        widget.myDeviceId,
        position.latitude,
        position.longitude,
        myHeading,
      );
    });

    _compassSubscription = FlutterCompass.events?.listen((event) {
      if (!mounted) return;
      if (event.heading != null) {
        setState(() {
          myHeading = event.heading!;
        });
      }
    });

    _friendLocationSubscription = FirebaseService.listenToLocation(
      widget.sessionId,
      widget.friendId,
    ).listen((locationData) {
      if (!mounted) return;
      if (locationData != null) {
        setState(() {
          friendLat = locationData.lat;
          friendLng = locationData.lng;
        });
      }
    });
  }

  double? _calculateDistance() {
    if (myLat == null ||
        myLng == null ||
        friendLat == null ||
        friendLng == null) {
      return null;
    }

    return LocationService.calculateDistance(
        myLat!, myLng!, friendLat!, friendLng!);
  }

  double? _calculateBearing() {
    if (myLat == null ||
        myLng == null ||
        friendLat == null ||
        friendLng == null) {
      return null;
    }

    return LocationService.calculateBearing(
        myLat!, myLng!, friendLat!, friendLng!);
  }

  double _calculateArRotation() {
    final bearing = _calculateBearing();
    if (bearing == null) return 0;
    return (bearing - myHeading);
  }

  String _getDirectionText() {
    final bearing = _calculateBearing();
    if (bearing == null) return 'Searching...';

    double relative = (bearing - myHeading + 360) % 360;
    return LocationService.getDirectionText(relative);
  }

  @override
  Widget build(BuildContext context) {
    final distance = _calculateDistance();
    final arrowRotation = _calculateArrowRotation();

    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF2FE0C4),
                    Color(0xFF1CB5B0),
                    Color(0xFF0F7C82),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [

                  /// TOP BAR
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: _stopTracking,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            widget.friendName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const CircleAvatar(
                          radius: 4,
                          backgroundColor: Color(0xFF69F0AE),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          "Connected",
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),

                  /// CENTER
                  SizedBox(
                    width: 280,
                    height: 280,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [

                        AnimatedBuilder(
                          animation: _pulseController,
                          builder: (_, __) {
                            return Stack(
                              alignment: Alignment.center,
                              children: [
                                _ring(220, _pulseController.value),
                                _ring(180, (_pulseController.value + 0.3) % 1),
                                _ring(140, (_pulseController.value + 0.6) % 1),
                              ],
                            );
                          },
                        ),

                        Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.2),
                          ),
                        ),

                        TweenAnimationBuilder<double>(
                          duration: const Duration(milliseconds: 300),
                          tween: Tween(begin: 0, end: arrowRotation),
                          builder: (context, angle, child) {
                            return Transform.rotate(
                              angle: angle * pi / 180,
                              child: const Arrow3D(size: 100),
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  /// TEXT
                  distance == null
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Column(
                          children: [
                            Text(
                              LocationService.formatDistance(distance),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 60,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _getDirectionText(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "Move towards the device",
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),

                  /// BUTTON
                  Padding(
                    padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
                    child: GestureDetector(
                      onTap: _stopTracking,
                      child: Container(
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFFFF5A5F),
                              Color(0xFFFF3B30),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withOpacity(0.4),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text(
                            "Stop Tracking",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _ring(double size, double progress) {
    return Opacity(
      opacity: 1 - progress,
      child: Container(
        width: size * (0.7 + progress * 0.3),
        height: size * (0.7 + progress * 0.3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1),
        ),
      ),
    );
  }

  Future<void> _stopTracking() async {
    await FirebaseService.endTrackingSession(widget.sessionId);
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _compassSubscription?.cancel();
    _friendLocationSubscription?.cancel();
    _pulseController.dispose();
    super.dispose();
  }
}

/// 🔥 3D ARROW
class Arrow3D extends StatelessWidget {
  final double size;
  const Arrow3D({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: ArrowPainter(),
    );
  }
}

class ArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final leftPaint = Paint()
      ..shader = LinearGradient(
        colors: [Color(0xFF3DAEFF), Color(0xFF007BFF)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    final rightPaint = Paint()
      ..shader = LinearGradient(
        colors: [Colors.white, Color(0xFFE6F7FF)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    final left = Path()
      ..moveTo(w * 0.5, h * 0.05)
      ..lineTo(w * 0.1, h * 0.9)
      ..lineTo(w * 0.5, h * 0.7)
      ..close();

    final right = Path()
      ..moveTo(w * 0.5, h * 0.05)
      ..lineTo(w * 0.9, h * 0.9)
      ..lineTo(w * 0.5, h * 0.7)
      ..close();

    canvas.drawPath(left, leftPaint);
    canvas.drawPath(right, rightPaint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}