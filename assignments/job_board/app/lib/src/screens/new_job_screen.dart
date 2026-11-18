import 'package:flutter/material.dart';

import '../api_client.dart';
import '../app_scope.dart';
import '../format.dart';
import '../widgets/common.dart';

/// Publishing form (R4). Pops with the published job.
class NewJobScreen extends StatefulWidget {
  const NewJobScreen({super.key});

  @override
  State<NewJobScreen> createState() => _NewJobScreenState();
}

class _NewJobScreenState extends State<NewJobScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _location = TextEditingController();
  final _description = TextEditingController();
  var _autovalidate = AutovalidateMode.disabled;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _location.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _publish() async {
    if (!_formKey.currentState!.validate()) {
      setState(() => _autovalidate = AutovalidateMode.onUserInteraction);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final job = await AppScope.of(context).api.createJob(
        title: _title.text.trim(),
        description: _description.text.trim(),
        location: _location.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(job);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nuovo annuncio')),
      body: Form(
        key: _formKey,
        autovalidateMode: _autovalidate,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              maxLength: 120,
              decoration: const InputDecoration(
                labelText: 'Titolo',
                hintText: 'Es. Sviluppatore Flutter junior',
                prefixIcon: Icon(Icons.title),
              ),
              validator: (v) => validateRequired(v, 'Il titolo è obbligatorio'),
            ),
            const SizedBox(height: 4),
            TextFormField(
              controller: _location,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Sede (facoltativa)',
                hintText: 'Es. Salerno, ibrido',
                prefixIcon: Icon(Icons.place_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              textCapitalization: TextCapitalization.sentences,
              minLines: 6,
              maxLines: 14,
              decoration: const InputDecoration(
                labelText: 'Descrizione',
                hintText: 'Ruolo, requisiti, cosa offrite…',
                alignLabelWithHint: true,
              ),
              validator: (v) =>
                  validateRequired(v, 'La descrizione è obbligatoria'),
            ),
            FormErrorText(_error),
            const SizedBox(height: 24),
            BusyButton(
              label: 'Pubblica annuncio',
              icon: Icons.campaign,
              busy: _busy,
              onPressed: _publish,
            ),
          ],
        ),
      ),
    );
  }
}
