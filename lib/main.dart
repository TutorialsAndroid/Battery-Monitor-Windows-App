import 'dart:async';
import 'dart:io';

import 'package:battery/home_page.dart';
import 'package:battery/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:win32/win32.dart';
import 'package:window_manager/window_manager.dart';

import 'about_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SharedPreferences prefs = await SharedPreferences.getInstance();
  bool minimizeSystemTray = prefs.getBool('system_tray_enabled') ?? false;
  // Must add this line.
  await windowManager.ensureInitialized();
  await windowManager.setResizable(false);

  WindowOptions windowOptions = const WindowOptions(
    alwaysOnTop: false,
    size: Size(400, 600),
    // Set an initial size
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false, //hides from the taskbar
    titleBarStyle: TitleBarStyle.hidden, //set TitleBarStyle.hidden to hide the close X button
  );
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    if (minimizeSystemTray) {
      await windowManager.hide();
    } else {
      await windowManager.show();
    }
  });
  runApp(const BatteryApp());
}

class BatteryApp extends StatefulWidget {
  const BatteryApp({super.key});

  @override
  State<BatteryApp> createState() => _BatteryAppState();
}

class _BatteryAppState extends State<BatteryApp> with TrayListener {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const HomePage(),
    const SettingsPage(), // New settings page
    const AboutPage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  void initState() {
    super.initState();
    trayManager.addListener(this);
    _initTray(); // Initialize Tray Icon
  }

  @override
  void dispose() {
    trayManager.removeListener(this);
    super.dispose();
  }

  @override
  void onTrayIconMouseDown() {
    trayManager.popUpContextMenu();
  }

  /// Hide the window instead of closing
  void _hideToTray() {
    final hwnd = GetForegroundWindow();
    ShowWindow(hwnd, SHOW_WINDOW_CMD.SW_HIDE); // Hides the app window
  }

  /// Restore the app window from the tray
  void _restoreFromTray() {
    windowManager.show(); // Restore the window from tray
    // final hwnd = GetForegroundWindow();
    // ShowWindow(hwnd, SHOW_WINDOW_CMD.SW_SHOW); // Restores the app window
  }

  /// Initialize system tray
  Future<void> _initTray() async {
    await trayManager.setIcon('assets/icons/battery.ico');
    await trayManager.setToolTip("Battery Monitor Running...");
    await trayManager.setContextMenu(Menu(items: [
      MenuItem(label: "Show App", onClick: (menuItem) => _restoreFromTray()),
      MenuItem(label: "Exit", onClick: (menuItem) => exit(0)),
    ]));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
        canPop: true, // Prevents app from closing
        onPopInvoked: (didPop) {
          if (didPop) return;
          _hideToTray(); // Minimize instead of closing
        },
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            body: _pages[_selectedIndex],
            bottomNavigationBar: BottomNavigationBar(
              selectedItemColor: Colors.deepOrange,
              unselectedItemColor: Colors.white54,
              backgroundColor:  Colors.grey[900],
              currentIndex: _selectedIndex,
              onTap: _onItemTapped,
              items: const [
                BottomNavigationBarItem(
                    label: 'Home', icon: Icon(Icons.home)),
                BottomNavigationBarItem(
                    label: 'Settings', icon: Icon(Icons.settings)),
                BottomNavigationBarItem(
                    label: 'About', icon: Icon(Icons.info)),
              ],
            ),
          ),
        )
    );
  }
}
