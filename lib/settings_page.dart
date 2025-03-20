import 'dart:io';

import 'package:flutter/material.dart';
import 'package:process_run/process_run.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _isStartupEnabled = false;
  bool _minimizeSystemTray = false;

  @override
  void initState() {
    super.initState();
    _loadStartupPreference();
    _loadSystemTrayPreference();
  }

  Future<void> _loadStartupPreference() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _isStartupEnabled = prefs.getBool('startup_enabled') ?? false;
    });
  }

  Future<void> _loadSystemTrayPreference() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _minimizeSystemTray = prefs.getBool('system_tray_enabled') ?? false;
    });
  }

  Future<void> _toggleStartup(bool value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _isStartupEnabled = value;
    });
    prefs.setBool('startup_enabled', value);

    var shell = Shell();
    if (value) {
      String exePath = Platform.resolvedExecutable;
      await shell.run(
          'reg add HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Run /v BatteryApp /t REG_SZ /d "$exePath" /f');
    } else {
      await shell.run(
          'reg delete HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Run /v BatteryApp /f');
    }
  }

  Future<void> _toggleSystemTray(bool value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _minimizeSystemTray = value;
    });
    prefs.setBool('system_tray_enabled', value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Enable on Startup', style: TextStyle(fontSize: 18)),
              const Spacer(),
              Switch(
                value: _isStartupEnabled,
                onChanged: (value) => _toggleStartup(value),
              ),
            ],
          ),
          const SizedBox(
            height: 8,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Minimize in System Tray',
                  style: TextStyle(fontSize: 18)),
              const Spacer(),
              Switch(
                value: _minimizeSystemTray,
                onChanged: (value) => _toggleSystemTray(value),
              ),
            ],
          ),
        ],
      ),
    ));
  }
}
