import 'dart:async';
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class LocationMonitor {
  static final LocationMonitor _instance = LocationMonitor._internal();
  factory LocationMonitor() => _instance;
  LocationMonitor._internal();

  static const double RADIUS_METERS = 250;
  final Map<String, List<Map<String, dynamic>>> _locations = {};
  Map<String, bool> _isInside = {};
  StreamSubscription<ServiceStatus>? _serviceStatusStream;
  StreamSubscription<Position>? _positionStream;
  final _locationController = StreamController<String>.broadcast();
  Map<String, DateTime> _lastNotificationTime = {};
  bool _isMonitoring = false;
  Map<String, bool> _lastLocationState = {};

  Stream<String> get locationStream => _locationController.stream;

  Future<bool> _checkLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }


  Future<void> startMonitoring() async {
    if (_isMonitoring) return;

    bool permissionGranted = await _checkLocationPermission();
    if (!permissionGranted) {
      return;
    }

    _isMonitoring = true;

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (serviceEnabled) {
      await _startPositionStream();
    }

    if (!kIsWeb) {
      _serviceStatusStream = Geolocator.getServiceStatusStream().listen((ServiceStatus status) {
        if (status == ServiceStatus.enabled) {
          _startPositionStream();
        } else {
          _stopPositionStream();
        }
      });
    }
  }

  Future<void> _startPositionStream() async {
    await _stopPositionStream();

    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 50,
      ),
    ).listen(
          (Position position) {
        checkLocation(LatLng(position.latitude, position.longitude));
      },
      onError: (error) {
        print("Error in position stream: $error");
      },
    );
  }

  Future<void> _stopPositionStream() async {
    if (_positionStream != null) {
      await _positionStream!.cancel();
      _positionStream = null;
    }
  }

  Future<void> stopMonitoring() async {
    _isMonitoring = false;
    if (_serviceStatusStream != null) {
      await _serviceStatusStream!.cancel();
      _serviceStatusStream = null;
    }
    await _stopPositionStream();
  }

  void updateLocations(Map<String, dynamic> userLocations) {
    _locations.clear();
    userLocations.forEach((locationType, encodedLocations) {
      List<Map<String, dynamic>> decodedLocations = _decodeLocations(encodedLocations);
      _locations[locationType] = decodedLocations;
      _isInside[locationType] = false;
    });

    DateTime timestamp = DateTime.now();
    _saveEncryptedData(timestamp);
  }


  void _saveEncryptedData(DateTime timestamp) {
    String encryptedData = _encryptData(json.encode({
      'locations': _locations,
      'timestamp': timestamp.toUtc().millisecondsSinceEpoch,
    }));
    FirebaseFirestore.instance
        .collection('currentLocation')
        .doc(FirebaseAuth.instance.currentUser!.email)
        .set({
      'currentLocation': encryptedData,
    }, SetOptions(merge: true));
  }



  String _encryptData(String data) {
    List<int> bytes = utf8.encode(data);
    return base64Url.encode(bytes);
  }

  String _decryptData(String encryptedData) {
    List<int> bytes = base64Url.decode(encryptedData);
    return utf8.decode(bytes);
  }

  Future<void> loadEncryptedData() async {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('currentLocation')
          .doc(FirebaseAuth.instance.currentUser!.email)
          .get();

      Map<String, dynamic>? data = doc.data() as Map<String, dynamic>?;
      String? encryptedData = data?['currentLocation'];

      if (encryptedData != null) {
        String decryptedData = _decryptData(encryptedData);
        Map<String, dynamic> loadedLocations = json.decode(decryptedData);
        _locations.clear();
        _locations.addAll(Map<String, List<Map<String, dynamic>>>.from(loadedLocations));
        _isInside = {for (var key in _locations.keys) key: false};
      } else {
        print('No encrypted data found.');
      }
    } catch (e) {
      print('Error loading encrypted data: $e');
    }
  }

  void checkLocation(LatLng currentLocation) {
    _locations.forEach((locationType, locationList) {
      bool wasInside = _isInside[locationType] ?? false;
      bool isNowInside = false;

      for (var location in locationList) {
        LatLng locationLatLng = LatLng(location['latitude'], location['longitude']);
        double distance = calculateDistance(currentLocation, locationLatLng);

        if (distance <= RADIUS_METERS) {
          isNowInside = true;
          break;
        }
      }

      if (wasInside != isNowInside) {
        _isInside[locationType] = isNowInside;
        _showNotification(locationType, isNowInside);
      }
    });
  }

  void _showNotification(String locationType, bool isInside) {
    DateTime now = DateTime.now();
    bool? lastState = _lastLocationState[locationType];

    // Only show notification if the state has changed
    if (lastState == null || lastState != isInside) {
      String message = isInside
          ? "You've entered the $locationType area"
          : "You've left the $locationType area";
      _locationController.add(message);
      _lastNotificationTime[locationType] = now;
      _lastLocationState[locationType] = isInside;
    }
  }
  List<Map<String, dynamic>> _decodeLocations(String encodedLocations) {
    List<int> bytes = base64Url.decode(encodedLocations);
    String jsonString = utf8.decode(bytes);
    return (json.decode(jsonString) as List).cast<Map<String, dynamic>>();
  }

  double calculateDistance(LatLng point1, LatLng point2) {
    return Geolocator.distanceBetween(
      point1.latitude,
      point1.longitude,
      point2.latitude,
      point2.longitude,
    );
  }
}