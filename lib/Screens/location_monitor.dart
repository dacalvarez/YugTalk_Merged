import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'global_snackbar.dart';

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
      counter: json['counter'] as int,
      startTime: json['startTime'] != null ? DateTime.parse(json['startTime']) : null,
      endTime: json['endTime'] != null ? DateTime.parse(json['endTime']) : null,
      duration: Duration(seconds: json['duration'] as int),
    );
  }
}

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
  Timer? _backgroundTimer;
  Timer? _statsTimer;
  final _statsController = StreamController<Map<String, Map<String, dynamic>>>.broadcast();
  Stream<String> get locationStream => _locationController.stream;
  Stream<Map<String, Map<String, dynamic>>> get statsStream => _statsController.stream;

  void _showNotification(String locationType, bool isInside) {
    DateTime now = DateTime.now();
    DateTime? lastNotificationTime = _lastNotificationTime[locationType];
    if (lastNotificationTime == null || now.difference(lastNotificationTime).inSeconds >= 60) {
      String message = isInside
          ? "You've entered the $locationType area"
          : "You've left the $locationType area";
      GlobalSnackBar.show(message);
      _lastNotificationTime[locationType] = now;
      _locationController.add(message);
    }
  }

  Map<String, Map<String, dynamic>> getLocationStats() {
    Map<String, Map<String, dynamic>> stats = {};
    _locationData.forEach((locationType, data) {
      stats[locationType] = {
        'counter': data.counter,
        'duration': data.duration.inSeconds,
        'startTime': data.startTime?.toIso8601String(),
        'endTime': data.endTime?.toIso8601String(),
      };
    });
    return stats;
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

    if (Platform.isIOS) {
      LocationPermission permission = await Geolocator.requestPermission();
      return permission == LocationPermission.always || permission == LocationPermission.whileInUse;
    }

    return true;
  }

  Future<void> startMonitoring() async {
    if (_isMonitoring) return;

    bool permissionGranted = await _checkLocationPermission();
    if (!permissionGranted) {
      print('Location permission not granted');
      return;
    }

    _isMonitoring = true;
    await _loadPersistedData();
    _startBackgroundUpdates();
    _startStatsUpdates();
  }

  void _startStatsUpdates() {
    _statsTimer = Timer.periodic(Duration(seconds: 30), (timer) {
      _statsController.add(getLocationStats());
    });
  }

  void _startBackgroundUpdates() {
    _backgroundTimer = Timer.periodic(Duration(seconds: 10), (timer) async {
      print('Background update triggered at ${DateTime.now()}');
      Position position = await Geolocator.getCurrentPosition();
      print('Current position: ${position.latitude}, ${position.longitude}');
      checkLocation(LatLng(position.latitude, position.longitude));
    });
  }

  Future<void> stopMonitoring() async {
    _isMonitoring = false;
    _backgroundTimer?.cancel();
    _statsTimer?.cancel();
    await _statsController.close();
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

  void updateLocations(Map<String, dynamic> userLocations) {
    _locations.clear();
    userLocations.forEach((locationType, encodedLocations) {
      List<Map<String, dynamic>> decodedLocations = _decodeLocations(encodedLocations);
      _locations[locationType] = decodedLocations;
      _lastLocationState[locationType] = false;
    });
  }

  Future<void> _persistData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    Map<String, dynamic> dataToSave = {};
    _locationData.forEach((key, value) {
      dataToSave[key] = value.toJson();
    });
    String jsonData = json.encode(dataToSave);
    await prefs.setString('locationData', jsonData);
  }

  Future<void> _loadPersistedData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? jsonData = prefs.getString('locationData');
    if (jsonData != null) {
      Map<String, dynamic> loadedData = json.decode(jsonData);
      loadedData.forEach((key, value) {
        _locationData[key] = LocationData.fromJson(value);
      });
    }
  }

  Future<void> _uploadDataToFirestore() async {
    try {
      Map<String, dynamic> dataToUpload = {};
      _locationData.forEach((key, value) {
        String encryptedData = _encryptLocationData(value.toJson());
        dataToUpload[key] = encryptedData;
      });

      await FirebaseFirestore.instance
          .collection('userSettings')
          .doc(FirebaseAuth.instance.currentUser!.email)
          .set({
        'locationCounters': dataToUpload
      }, SetOptions(merge: true));

      print('Successfully uploaded encrypted location data to Firestore: ${DateTime.now()}');
      print('Uploaded data: $dataToUpload');
    } catch (e) {
      print('Error uploading encrypted location data: $e');
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
    print('Checking location: ${currentLocation.latitude}, ${currentLocation.longitude}');
    _locations.forEach((locationType, locationList) {
      bool isNowInside = false;

      for (var location in locationList) {
        LatLng locationLatLng = LatLng(
            location['latitude'] as double,
            location['longitude'] as double
        );
        double distance = calculateDistance(currentLocation, locationLatLng);

        print('Distance to $locationType: $distance meters');

        if (distance <= RADIUS_METERS) {
          isNowInside = true;
          break;
        }
      }

      // Check if the state has changed
      if (isNowInside != (_isInside[locationType] ?? false)) {
        _showNotification(locationType, isNowInside);
        _isInside[locationType] = isNowInside;
      }

      _updateLocationData(locationType, isNowInside);
    });

    _persistData();
    _uploadDataToFirestore();
  }
  void _updateLocationData(String locationType, bool isInside) {
    DateTime now = DateTime.now();
    LocationData data = _locationData[locationType]!;

    if (isInside) {
      if (data.startTime == null) {
        data.counter++;
        data.startTime = now;
        print('Started visit to $locationType. Counter: ${data.counter}');
      } else {
        // Update duration even if already inside
        data.duration = now.difference(data.startTime!);
        print('Continuing visit to $locationType. Current duration: ${data.duration}');
      }
      data.endTime = now; // Always update end time while inside
    } else {
      if (data.startTime != null) {
        // If we were inside but now we're not, finalize this visit
        data.endTime = now;
        data.duration = now.difference(data.startTime!);
        print('Ended visit to $locationType. Total duration: ${data.duration}');
        data.startTime = null;
      }
    }

    // Print current state for debugging
    print('$locationType - Counter: ${data.counter}, Start: ${data.startTime}, End: ${data.endTime}, Duration: ${data.duration}');
  }

  String _encryptLocationData(Map<String, dynamic> data) {
    String jsonString = json.encode(data);
    List<int> bytes = utf8.encode(jsonString);
    return base64Url.encode(bytes);
  }

  Map<String, dynamic> _decryptLocationData(String encryptedData) {
    List<int> bytes = base64Url.decode(encryptedData);
    String jsonString = utf8.decode(bytes);
    return json.decode(jsonString);
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
          .collection('locationCounters')
          .doc(FirebaseAuth.instance.currentUser!.email)
          .get();

      Map<String, dynamic>? data = doc.data() as Map<String, dynamic>?;

      if (data != null) {
        data.forEach((key, value) {
          Map<String, dynamic> decryptedData = _decryptLocationData(value as String);
          _locationData[key] = LocationData.fromJson(decryptedData);
        });

        // Print the loaded counters
        print('Loaded Location Counters:');
        _locationData.forEach((type, data) {
          print('$type: ${data.counter}');
        });
      }
    } catch (e) {
      print('Error loading encrypted location counters: $e');
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