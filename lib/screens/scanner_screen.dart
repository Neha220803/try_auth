import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:location/location.dart';

class ScannerPage extends StatelessWidget {
  const ScannerPage({super.key});

  void _startScanning(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const ScannerScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QR Scanner')),
      body: Center(
        child: ElevatedButton(
          onPressed: () => _startScanning(context),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          ),
          child: const Text('Scan Now'),
        ),
      ),
    );
  }
}

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  MobileScannerController controller = MobileScannerController();
  bool _hasScanned = false;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
  final Location location = Location();
  bool _isSaving = false;

  // Test simple connection to Firebase
  Future<bool> _testFirebaseConnection() async {
    try {
      // Check internet connection first
      try {
        final result = await InternetAddress.lookup('google.com');
        if (result.isEmpty || result[0].rawAddress.isEmpty) {
          debugPrint('No internet connection');
          return false;
        }
      } catch (e) {
        debugPrint('Internet connection error: $e');
        return false;
      }

      // Simple test write
      final testDoc = await _firestore
          .collection('test_connection')
          .add({'timestamp': DateTime.now(), 'test': 'Connection test'});

      debugPrint('Firebase connection successful, test ID: ${testDoc.id}');
      return true;
    } catch (e) {
      debugPrint('Firebase connection test failed: $e');
      return false;
    }
  }

  Future<void> _saveScanToFirebase(String qrData) async {
    if (_isSaving) return; // Prevent multiple save attempts

    setState(() {
      _isSaving = true;
    });

    try {
      // Test connection first
      bool isConnected = await _testFirebaseConnection();
      if (!isConnected) {
        throw Exception('Failed to connect to Firebase');
      }

      // Get current date and time - simple format
      final now = DateTime.now();

      // Get device info
      String deviceModel = "Unknown";
      String deviceId = "Unknown";

      try {
        if (Theme.of(context).platform == TargetPlatform.android) {
          final androidInfo = await deviceInfo.androidInfo;
          deviceModel = '${androidInfo.manufacturer} ${androidInfo.model}';
          deviceId = androidInfo.id;
        } else if (Theme.of(context).platform == TargetPlatform.iOS) {
          final iosInfo = await deviceInfo.iosInfo;
          deviceModel = '${iosInfo.name} ${iosInfo.systemVersion}';
          deviceId = iosInfo.identifierForVendor ?? "Unknown";
        }
      } catch (e) {
        debugPrint('Error getting device info: $e');
      }

      // Get location using Location package
      double? latitude;
      double? longitude;
      String locationInfo = "Location unavailable";

      try {
        // Request service to be enabled
        bool serviceEnabled = await location.serviceEnabled();
        if (!serviceEnabled) {
          serviceEnabled = await location.requestService();
          if (!serviceEnabled) {
            throw Exception('Location services are disabled');
          }
        }

        // Get location directly without permission check
        var locationData = await location.getLocation();
        if (locationData.latitude != null && locationData.longitude != null) {
          latitude = locationData.latitude;
          longitude = locationData.longitude;
          locationInfo = "$latitude, $longitude";
          debugPrint('Location obtained: $locationInfo');
        }
      } catch (e) {
        debugPrint('Error getting location: $e');
      }

      // Create data document
      final scanData = {
        'userName': 'User',
        'scanDateTime': now, // Direct DateTime object
        'deviceInfo': '$deviceModel ($deviceId)',
        'location': locationInfo,
        'latitude': latitude,
        'longitude': longitude,
        'qrData': qrData,
        'status': 'Completed',
        'actions': [],
      };

      debugPrint('Attempting to save scan data: $scanData');

      // Save with explicit timeout
      final DocumentReference docRef = await _firestore
          .collection('scan_info')
          .add(scanData)
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw TimeoutException('Firebase write timed out'),
          );

      debugPrint('Scan successfully saved with ID: ${docRef.id}');

      // Verify the document was created by reading it back
      final docSnapshot = await docRef.get();
      if (docSnapshot.exists) {
        debugPrint('Document verified in Firestore');
      } else {
        debugPrint('Document appears to be missing after creation');
      }
    } catch (e) {
      debugPrint('Error saving to Firebase: $e');

      // If in UI, show the error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save scan data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scanning...')),
      body: Stack(
        children: [
          MobileScanner(
            controller: controller,
            onDetect: (capture) async {
              if (_hasScanned) return; // Prevent multiple scans

              final List<Barcode> barcodes = capture.barcodes;
              if (barcodes.isNotEmpty) {
                _hasScanned = true;
                controller.stop(); // Stop the scanner

                final barcode = barcodes.first;
                final qrData = barcode.rawValue ?? "No data";
                debugPrint('Barcode found! Data: $qrData');

                // Show "Saving..." dialog
                if (mounted) {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => const AlertDialog(
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Saving scan data...'),
                        ],
                      ),
                    ),
                  );
                }

                // Save to Firebase
                await _saveScanToFirebase(qrData);

                // Close saving dialog if it's open
                if (mounted && Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                }

                // Show success dialog
                if (mounted) {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        backgroundColor: Colors.white,
                        title: const Text('QR Scanned Successfully'),
                        content: const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 45,
                        ),
                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop(); // Close dialog
                              Navigator.of(context)
                                  .pop(); // Return to previous screen
                            },
                            child: const Text('OK'),
                          ),
                        ],
                      );
                    },
                  );
                }
              }
            },
          ),
          if (_isSaving)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}
