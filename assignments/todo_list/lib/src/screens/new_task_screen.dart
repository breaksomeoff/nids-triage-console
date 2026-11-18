import 'package:flutter/material.dart';

import '../models/task.dart';

/// Creation form (S1). Pops with the new [Task] on confirm, or with null when
/// the user goes back without confirming.
class NewTaskScreen extends StatefulWidget {
  const NewTaskScreen({super.key});

  @override
  State<NewTaskScreen> createState() => _NewTaskScreenState();
}

class _NewTaskScreenState extends State<NewTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  bool _important = false;

  // Validate only after the first confirm attempt; from then on the error is
  // re-checked as the user types, so it disappears once the title is fixed.
  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _confirm() {
    if (!_formKey.currentState!.validate()) {
      setState(() => _autovalidateMode = AutovalidateMode.onUserInteraction);
      return;
    }
    Navigator.of(
      context,
    ).pop(Task(title: _titleController.text.trim(), important: _important));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nuova attività')),
      body: Form(
        key: _formKey,
        autovalidateMode: _autovalidateMode,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titleController,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _confirm(),
              decoration: const InputDecoration(
                labelText: 'Titolo',
                hintText: 'Es. Comprare il latte',
                border: OutlineInputBorder(),
              ),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Il titolo è obbligatorio'
                  : null,
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.star_outline),
              title: const Text('Importante'),
              value: _important,
              onChanged: (value) => setState(() => _important = value),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _confirm,
              icon: const Icon(Icons.check),
              label: const Text('Aggiungi'),
            ),
          ],
        ),
      ),
    );
  }
}
