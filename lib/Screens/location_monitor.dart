import 'dart:async';
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';

import 'global_snackbar.dart';

class LocationMonitor {
  static final LocationMonitor _instance = LocationMonitor._internal();
  factory LocationMonitor() => _instance;
  LocationMonitor._internal();

  static const double RADIUS_METERS = 250;
  Map<String, List<Map<String, dynamic>>> _locations = {};

  Map<String, bool> _lastLocationState = {};
  Map<String, int> _locationCounters = {};

  Map<String, bool> _isInside = {};
  Map<String, dynamic> _currentLocationData = {};
  StreamSubscription<ServiceStatus>? _serviceStatusStream;
  StreamSubscription<Position>? _positionStream;
  final _locationController = StreamController<String>.broadcast();
  Map<String, LocationData> _locationData = {
    'Home': LocationData(),
    'Clinic': LocationData(),
    'School': LocationData(),
  };
  bool _isMonitoring = false;
  Map<String, DateTime> _lastNotificationTime = {};

  Stream<String> get locationStream => _locationController.stream;

  void _showNotification(String locationType, bool isInside) {
    DateTime now = DateTime.now();
    DateTime? lastNotificationTime = _lastNotificationTime[locationType];
    if (lastNotificationTime == null || now.difference(lastNotificationTime).inSeconds >= 60) {
      String message = isInside
          ? "You've entered the $locationType area"
          : "You've left the $locationType area";
      GlobalSnackBar.show(message);
      _lastNotificationTime[locationType] = now;
    }
  }


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

    // Load persisted data before starting the monitoring
    await _loadPersistedData();

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (serviceEnabled) {
      await _startPositionStream();
    }

    if (!kIsWeb) {
      _serviceStatusStream =
          Geolocator.getServiceStatusStream().listen((ServiceStatus status) {
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
    Map<String, dynamic> dataToSave = {
      'currentLocation': _currentLocationData['currentLocation'] ?? {},
      'Home': _currentLocationData['Home'] ?? {},
      'School': _currentLocationData['School'] ?? {},
      'Clinic': _currentLocationData['Clinic'] ?? {},
      'timestamp': timestamp.toUtc().millisecondsSinceEpoch,
    };
    String jsonString = json.encode(dataToSave);
    print('Data to save: $jsonString');
    String encryptedData = _encryptData(jsonString);
    FirebaseFirestore.instance
        .collection('currentLocation')
        .doc(FirebaseAuth.instance.currentUser!.email)
        .set({
      'currentLocation': encryptedData,
    }, SetOptions(merge: true));
  }

  Future<void> _persistData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    Map<String, dynamic> dataToSave = {};
    _locationData.forEach((key, value) {
      dataToSave[key] = value.toJson();
    });
    String encryptedData = _encryptData(json.encode(dataToSave));
    await prefs.setString('locationData', encryptedData);
  }

  Future<void> _loadPersistedData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? encryptedData = prefs.getString('locationData');
    if (encryptedData != null) {
      String decryptedData = _decryptData(encryptedData);
      Map<String, dynamic> loadedData = json.decode(decryptedData);
      loadedData.forEach((key, value) {
        _locationData[key] = LocationData.fromJson(value);
      });
    }
  }

  Future<void> _uploadDataToFirestore() async {
    try {
      Map<String, dynamic> dataToUpload = {};
      _locationData.forEach((key, value) {
        dataToUpload[key] = value.toJson();
      });
      String encryptedData = _encryptData(json.encode(dataToUpload));

      await FirebaseFirestore.instance
          .collection('locationStats')
          .doc(FirebaseAuth.instance.currentUser!.email)
          .set({
        'encryptedLocationData': encryptedData,
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error uploading location data: $e');
    }
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
        Map<String, dynamic> loadedData = json.decode(decryptedData);

        _currentLocationData = {
          'currentLocation': loadedData['currentLocation'] ?? {},
          'Home': loadedData['Home'] ?? {},
          'School': loadedData['School'] ?? {},
          'Clinic': loadedData['Clinic'] ?? {},
        };

        print('Loaded current location data: $_currentLocationData');

        if (loadedData.containsKey('locations')) {
          _locations.clear();
          Map<String, dynamic> locationsData = loadedData['locations'];
          locationsData.forEach((key, value) {
            _locations[key] = (value as List).cast<Map<String, dynamic>>();
          });
          _isInside = {for (var key in _locations.keys) key: false};
          print('Loaded locations: $_locations');
        }
      } else {
        print('No encrypted data found.');
      }
    } catch (e) {
      print('Error loading encrypted data: $e');
      print('Stack trace: ${StackTrace.current}');
    }
  }

