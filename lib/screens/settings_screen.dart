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
  bool _checkingNotifications = true;

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

        if (mounted) {
          setState(() {
            _notifPermission = enabled;
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
          _checkingNotifications = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _notifPermission = null;
          _checkingNotifications = false;
        });
      }
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

        _sectionCard(
          context,
          'Reminders & alerts',
          [
            _row(
              'Notifications',
              subtitle: _checkingNotifications
                  ? 'Checking notification permission...'
                  : _notifPermission == true
                      ? 'Allowed'
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
