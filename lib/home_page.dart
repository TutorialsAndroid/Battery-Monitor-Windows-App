import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/material.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import 'package:windows_notification/notification_message.dart';
import 'package:windows_notification/windows_notification.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TrayListener {
  final Battery _battery = Battery();
  int _batteryLevel = 0;
  bool _isCharging = false;
  Timer? _batteryTimer; // Timer to refresh battery info

  @override
  void initState() {
    super.initState();
    _getBatteryInfo(); // Initial fetch
    _startBatteryMonitoring(); // Start periodic updates
  }

  @override
  void dispose() {
    _batteryTimer?.cancel(); // Stop timer when widget is disposed
    super.dispose();
  }

  void _startBatteryMonitoring() {
    _batteryTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _getBatteryInfo();
    });
  }

  void _showWindowsToastNotification(String title, String body) {
    final winNotifyPlugin = WindowsNotification(applicationId: "Battery App");

    NotificationMessage message = NotificationMessage.fromPluginTemplate(
        "battery_info", title, body,
        largeImage: null, image: null);

    winNotifyPlugin.showNotificationPluginTemplate(message);
  }

  Future<void> _getBatteryInfo() async {
    final level = await _battery.batteryLevel;
    final chargingStatus = await _battery.batteryState;

    if (mounted) {
      setState(() {
        _batteryLevel = level;
        _isCharging = chargingStatus == BatteryState.charging;
      });
    }

    // Trigger notifications based on conditions
    if (_batteryLevel == 30 || _batteryLevel == 10) {
      _showWindowsToastNotification('Battery Level',
          'Battery level is $_batteryLevel%. Please charge your device.');
    }
    if (_isCharging && _batteryLevel >= 80) {
      _showWindowsToastNotification('Battery Level',
          'Battery level is $_batteryLevel%. Please unplug the charger.');
    }
  }

  void _exit() {
    windowManager.hide();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Battery Level: $_batteryLevel%',
                  style: const TextStyle(fontSize: 24)),
              Text(
                  'Charging Status: ${_isCharging ? "Charging" : "Not Charging"}',
                  style: const TextStyle(fontSize: 18)),
              const SizedBox(
                height: 16,
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red, // Change button color
                  foregroundColor: Colors.white, // Text color
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), // Padding
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10), // Rounded corners
                  ),
                ),
                onPressed: _exit,
                child: const Text('Exit'),
              )

            ],
          ),
        ),
      ),
    );
  }
}
