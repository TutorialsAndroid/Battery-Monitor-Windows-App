import 'dart:async';
import 'package:battery/about_page.dart';
import 'package:battery/settings_page.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:windows_notification/notification_message.dart';
import 'package:windows_notification/windows_notification.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  final Battery _battery = Battery();
  final ValueNotifier<int> _batteryLevel = ValueNotifier<int>(0);
  final ValueNotifier<bool> _isCharging = ValueNotifier<bool>(false);
  final ValueNotifier<String> _batteryHealth = ValueNotifier<String>("Unknown");
  Timer? _batteryTimer;
  SharedPreferences? _prefs;
  final List<BatteryRecord> _batteryHistory = [];
  bool _minimizeToTray = true;
  bool _showNotifications = true;
  late TabController _tabController;
  late AnimationController _animationController;

  final Color _primaryColor = const Color(0xFF2E7D32);
  final Color _secondaryColor = const Color(0xFFC8E6C9);
  final Color _warningColor = Colors.orange;
  final Color _criticalColor = Colors.red;
  final Color _backgroundColor = const Color(0xFFF5F5F5);

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _getBatteryInfo();
    _startBatteryMonitoring();
    _tabController = TabController(length: 4, vsync: this);
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _batteryTimer?.cancel();
    _batteryLevel.dispose();
    _isCharging.dispose();
    _batteryHealth.dispose();
    _tabController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    _prefs = await SharedPreferences.getInstance();
    setState(() {
      _minimizeToTray = _prefs?.getBool('minimizeToTray') ?? true;
      _showNotifications = _prefs?.getBool('showNotifications') ?? true;
    });

    final List<String>? historyData = _prefs?.getStringList('batteryHistory');
    if (historyData != null) {
      for (final item in historyData) {
        final parts = item.split('|');
        if (parts.length >= 2) {
          _batteryHistory.add(BatteryRecord(
            dateTime: DateTime.parse(parts[0]),
            level: int.parse(parts[1]),
            isCharging: parts.length > 2 ? parts[2] == 'true' : false,
          ));
        }
      }
    }
  }

  Future<void> _saveSettings() async {
    await _prefs?.setBool('minimizeToTray', _minimizeToTray);
    await _prefs?.setBool('showNotifications', _showNotifications);

    if (_batteryHistory.length > 50) {
      _batteryHistory.removeRange(0, _batteryHistory.length - 50);
    }

    final List<String> historyData = [];
    for (final record in _batteryHistory) {
      historyData.add('${record.dateTime.toIso8601String()}|${record.level}|${record.isCharging}');
    }

    await _prefs?.setStringList('batteryHistory', historyData);
  }

  void _startBatteryMonitoring() {
    _batteryTimer = Timer.periodic(const Duration(minutes: 10), (timer) {
      _getBatteryInfo();
    });
  }

  String _estimateBatteryHealth() {
    if (_batteryHistory.isEmpty) return "Good";

    final dischargeRates = <double>[];
    for (int i = 1; i < _batteryHistory.length; i++) {
      final prev = _batteryHistory[i-1];
      final curr = _batteryHistory[i];

      if (!prev.isCharging && !curr.isCharging) {
        final duration = curr.dateTime.difference(prev.dateTime).inMinutes;
        if (duration > 0 && curr.level < prev.level) {
          final rate = (prev.level - curr.level) / duration;
          dischargeRates.add(rate);
        }
      }
    }

    if (dischargeRates.isEmpty) return "Good";

    final avgDischargeRate = dischargeRates.reduce((a, b) => a + b) / dischargeRates.length;

    if (avgDischargeRate > 0.5) return "Needs Check";
    if (avgDischargeRate > 0.3) return "Average";
    return "Good";
  }

  Future<void> _getBatteryInfo() async {
    final level = await _battery.batteryLevel;
    final chargingStatus = await _battery.batteryState;

    if (mounted) {
      setState(() {
        _batteryLevel.value = level;
        _isCharging.value = chargingStatus == BatteryState.charging;
        _batteryHealth.value = _estimateBatteryHealth();

        _batteryHistory.add(BatteryRecord(
          dateTime: DateTime.now(),
          level: level,
          isCharging: chargingStatus == BatteryState.charging,
        ));

        _saveSettings();
      });
    }

    _checkBatteryNotifications();
  }

  void _checkBatteryNotifications() {
    if (!_showNotifications) return;

    if (!_isCharging.value && _batteryLevel.value <= 30) {
      final String severity = _batteryLevel.value <= 10 ? 'Critical' : 'Low';
      _showWindowsToastNotification(
        'Battery $severity',
        'Battery level is ${_batteryLevel.value}%. Please charge your device.',
      );
    } else if (_isCharging.value && _batteryLevel.value >= 80) {
      _showWindowsToastNotification(
        'Battery Full',
        'Battery level is ${_batteryLevel.value}%. For better battery health, unplug the charger.',
      );
    }
  }

  void _showWindowsToastNotification(String title, String body) {
    final winNotifyPlugin = WindowsNotification(applicationId: "Battery Monitor");
    NotificationMessage message = NotificationMessage.fromPluginTemplate(
        "battery_info", title, body);
    winNotifyPlugin.showNotificationPluginTemplate(message);
  }

  void _exit() {
    if (_minimizeToTray) {
      windowManager.hide();
    } else {
      windowManager.close();
    }
  }

  String _getBatteryLevelDescription() {
    if (_batteryLevel.value > 80) return 'Excellent';
    if (_batteryLevel.value > 50) return 'Good';
    if (_batteryLevel.value > 20) return 'Average';
    if (_batteryLevel.value > 10) return 'Low';
    return 'Critical';
  }

  Color _getBatteryColor() {
    if (_isCharging.value) return _primaryColor;
    if (_batteryLevel.value > 50) return _primaryColor;
    if (_batteryLevel.value > 20) return _warningColor;
    return _criticalColor;
  }

  Widget _buildBatteryIndicator() {
    final color = _getBatteryColor();
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return Container(
              width: 150,
              height: 70,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color, width: 3),
              ),
              child: Stack(
                children: [
                  Container(
                    margin: const EdgeInsets.all(3),
                    width: (_batteryLevel.value / 100) * 144,
                    decoration: BoxDecoration(
                      color: _isCharging.value
                          ? Color.lerp(color, Colors.white, _animationController.value)
                          : color,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  Center(
                    child: Text(
                      '${_batteryLevel.value}%',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: _batteryLevel.value > 50 ? Colors.black : Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        Container(
          width: 15,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(3),
              topRight: Radius.circular(3),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBatteryInfoTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildBatteryIndicator(),
          const SizedBox(height: 24),
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(
                      _isCharging.value ? Icons.battery_charging_full : Icons.battery_full,
                      color: _getBatteryColor(),
                      size: 36,
                    ),
                    title: const Text('Status', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(_isCharging.value ? 'Charging' : 'Discharging'),
                  ),
                  const Divider(),
                  ListTile(
                    leading: Icon(Icons.battery_alert, color: _getBatteryColor(), size: 36),
                    title: const Text('Condition', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(_getBatteryLevelDescription()),
                  ),
                  const Divider(),
                  ValueListenableBuilder<String>(
                    valueListenable: _batteryHealth,
                    builder: (context, health, _) {
                      return ListTile(
                        leading: Icon(Icons.health_and_safety, color: _getBatteryColor(), size: 36),
                        title: const Text('Health', style: TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(health),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: _getBatteryInfo,
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.close),
                label: const Text('Exit'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: _exit,
              ),
            ],
          ),


        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    if (_batteryHistory.isEmpty) {
      return const Center(
        child: Text('No history data available yet'),
      );
    }

    final List<FlSpot> spots = [];
    final lastRecords = _batteryHistory.length > 24
        ? _batteryHistory.sublist(_batteryHistory.length - 24)
        : _batteryHistory;

    for (int i = 0; i < lastRecords.length; i++) {
      spots.add(FlSpot(i.toDouble(), lastRecords[i].level.toDouble()));
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          const Text(
            'Battery Level History (Last 24 Records)',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: true),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: const TextStyle(fontSize: 10),
                        );
                      },
                    ),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: true),
                minY: 0,
                maxY: 100,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    gradient: LinearGradient(
                      colors: [_warningColor, _primaryColor],
                    ),
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          _secondaryColor.withOpacity(0.3),
                          _primaryColor.withOpacity(0.1),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: lastRecords.length,
              itemBuilder: (context, index) {
                final record = lastRecords[lastRecords.length - 1 - index];
                final formattedTime = '${record.dateTime.hour}:${record.dateTime.minute.toString().padLeft(2, '0')}';
                final formattedDate = '${record.dateTime.day}/${record.dateTime.month}/${record.dateTime.year}';
                return ListTile(
                  leading: Icon(
                    record.isCharging ? Icons.battery_charging_full : Icons.battery_std,
                    color: record.level > 20 ? _primaryColor : _criticalColor,
                  ),
                  title: Text('${record.level}%', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('$formattedDate at $formattedTime'),
                  trailing: Text(
                    record.isCharging ? 'Charging' : 'Discharging',
                    style: TextStyle(
                      color: record.isCharging ? _primaryColor : Colors.grey,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Application Settings',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Minimize to Tray Instead of Close'),
                    subtitle: const Text('Keep running in the background when closed'),
                    value: _minimizeToTray,
                    activeColor: _primaryColor,
                    onChanged: (value) {
                      setState(() {
                        _minimizeToTray = value;
                        _saveSettings();
                      });
                    },
                  ),
                  const Divider(),
                  SwitchListTile(
                    title: const Text('Show Battery Notifications'),
                    subtitle: const Text('Alert when battery is low or fully charged'),
                    value: _showNotifications,
                    activeColor: _primaryColor,
                    onChanged: (value) {
                      setState(() {
                        _showNotifications = value;
                        _saveSettings();
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Battery Protection',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Padding(
              padding: EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Battery Health Tips:',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  ListTile(
                    leading: Icon(Icons.bolt, color: Colors.amber),
                    title: Text('Avoid complete discharge'),
                    dense: true,
                  ),
                  ListTile(
                    leading: Icon(Icons.battery_full, color: Colors.green),
                    title: Text('Try to keep between 20-80%'),
                    dense: true,
                  ),
                  ListTile(
                    leading: Icon(Icons.thermostat, color: Colors.red),
                    title: Text('Avoid extreme temperatures'),
                    dense: true,
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          Center(
            child: Column(
              children: [
                const Text('Battery Monitor v1.1', style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.exit_to_app),
                  label: const Text('Exit Application'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: _exit,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Battery Monitor Pro', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.battery_full), text: 'Status'),
            Tab(icon: Icon(Icons.history), text: 'History'),
            Tab(icon: Icon(Icons.settings), text: 'Settings'),
            Tab(icon: Icon(Icons.warning_amber),text: 'About',)
          ],
        ),
      ),
      body: Container(
        color: _backgroundColor,
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildBatteryInfoTab(),
            _buildHistoryTab(),
            const SettingsPage(),
            const AboutPage(),
          ],
        ),
      ),
    );
  }
}

class BatteryRecord {
  final DateTime dateTime;
  final int level;
  final bool isCharging;

  BatteryRecord({
    required this.dateTime,
    required this.level,
    required this.isCharging,
  });
}