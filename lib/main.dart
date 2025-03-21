import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:win32/win32.dart';
import 'package:window_manager/window_manager.dart';

import 'home_page.dart';
import 'settings_page.dart';
import 'about_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final minimizeToTray = prefs.getBool('system_tray_enabled') ?? false;

  await windowManager.ensureInitialized();

  const windowOptions = WindowOptions(
    alwaysOnTop: false,
    size: Size(400, 800),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.normal,
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    minimizeToTray ? await windowManager.hide() : await windowManager.show();
  });

  runApp(const BatteryApp());
}

class BatteryApp extends StatefulWidget {
  const BatteryApp({super.key});

  @override
  State<BatteryApp> createState() => _BatteryAppState();
}

class _BatteryAppState extends State<BatteryApp> with TrayListener {
  final RxInt _selectedIndex = 0.obs;
  final List<Widget> _pages = const [HomePage(), SettingsPage(), AboutPage()];

  @override
  void initState() {
    super.initState();
    trayManager.addListener(this);
    _initTray();
  }

  @override
  void dispose() {
    trayManager.removeListener(this);
    super.dispose();
  }

  @override
  void onTrayIconMouseDown() => trayManager.popUpContextMenu();

  void _hideToTray() => ShowWindow(GetForegroundWindow(), SHOW_WINDOW_CMD.SW_HIDE);

  Future<void> _restoreFromTray() async => windowManager.show();

  Future<void> _initTray() async {
    await trayManager.setIcon('assets/icons/battery.ico');
    await trayManager.setToolTip("Battery Monitor Running...");
    await trayManager.setContextMenu(Menu(items: [
      MenuItem(label: "Show App", onClick: (_) => _restoreFromTray()),
      MenuItem(label: "Exit", onClick: (_) => exit(0)),
    ]));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) {
        if (!didPop) _hideToTray();
      },
      child: GetMaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Obx(() => _pages[_selectedIndex.value]),
          // bottomNavigationBar: Obx(() => BottomNavigationBar(
          //   currentIndex: _selectedIndex.value,
          //   onTap: (index) => _selectedIndex.value = index,
          //   items: const [
          //     BottomNavigationBarItem(label: 'Home', icon: Icon(Icons.home)),
          //     BottomNavigationBarItem(label: 'Settings', icon: Icon(Icons.settings)),
          //     BottomNavigationBarItem(label: 'About', icon: Icon(Icons.info)),
          //   ],
          // )),
        ),
      ),
    );
  }
}