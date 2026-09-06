import 'package:flutter/material.dart';
import '../models.dart';
import '../utils.dart';

class TaskTile extends StatelessWidget {
  const TaskTile({
    super.key,
    required this.task,
    required this.onToggle,
    required this.onTap,
    required this.onDelete,
  });

  final Task task;
  final VoidCallback onToggle;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final due = task.dueDateTime;
    final now = DateTime.now();
    final overdue = due != null && !task.done && due.isBefore(now) && !isSameDay(due, now);
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55);

    String? metaText;
    if (due != null) {
      metaText = fmtDateShort(due) + (task.time != null && task.time!.isNotEmpty ? ', ${fmtTime(due)}' : '');
    }

    return ListTile(
      onTap: onTap,
      leading: GestureDetector(
        onTap: onToggle,
        child: Container(
          width: 26,
          height: 26,
          margin: const EdgeInsets.only(top: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: task.done ? Colors.transparent : Theme.of(context).dividerColor, width: 2),
            color: task.done ? Theme.of(context).colorScheme.secondary : Colors.transparent,
          ),
          child: task.done ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
        ),
      ),
      title: Text(
        task.title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          decoration: task.done ? TextDecoration.lineThrough : null,
          color: task.done ? muted : null,
        ),
      ),
      subtitle: metaText == null
          ? null
          : Row(
              children: [
                if (overdue) ...[
                  Container(width: 6, height: 6, decoration: BoxDecoration(color: Colors.red.shade400, shape: BoxShape.circle)),
                  const SizedBox(width: 5),
                ],
                Text(metaText, style: TextStyle(color: muted, fontSize: 12.5)),
                if (task.reminder) ...[
                  const SizedBox(width: 6),
                  Icon(Icons.notifications_outlined, size: 13, color: muted),
                ],
              ],
            ),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline, size: 20),
        onPressed: onDelete,
      ),
    );
  }
}
