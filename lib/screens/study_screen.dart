import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models.dart';
import '../utils.dart';
import '../widgets/empty_state.dart';

class StudyScreen extends StatefulWidget {
  const StudyScreen({super.key});
  @override
  State<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends State<StudyScreen> {
  Timer? _ticker;
  final _subjectCtrl = TextEditingController();
  final _topicCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    // This only drives the on-screen display every second. The actual
    // elapsed time is always computed from real timestamps (see
    // ActiveSession.elapsedMs), so it stays accurate even if the UI timer
    // is delayed or the app is briefly backgrounded.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _subjectCtrl.dispose();
    _topicCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final active = state.activeSession;
    final history = [...state.sessions]..sort((a, b) => DateTime.parse(b.endedAt).compareTo(DateTime.parse(a.endedAt)));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: active == null ? _buildStartForm(context, state) : _buildActive(context, state, active),
          ),
        ),
        const SizedBox(height: 20),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text('History', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, letterSpacing: 0.4)),
        ),
        const SizedBox(height: 8),
        if (history.isEmpty)
          const EmptyState(icon: Icons.timer_outlined, title: 'No study sessions yet', message: '')
        else
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Column(
                children: history.take(12).map((s) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s.subject.isEmpty ? 'Focus session' : s.subject, style: const TextStyle(fontWeight: FontWeight.w700)),
                              Text(
                                DateTime.parse(s.endedAt).toLocal().toString().split(' ').first,
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                        Chip(label: Text(durationHuman(s.durationMs))),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStartForm(BuildContext context, AppState state) {
    return Column(
      children: [
        TextField(
          controller: _subjectCtrl,
          decoration: const InputDecoration(labelText: 'Subject', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _topicCtrl,
          decoration: const InputDecoration(labelText: 'Topic (optional)', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 20),
        FloatingActionButton(
          heroTag: 'start',
          backgroundColor: Theme.of(context).colorScheme.secondary,
          onPressed: () => state.startSession(_subjectCtrl.text.trim(), _topicCtrl.text.trim()),
          child: const Icon(Icons.play_arrow),
        ),
        const SizedBox(height: 8),
        const Text('Start a focus session', style: TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildActive(BuildContext context, AppState state, ActiveSession active) {
    final elapsed = active.elapsedMs();
    return Column(
      children: [
        Text(
          active.subject.isEmpty ? 'Focus session' : active.subject,
          style: const TextStyle(color: Colors.grey, fontSize: 13),
        ),
        const SizedBox(height: 8),
        Text(durationStr(elapsed), style: const TextStyle(fontSize: 52, fontWeight: FontWeight.w600)),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FloatingActionButton(
              heroTag: 'pauseresume',
              backgroundColor: active.status == 'running' ? Colors.amber : Theme.of(context).colorScheme.secondary,
              onPressed: () => active.status == 'running' ? state.pauseSession() : state.resumeSession(),
              child: Icon(active.status == 'running' ? Icons.pause : Icons.play_arrow),
            ),
            const SizedBox(width: 16),
            FloatingActionButton(
              heroTag: 'stop',
              backgroundColor: Theme.of(context).colorScheme.error,
              onPressed: () => state.stopSession(),
              child: const Icon(Icons.stop),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Chip(label: Text(active.status == 'running' ? 'Running' : 'Paused')),
      ],
    );
  }
}
