import 'package:flutter/material.dart';

import 'profile_model.dart';
import 'profile_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../offline_tracker/tracking_settings_service.dart';
import '../offline_tracker/native_tracking_service.dart';
import '../offline_tracker/offline_counting_settings_service.dart';
import 'package:country_picker/country_picker.dart';
import '../leaderboard/leaderboard_service.dart';


class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ProfileService _profileService = ProfileService();
  final LeaderboardService _leaderboardService = LeaderboardService();

  final _nicknameController = TextEditingController();
  final _cityController = TextEditingController();
  final _countryController = TextEditingController();

  final TrackingSettingsService _trackingSettingsService =
  TrackingSettingsService();

  final NativeTrackingService _nativeTrackingService =
  NativeTrackingService();

  final OfflineCountingSettingsService _countingSettingsService =
  OfflineCountingSettingsService();

  bool _excludeSleepTime = false;
  TimeOfDay _sleepStart = const TimeOfDay(hour: 22, minute: 0);
  TimeOfDay _sleepEnd = const TimeOfDay(hour: 7, minute: 0);

  bool _loading = true;
  bool _saving = false;
  bool _showInRankings = true;
  bool _rankingToggleSaving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _stopCollecting() async {
    await _trackingSettingsService.setTrackingEnabled(false);
    await _nativeTrackingService.stopTrackingService();
  }

  Future<void> _resetAllData() async {
    await _stopCollecting();
    final prefs = await SharedPreferences.getInstance();

    // vypnout collecting
    await prefs.setBool('collecting_enabled', false);
    await prefs.setBool('automatic_collecting_started', false);

    // vynulovat statistiky
    await prefs.remove('native_session_history');
    await prefs.remove('screen_off_started_at');

    // vynulovat notifikace
    await prefs.remove('notification_last_sent_daily');
    await prefs.remove('notification_last_sent_weekly');
    await prefs.remove('notification_last_sent_monthly');

    await prefs.remove('notification_settings');

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Statistics reset and collecting stopped'),
      ),
    );

    setState(() {});
  }

  void _showCountryPicker() {
    showCountryPicker(
      context: context,
      showPhoneCode: false,
      onSelect: (Country country) {
        setState(() {
          _countryController.text = country.countryCode;
        });
      },
    );
  }

  Future<void> _loadProfile() async {
    final profile = await _profileService.loadProfile();

    final excludeSleep =
    await _countingSettingsService.loadExcludeSleepTime();
    final sleepStart =
    await _countingSettingsService.loadSleepStart();
    final sleepEnd =
    await _countingSettingsService.loadSleepEnd();

    _nicknameController.text = profile.nickname;
    _cityController.text = profile.city;
    _countryController.text = profile.country;


    setState(() {
      _showInRankings = profile.showInRankings;
      _excludeSleepTime = excludeSleep;
      _sleepStart = TimeOfDay(
        hour: sleepStart.hour,
        minute: sleepStart.minute,
      );
      _sleepEnd = TimeOfDay(
        hour: sleepEnd.hour,
        minute: sleepEnd.minute,
      );
      _loading = false;
    });
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Future<void> _pickSleepTime({
    required bool isStart,
  }) async {
    final initial = isStart ? _sleepStart : _sleepEnd;

    final selected = await showTimePicker(
      context: context,
      initialTime: initial,
    );

    if (selected == null) return;

    if (isStart) {
      await _countingSettingsService.saveSleepStart(
        selected.hour,
        selected.minute,
      );
      setState(() {
        _sleepStart = selected;
      });
    } else {
      await _countingSettingsService.saveSleepEnd(
        selected.hour,
        selected.minute,
      );
      setState(() {
        _sleepEnd = selected;
      });
    }
  }

  Future<void> _confirmResetAllData() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset statistics?'),
        content: const Text(
          'This will delete all offline statistics and turn off collecting. '
              'Offline time tracking will stop until you start it again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset and stop'),
          ),
        ],
      ),
    );

    if (result == true) {
      await _resetAllData();
    }
  }

  Future<void> _saveProfile() async {
    final nickname = _nicknameController.text.trim();
    final city = _cityController.text.trim();
    final country = _countryController.text.trim();



    setState(() {
      _saving = true;
    });

    final profile = ProfileModel(
      nickname: nickname,
      city: city,
      country: country,
      showInRankings: _showInRankings,
    );

    await _profileService.saveProfile(profile);
    if (_showInRankings) {
      await _leaderboardService.updateMyLeaderboardProfile(
        nickname: nickname,
        country: country,
        city: city,
      );
    }

    if (!mounted) return;

    setState(() {
      _saving = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Profile saved'),
      ),
    );
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _cityController.dispose();
    _countryController.dispose();
    super.dispose();
  }

  Future<void> _setShowInRankings(bool value) async {
    print("TOGGLE: $value");
    setState(() {
      _showInRankings = value;
      _rankingToggleSaving = true;
    });

    final profile = ProfileModel(
      nickname: _nicknameController.text.trim(),
      city: _cityController.text.trim(),
      country: _countryController.text.trim(),
      showInRankings: value,
    );

    await _profileService.saveProfile(profile);

    await _leaderboardService.uploadMyStats(
      nickname: profile.nickname.isEmpty ? 'Anonymous' : profile.nickname,
      country: profile.country.isEmpty ? 'UN' : profile.country.toUpperCase(),
      city: profile.city.isEmpty ? 'unknown' : profile.city.toLowerCase(),
      dayMinutes: 0,
      weekMinutes: 0,
      monthMinutes: 0,
      allMinutes: 0,
    );

    if (!mounted) return;

    setState(() {
      _rankingToggleSaving = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final originalMedia = MediaQuery.of(context);
    final h = originalMedia.size.height;
    final w = originalMedia.size.width;

    final compact = h < 860;
    final veryCompact = h < 780;

    final pagePadding = w < 380 ? 10.0 : 12.0;
    final gap = veryCompact ? 5.0 : 7.0;
    final fieldFont = veryCompact ? 14.0 : 15.0;
    final tileTitleFont = veryCompact ? 14.0 : 15.0;
    final tileSubFont = veryCompact ? 11.0 : 12.0;

    InputDecoration fieldDecoration(String label) {
      return InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
        contentPadding: EdgeInsets.symmetric(
          horizontal: 12,
          vertical: veryCompact ? 7 : 9,
        ),
      );
    }

    return MediaQuery(
      data: originalMedia.copyWith(
        textScaler: const TextScaler.linear(0.88),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Profile'),
          toolbarHeight: veryCompact ? 42 : 46,
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              pagePadding,
              veryCompact ? 2 : 5,
              pagePadding,
              4,
            ),
            child: Column(
              children: [
                TextField(
                  controller: _nicknameController,
                  style: TextStyle(fontSize: fieldFont),
                  decoration: fieldDecoration('Nickname'),
                ),
                SizedBox(height: gap),

                TextField(
                  controller: _cityController,
                  style: TextStyle(fontSize: fieldFont),
                  decoration: fieldDecoration('City'),
                ),
                SizedBox(height: gap),

                TextField(
                  controller: _countryController,
                  readOnly: true,
                  onTap: _showCountryPicker,
                  style: TextStyle(fontSize: fieldFont),
                  decoration: fieldDecoration('Country').copyWith(
                    hintText: 'Select country',
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_countryController.text.trim().isNotEmpty)
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            iconSize: 19,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                _countryController.clear();
                              });
                            },
                          ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          iconSize: 19,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                          icon: const Icon(Icons.public),
                          onPressed: _showCountryPicker,
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: veryCompact ? 7 : 9),

                SizedBox(
                  height: veryCompact ? 35 : 38,
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _saveProfile,
                    child: Text(
                      _saving ? 'Saving...' : 'Save profile',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                SizedBox(height: veryCompact ? 5 : 7),

                SwitchListTile(
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  contentPadding:
                  const EdgeInsets.symmetric(horizontal: 6),
                  title: Text(
                    'Show me in rankings',
                    style: TextStyle(fontSize: tileTitleFont),
                  ),
                  subtitle: Text(
                    _rankingToggleSaving
                        ? 'Updating ranking visibility...'
                        : 'Allow others to see your ranking',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: tileSubFont),
                  ),
                  value: _showInRankings,
                  onChanged: _rankingToggleSaving
                      ? null
                      : (value) {
                    _setShowInRankings(value);
                  },
                ),

                SizedBox(height: veryCompact ? 3 : 5),

                Card(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      SwitchListTile(
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        contentPadding:
                        const EdgeInsets.symmetric(horizontal: 8),
                        title: Text(
                          'Exclude sleep time',
                          style: TextStyle(fontSize: tileTitleFont),
                        ),
                        subtitle: Text(
                          'Sleep window will not count into stats, goals and rankings',
                          style: TextStyle(fontSize: tileSubFont),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        value: _excludeSleepTime,
                        onChanged: (value) async {
                          await _countingSettingsService
                              .saveExcludeSleepTime(value);
                          setState(() {
                            _excludeSleepTime = value;
                          });
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        enabled: _excludeSleepTime,
                        leading: const Icon(Icons.bedtime, size: 18),
                        title: Text(
                          'Sleep window',
                          style: TextStyle(
                            fontSize: veryCompact ? 13 : 14,
                          ),
                        ),
                        subtitle: Text(
                          '${_formatTimeOfDay(_sleepStart)} – ${_formatTimeOfDay(_sleepEnd)}',
                          style: TextStyle(
                            fontSize: veryCompact ? 11 : 12,
                          ),
                        ),
                      ),
                      SizedBox(
                        height: veryCompact ? 30 : 32,
                        child: Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                onPressed: _excludeSleepTime
                                    ? () => _pickSleepTime(isStart: true)
                                    : null,
                                child: const Text(
                                  'Start',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ),
                            Expanded(
                              child: TextButton(
                                onPressed: _excludeSleepTime
                                    ? () => _pickSleepTime(isStart: false)
                                    : null,
                                child: const Text(
                                  'End',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                ListTile(
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  contentPadding:
                  const EdgeInsets.symmetric(horizontal: 4),
                  leading: const Icon(
                    Icons.delete_forever,
                    color: Colors.red,
                    size: 20,
                  ),
                  title: const Text(
                    'Reset statistics',
                    style: TextStyle(color: Colors.red, fontSize: 13),
                  ),
                  subtitle: const Text(
                    'Delete stats and stop collecting',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11),
                  ),
                  onTap: _confirmResetAllData,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}