import 'package:flutter/material.dart';

import 'notification_settings_model.dart';
import 'notification_settings_service.dart';
import 'local_notification_service.dart';



class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  final NotificationSettingsService _service = NotificationSettingsService();

  bool _loading = true;
  NotificationSettingsModel _settings = NotificationSettingsModel.defaults();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final loaded = await _service.loadSettings();

    setState(() {
      _settings = loaded;
      _loading = false;
    });
  }

  Future<void> _save(NotificationSettingsModel value) async {
    setState(() {
      _settings = value;
    });

    await _service.saveSettings(value);
  }

  String _timeText(int hour, int minute) {
    return '${hour.toString().padLeft(2, '0')}:'
        '${minute.toString().padLeft(2, '0')}';
  }

  Future<void> _pickTime({
    required int initialHour,
    required int initialMinute,
    required void Function(TimeOfDay time) onPicked,
  }) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: initialHour,
        minute: initialMinute,
      ),
    );

    if (picked == null) return;
    onPicked(picked);
  }

  String _weekdayName(int day) {
    switch (day) {
      case 1:
        return 'Monday';
      case 2:
        return 'Tuesday';
      case 3:
        return 'Wednesday';
      case 4:
        return 'Thursday';
      case 5:
        return 'Friday';
      case 6:
        return 'Saturday';
      case 7:
        return 'Sunday';
      default:
        return 'Sunday';
    }
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _settingsCard(List<Widget> children) {
    return Card(
      child: Column(
        children: children,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Choose when Offline Challenge should send your summaries.',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),

          _sectionTitle('Daily summary'),
          _settingsCard([
            SwitchListTile(
              title: const Text('Daily summary'),
              subtitle: const Text('Receive a summary every day.'),
              value: _settings.dailyEnabled,
              onChanged: (value) {
                _save(_settings.copyWith(dailyEnabled: value));
              },
            ),
            const Divider(height: 1),
            RadioListTile<DailySummaryPeriod>(
              title: const Text('Today'),
              subtitle: const Text('Summary of the current day.'),
              value: DailySummaryPeriod.today,
              groupValue: _settings.dailyPeriod,
              onChanged: !_settings.dailyEnabled
                  ? null
                  : (value) {
                if (value == null) return;
                _save(_settings.copyWith(dailyPeriod: value));
              },
            ),
            RadioListTile<DailySummaryPeriod>(
              title: const Text('Yesterday'),
              subtitle: const Text('Summary of the previous day.'),
              value: DailySummaryPeriod.yesterday,
              groupValue: _settings.dailyPeriod,
              onChanged: !_settings.dailyEnabled
                  ? null
                  : (value) {
                if (value == null) return;
                _save(_settings.copyWith(dailyPeriod: value));
              },
            ),
            const Divider(height: 1),
            ListTile(
              enabled: _settings.dailyEnabled,
              title: const Text('Time'),
              subtitle: Text(
                _timeText(_settings.dailyHour, _settings.dailyMinute),
              ),
              trailing: const Icon(Icons.schedule),
              onTap: !_settings.dailyEnabled
                  ? null
                  : () {
                _pickTime(
                  initialHour: _settings.dailyHour,
                  initialMinute: _settings.dailyMinute,
                  onPicked: (time) {
                    _save(
                      _settings.copyWith(
                        dailyHour: time.hour,
                        dailyMinute: time.minute,
                      ),
                    );
                  },
                );
              },
            ),
          ]),

          _sectionTitle('Weekly summary'),
          _settingsCard([
            SwitchListTile(
              title: const Text('Weekly summary'),
              subtitle: const Text('Receive a weekly offline summary.'),
              value: _settings.weeklyEnabled,
              onChanged: (value) {
                _save(_settings.copyWith(weeklyEnabled: value));
              },
            ),
            const Divider(height: 1),
            ListTile(
              enabled: _settings.weeklyEnabled,
              title: const Text('Day'),
              subtitle: Text(_weekdayName(_settings.weeklyDay)),
              trailing: DropdownButton<int>(
                value: _settings.weeklyDay,
                onChanged: !_settings.weeklyEnabled
                    ? null
                    : (value) {
                  if (value == null) return;
                  _save(_settings.copyWith(weeklyDay: value));
                },
                items: List.generate(7, (index) {
                  final day = index + 1;
                  return DropdownMenuItem(
                    value: day,
                    child: Text(_weekdayName(day)),
                  );
                }),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              enabled: _settings.weeklyEnabled,
              title: const Text('Time'),
              subtitle: Text(
                _timeText(_settings.weeklyHour, _settings.weeklyMinute),
              ),
              trailing: const Icon(Icons.schedule),
              onTap: !_settings.weeklyEnabled
                  ? null
                  : () {
                _pickTime(
                  initialHour: _settings.weeklyHour,
                  initialMinute: _settings.weeklyMinute,
                  onPicked: (time) {
                    _save(
                      _settings.copyWith(
                        weeklyHour: time.hour,
                        weeklyMinute: time.minute,
                      ),
                    );
                  },
                );
              },
            ),
          ]),

          _sectionTitle('Monthly summary'),
          _settingsCard([
            SwitchListTile(
              title: const Text('Monthly summary'),
              subtitle: const Text('Receive a monthly offline summary.'),
              value: _settings.monthlyEnabled,
              onChanged: (value) {
                _save(_settings.copyWith(monthlyEnabled: value));
              },
            ),
            const Divider(height: 1),
            ListTile(
              enabled: _settings.monthlyEnabled,
              title: const Text('Day of month'),
              subtitle: Text('Day ${_settings.monthlyDay}'),
              trailing: DropdownButton<int>(
                value: _settings.monthlyDay,
                onChanged: !_settings.monthlyEnabled
                    ? null
                    : (value) {
                  if (value == null) return;
                  _save(_settings.copyWith(monthlyDay: value));
                },
                items: List.generate(28, (index) {
                  final day = index + 1;
                  return DropdownMenuItem(
                    value: day,
                    child: Text('$day'),
                  );
                }),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              enabled: _settings.monthlyEnabled,
              title: const Text('Time'),
              subtitle: Text(
                _timeText(
                  _settings.monthlyHour,
                  _settings.monthlyMinute,
                ),
              ),
              trailing: const Icon(Icons.schedule),
              onTap: !_settings.monthlyEnabled
                  ? null
                  : () {
                _pickTime(
                  initialHour: _settings.monthlyHour,
                  initialMinute: _settings.monthlyMinute,
                  onPicked: (time) {
                    _save(
                      _settings.copyWith(
                        monthlyHour: time.hour,
                        monthlyMinute: time.minute,
                      ),
                    );
                  },
                );
              },
            ),
          ]),
        ],
      ),
    );
  }
}