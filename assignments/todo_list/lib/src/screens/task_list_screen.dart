import 'package:flutter/material.dart';

import '../models/task.dart';
import 'new_task_screen.dart';

/// List of all tasks with the completed/total count (S2), toggle (S3),
/// delete with confirmation (S4) and the entry point for creation (S1).
class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key, this.initialTasks = const []});

  final List<Task> initialTasks;

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  late final List<Task> _tasks = [...widget.initialTasks];

  int get _completedCount => _tasks.where((t) => t.done).length;

  Future<void> _addTask() async {
    final task = await Navigator.of(
      context,
    ).push<Task>(MaterialPageRoute(builder: (_) => const NewTaskScreen()));
    // null when the user went back without confirming: nothing to do.
    if (task == null || !mounted) return;

    setState(() => _tasks.add(task));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('Attività "${task.title}" aggiunta')),
      );
  }

  void _toggle(Task task) {
    setState(() => task.done = !task.done);
  }

  Future<void> _delete(Task task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminare l\'attività?'),
        content: Text('"${task.title}" verrà eliminata definitivamente.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      setState(() => _tasks.remove(task));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Le mie attività'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(32),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Completate: $_completedCount su ${_tasks.length}',
              key: const Key('completed-count'),
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
        ),
      ),
      body: _tasks.isEmpty
          ? const _EmptyState()
          : ListView.separated(
              padding: const EdgeInsets.only(bottom: 88),
              itemCount: _tasks.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final task = _tasks[index];
                return _TaskTile(
                  task: task,
                  onToggle: () => _toggle(task),
                  onDelete: () => _delete(task),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addTask,
        icon: const Icon(Icons.add),
        label: const Text('Nuova attività'),
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({
    required this.task,
    required this.onToggle,
    required this.onDelete,
  });

  final Task task;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return ListTile(
      onTap: onToggle,
      leading: Checkbox(value: task.done, onChanged: (_) => onToggle()),
      title: Text(
        task.title,
        style: TextStyle(
          decoration: task.done ? TextDecoration.lineThrough : null,
          color: task.done ? colors.onSurfaceVariant : null,
          fontWeight: task.important ? FontWeight.bold : null,
        ),
      ),
      subtitle: Row(
        children: [
          Text(task.done ? 'Completata' : 'Da fare'),
          if (task.important) ...[
            const SizedBox(width: 12),
            Icon(Icons.star, size: 16, color: colors.error),
            const SizedBox(width: 4),
            Text('Importante', style: TextStyle(color: colors.error)),
          ],
        ],
      ),
      trailing: IconButton(
        tooltip: 'Elimina',
        icon: const Icon(Icons.delete_outline),
        onPressed: onDelete,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.checklist,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text('Nessuna attività', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text(
              'Tocca "Nuova attività" in basso per aggiungerne una.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
