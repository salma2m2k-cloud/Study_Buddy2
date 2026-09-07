import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api_service.dart';
import '../app_state.dart';
import '../notification_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _api = ApiService();
  final _notifications = NotificationService();

  BackendStatus? _status;
  bool _checkingStatus = true;

  bool? _notifPermission;
  bool? _exactAlarmPermission;
  bool _checkingNotifications = true;
  bool _sendingTestNotification = false;

  @override
  void initState() {
    super.initState();
    _refreshStatus();
    _refreshNotificationPermission();
  }

  Future<void> _refreshStatus() async {
    if (mounted) {
      setState(() {
        _checkingStatus = true;
      });
    }

    final status = await _api.fetchStatus();

    if (mounted) {
      setState(() {
        _status = status;
        _checkingStatus = false;
      });
    }
  }

  Future<void> _refreshNotificationPermission() async {
    if (mounted) {
      setState(() {
        _checkingNotifications = true;
      });
    }

    try {
      await _notifications.init();

      final androidImpl =
          _notifications.androidImplementation;

      if (androidImpl != null) {
        final enabled =
            await androidImpl.areNotificationsEnabled();

        // Notification permission and exact-alarm permission are two
        // separate OS toggles on Android 12+. A user can have
        // notifications "enabled" and reminders still never fire because
        // "Alarms & reminders" is off — so we check both instead of only
        // reporting the first one.
        final exactAlarms =
            await _notifications.canScheduleExactAlarms();

        if (mounted) {
          setState(() {
            _notifPermission = enabled;
            _exactAlarmPermission = exactAlarms;
            _checkingNotifications = false;
          });
        }

        return;
      }

      // On iOS we don't use the unsupported API from
      // flutter_local_notifications 17.2.4.
      //
      // The permission button below can still request
      // notification permission normally.
      if (mounted) {
        setState(() {
          _notifPermission = null;
          _exactAlarmPermission = null;
          _checkingNotifications = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _notifPermission = null;
          _exactAlarmPermission = null;
          _checkingNotifications = false;
        });
      }
    }
  }

  Future<void> _sendTestNotification() async {
    setState(() {
      _sendingTestNotification = true;
    });

    try {
      await _notifications.showTestNotification();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Test notification sent — check your notification shade.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not send test notification: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _sendingTestNotification = false;
        });
      }
    }
  }

  Future<void> _askForExactAlarms() async {
    final androidImpl = _notifications.androidImplementation;

    if (androidImpl == null) return;

    try {
      // On Android 12+ this opens the system "Alarms & reminders" screen
      // for this app directly — this is the ONE permission that governs
      // whether task/class reminders can ever actually fire on time.
      await androidImpl.requestExactAlarmsPermission();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open alarm settings: $e'),
          ),
        );
      }
    } finally {
      // The system screen is opened and control returns to us before the
      // user has necessarily finished — re-check shortly after so the
      // banner updates once they come back.
      await _refreshNotificationPermission();
    }
  }

  Future<void> _askForNotifications() async {
    try {
      await _notifications.init();

      final granted =
          await _notifications.requestPermissions();

      if (mounted) {
        setState(() {
          _notifPermission = granted;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              granted
                  ? 'Notifications enabled'
                  : 'Notifications not enabled — you can allow them later in your phone settings.',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not request notification permission. Please try again.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final settings = state.settings;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionCard(
          context,
          'Appearance',
          [
            _row(
              'Theme',
              trailing: DropdownButton<String>(
                value: settings.theme,
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(
                    value: 'system',
                    child: Text('System'),
                  ),
                  DropdownMenuItem(
                    value: 'light',
                    child: Text('Light'),
                  ),
                  DropdownMenuItem(
                    value: 'dark',
                    child: Text('Dark'),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) {
                    state.updateSettings((s) {
                      s.theme = v;
                      return s;
                    });
                  }
                },
              ),
            ),
          ],
        ),

        const SizedBox(height: 14),

        // Unmissable banner: this is the #1 reason a task/class reminder
        // never fires while notifications otherwise look "enabled". It
        // only shows once we've actually checked and confirmed it's off.
        if (_exactAlarmPermission == false)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Card(
              color: Theme.of(context)
                  .colorScheme
                  .errorContainer
                  .withValues(alpha: 0.6),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.alarm_off_rounded,
                          color:
                              Theme.of(context).colorScheme.error,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Reminders can\'t ring yet',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Task and class reminders need the "Alarms & '
                      'reminders" permission to ring like an alarm at '
                      'the exact time. This is separate from regular '
                      'notification permission and your phone likely '
                      'has it turned off.',
                      style: TextStyle(fontSize: 12.5),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton.icon(
                        onPressed: _askForExactAlarms,
                        icon: const Icon(Icons.alarm_add_rounded),
                        label: const Text('Turn on alarm reminders'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        _sectionCard(
          context,
          'Reminders & alerts',
          [
            _row(
              'Notifications',
              subtitle: _checkingNotifications
                  ? 'Checking notification permission...'
                  : _notifPermission == true
                      ? (_exactAlarmPermission == false
                          ? 'Allowed, but alarms are off — see the banner above'
                          : 'Allowed')
                      : _notifPermission == false
                          ? 'Not allowed — check your phone\'s system settings'
                          : 'Tap to allow reminders to notify you',
              trailing: FilledButton.tonal(
                onPressed: _checkingNotifications
                    ? null
                    : _askForNotifications,
                child: Text(
                  _checkingNotifications
                      ? 'Checking'
                      : _notifPermission == true
                          ? 'Enabled'
                          : 'Enable',
                ),
              ),
            ),

            const Divider(height: 1),

            _row(
              'Test notification',
              subtitle:
                  'Sends one immediately, so you can tell whether '
                  'notifications work at all before checking reminders',
              trailing: FilledButton.tonal(
                onPressed: _sendingTestNotification
                    ? null
                    : _sendTestNotification,
                child: Text(
                  _sendingTestNotification ? 'Sending' : 'Send',
                ),
              ),
            ),

            const Divider(height: 1),

            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Sound'),
              subtitle: const Text(
                'Play a sound when a reminder fires',
              ),
              value: settings.sound,
              onChanged: (v) {
                state.updateSettings((s) {
                  s.sound = v;
                  return s;
                });
              },
            ),

            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Vibration'),
              subtitle: const Text(
                'Vibrate on supported devices',
              ),
              value: settings.vibration,
              onChanged: (v) {
                state.updateSettings((s) {
                  s.vibration = v;
                  return s;
                });
              },
            ),

            _row(
              'Remind me before',
              subtitle:
                  'Default lead time for new tasks & classes',
              trailing: DropdownButton<int>(
                value: settings.reminderLead,
                underline: const SizedBox.shrink(),
                items: const [
                  0,
                  5,
                  10,
                  15,
                  30,
                  60,
                ]
                    .map(
                      (v) => DropdownMenuItem(
                        value: v,
                        child: Text(
                          v == 0
                              ? 'At the time'
                              : '$v min',
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) {
                    state.updateSettings((s) {
                      s.reminderLead = v;
                      return s;
                    });
                  }
                },
              ),
            ),
          ],
        ),

        const SizedBox(height: 14),

        _sectionCard(
          context,
          'AI Buddy',
          [
            _row(
              'Connection',
              subtitle: _checkingStatus
                  ? 'Checking...'
                  : (_status?.reachable != true
                      ? 'Can\'t reach the backend. Check your internet connection.'
                      : (_status!.aiConfigured
                          ? 'Connected to OpenRouter (minimax/minimax-m3:free).'
                          : 'No API key configured on the backend yet.')),
              trailing: Chip(
                label: Text(
                  _checkingStatus
                      ? 'Checking'
                      : (_status?.reachable != true
                          ? 'Unreachable'
                          : (_status!.aiConfigured
                              ? 'Ready'
                              : 'Needs API key')),
                ),
                backgroundColor: _checkingStatus
                    ? null
                    : (_status?.reachable != true
                        ? Theme.of(context)
                            .colorScheme
                            .error
                            .withValues(alpha: 0.15)
                        : (_status!.aiConfigured
                            ? Theme.of(context)
                                .colorScheme
                                .secondary
                                .withValues(alpha: 0.15)
                            : Colors.amber
                                .withValues(alpha: 0.2))),
              ),
            ),

            const SizedBox(height: 6),

            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _refreshStatus,
                child: const Text('Refresh status'),
              ),
            ),
          ],
        ),

        const SizedBox(height: 14),

        _sectionCard(
          context,
          'Data',
          [
            _row(
              'Storage',
              subtitle:
                  'Everything is saved on this device automatically — no account, no cloud.',
              trailing: Chip(
                label: const Text('On-device'),
                backgroundColor: Theme.of(context)
                    .colorScheme
                    .secondary
                    .withValues(alpha: 0.15),
              ),
            ),

            const Divider(height: 1),

            _row(
              'Clear all data',
              subtitle:
                  'Permanently deletes tasks, classes, notes, sessions and chats from this device.',
              trailing: FilledButton.tonal(
                style: ButtonStyle(
                  backgroundColor: WidgetStatePropertyAll(
                    Theme.of(context)
                        .colorScheme
                        .error
                        .withValues(alpha: 0.12),
                  ),
                  foregroundColor: WidgetStatePropertyAll(
                    Theme.of(context)
                        .colorScheme
                        .error,
                  ),
                ),
                onPressed: () =>
                    _confirmClear(context, state),
                child: const Text('Clear data'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _confirmClear(
    BuildContext context,
    AppState state,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear all data?'),
        content: const Text(
          'This permanently deletes all tasks, classes, notes, study sessions and chats from this device. This can\'t be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor:
                  Theme.of(context).colorScheme.error,
            ),
            onPressed: () =>
                Navigator.of(ctx).pop(true),
            child: const Text('Clear data'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await state.clearAllData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All data cleared'),
          ),
        );
      }
    }
  }

  Widget _sectionCard(
    BuildContext context,
    String title,
    List<Widget> children,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 6),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _row(
    String label, {
    String? subtitle,
    required Widget trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 8,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}
