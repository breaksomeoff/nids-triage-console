import 'package:flutter/material.dart';

import '../api_client.dart';
import '../app_scope.dart';
import '../format.dart';
import '../models.dart';
import '../widgets/common.dart';

const _maxCvBytes = 5 * 1024 * 1024;

/// Application form (R6). Pops with `true` once the server has saved it.
class ApplyScreen extends StatefulWidget {
  const ApplyScreen({super.key, required this.job});

  final Job job;

  @override
  State<ApplyScreen> createState() => _ApplyScreenState();
}

class _ApplyScreenState extends State<ApplyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cvFieldKey = GlobalKey<FormFieldState<PickedCv>>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  var _autovalidate = AutovalidateMode.disabled;
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _pickCv() async {
    final cv = await AppScope.of(context).pickCv();
    if (cv != null) _cvFieldKey.currentState!.didChange(cv);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      setState(() => _autovalidate = AutovalidateMode.onUserInteraction);
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await AppScope.of(context).api.apply(
        jobId: widget.job.id,
        firstName: _firstName.text.trim(),
        lastName: _lastName.text.trim(),
        email: _email.text.trim(),
        cv: _cvFieldKey.currentState!.value!,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() {
        _sending = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Candidatura')),
      body: Form(
        key: _formKey,
        autovalidateMode: _autovalidate,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            HeaderCard(
              icon: Icons.work_outline,
              label: widget.job.companyName,
              title: widget.job.title,
            ),
            const SectionTitle('I tuoi dati'),
            TextFormField(
              controller: _firstName,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.givenName],
              decoration: const InputDecoration(
                labelText: 'Nome',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (v) => validateRequired(v, 'Il nome è obbligatorio'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _lastName,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.familyName],
              decoration: const InputDecoration(
                labelText: 'Cognome',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
              validator: (v) =>
                  validateRequired(v, 'Il cognome è obbligatorio'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.alternate_email),
              ),
              validator: validateEmail,
            ),
            const SectionTitle('Curriculum'),
            FormField<PickedCv>(
              key: _cvFieldKey,
              validator: (cv) {
                if (cv == null) return 'Allega il curriculum in PDF';
                if (cv.bytes.length > _maxCvBytes) {
                  return 'Il file supera i 5 MB';
                }
                return null;
              },
              builder: (field) => _CvPickerTile(
                cv: field.value,
                error: field.errorText,
                onPick: _sending ? null : _pickCv,
              ),
            ),
            FormErrorText(_error),
            const SizedBox(height: 24),
            BusyButton(
              label: 'Invia candidatura',
              icon: Icons.send,
              busy: _sending,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

class _CvPickerTile extends StatelessWidget {
  const _CvPickerTile({required this.cv, required this.error, this.onPick});

  final PickedCv? cv;
  final String? error;
  final VoidCallback? onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final picked = cv;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: error != null ? colors.error : colors.outlineVariant,
            ),
          ),
          child: ListTile(
            onTap: onPick,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 6,
            ),
            leading: Icon(
              picked == null ? Icons.upload_file : Icons.picture_as_pdf,
              color: picked == null ? colors.primary : colors.error,
              size: 32,
            ),
            title: Text(
              picked == null ? 'Allega curriculum' : picked.name,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              picked == null
                  ? 'File PDF, massimo 5 MB'
                  : '${formatBytes(picked.bytes.length)} · tocca per cambiarlo',
            ),
            trailing: Icon(picked == null ? Icons.add : Icons.swap_horiz),
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 6),
            child: Text(
              error!,
              style: theme.textTheme.bodySmall?.copyWith(color: colors.error),
            ),
          ),
      ],
    );
  }
}