  void checkLocation(LatLng currentLocation) {
    _locations.forEach((locationType, locationList) {
      bool wasInside = _isInside[locationType] ?? false;
      bool isNowInside = false;

      for (var location in locationList) {
        LatLng locationLatLng = LatLng(
            location['latitude'] as double,
            location['longitude'] as double
        );
        double distance = calculateDistance(currentLocation, locationLatLng);

        if (distance <= RADIUS_METERS) {
          isNowInside = true;
          break;
        }
      }

      if (!wasInside && isNowInside) {
        _isInside[locationType] = true;
        _updateLocationData(locationType, true);
        _showNotification(locationType, true);
      } else if (wasInside && !isNowInside) {
        _isInside[locationType] = false;
        _updateLocationData(locationType, false);
        _showNotification(locationType, false);
      }
    });
  }

  void _updateLocationData(String locationType, bool isEntering) {
    DateTime now = DateTime.now();
    LocationData data = _locationData[locationType]!;

    if (isEntering) {
      data.counter++;
      data.startTime = now;
      data.endTime = null;
    } else {
      data.endTime = now;
      if (data.startTime != null) {
        data.duration += now.difference(data.startTime!);
      }
    }

    _persistData();
    _uploadDataToFirestore();
  }

  String _encryptLocationData(Map<String, dynamic> data) {
    String jsonString = json.encode(data);
    return _encryptData(jsonString);
  }

  Map<String, dynamic> _decryptLocationData(String encryptedData) {
    String decryptedJson = _decryptData(encryptedData);
    return json.decode(decryptedJson);
  }

  Future<Map<String, dynamic>> getLocationData() async {
    await loadEncryptedData();
    Map<String, dynamic> decryptedData = {};
    _currentLocationData.forEach((key, value) {
      if (key != 'currentLocation') {
        decryptedData[key] = _decryptLocationData(value);
      } else {
        decryptedData[key] = value;
      }
    });
    return decryptedData;
  }

  Future<void> loadLocationData() async {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('currentLocation')
          .doc(FirebaseAuth.instance.currentUser!.email)
          .get();

      Map<String, dynamic>? data = doc.data() as Map<String, dynamic>?;

      if (data != null) {
        _currentLocationData = data;

        print('Loaded Location Data:');
        _currentLocationData.forEach((type, data) {
          print('$type: $data');
        });
      }
    } catch (e) {
      print('Error loading location data: $e');
    }
  }

  Future<void> loadLocationCounters() async {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('userSettings')
          .doc(FirebaseAuth.instance.currentUser!.email)
          .get();

      Map<String, dynamic>? data = doc.data() as Map<String, dynamic>?;
      Map<String, dynamic>? counters = data?['locationCounters'] as Map<String, dynamic>?;

      if (counters != null) {
        _locationCounters = Map<String, int>.from(counters);

        // Print the loaded counters
        print('Loaded Location Counters:');
        _locationCounters.forEach((type, count) {
          print('$type: $count');
        });
      }
    } catch (e) {
      print('Error loading location counters: $e');
    }
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

class LocationData {
  int counter;
  DateTime? startTime;
  DateTime? endTime;
  Duration duration;

  LocationData({
    this.counter = 0,
    this.startTime,
    this.endTime,
    this.duration = Duration.zero,
  });

  Map<String, dynamic> toJson() {
    return {
      'counter': counter,
      'startTime': startTime?.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'duration': duration.inSeconds,
    };
  }

  factory LocationData.fromJson(Map<String, dynamic> json) {
    return LocationData(
      counter: json['counter'],
      startTime: json['startTime'] != null ? DateTime.parse(json['startTime']) : null,
      endTime: json['endTime'] != null ? DateTime.parse(json['endTime']) : null,
      duration: Duration(seconds: json['duration']),
    );
  }
}