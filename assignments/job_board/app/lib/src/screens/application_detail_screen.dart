import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../format.dart';
import '../models.dart';
import '../widgets/common.dart';

/// Candidate's data and the attached CV (R7).
class ApplicationDetailScreen extends StatelessWidget {
  const ApplicationDetailScreen({
    super.key,
    required this.application,
    required this.job,
  });

  final JobApplication application;
  final Job job;

  Future<void> _openCv(BuildContext context) async {
    final scope = AppScope.of(context);
    // No await before this call: on the web the new tab must open within the
    // tap, or the browser blocks it as a pop-up.
    final opened = await scope.openUrl(scope.api.cvUrl(application.id));
    if (!opened && context.mounted) {
      showMessage(
        context,
        'Impossibile aprire il curriculum.',
        icon: Icons.error_outline,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Candidato')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          HeaderCard(
            initials: application.initials,
            label: 'Candidatura a "${job.title}"',
            title: application.fullName,
          ),
          const SectionTitle('Dati'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(application.firstName),
                  subtitle: const Text('Nome'),
                ),
                ListTile(
                  leading: const Icon(Icons.badge_outlined),
                  title: Text(application.lastName),
                  subtitle: const Text('Cognome'),
                ),
                ListTile(
                  leading: const Icon(Icons.alternate_email),
                  title: SelectableText(application.email),
                  subtitle: const Text('Email'),
                ),
                ListTile(
                  leading: const Icon(Icons.event_outlined),
                  title: Text(formatDate(application.createdAt)),
                  subtitle: const Text('Ricevuta il'),
                ),
              ],
            ),
          ),
          const SectionTitle('Curriculum'),
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 6,
              ),
              leading: Icon(
                Icons.picture_as_pdf,
                color: colors.error,
                size: 32,
              ),
              title: Text(
                application.cvFilename,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text('PDF · ${formatBytes(application.cvSize)}'),
              trailing: const Icon(Icons.open_in_new),
              onTap: () => _openCv(context),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => _openCv(context),
            icon: const Icon(Icons.description_outlined),
            label: const Text('Apri curriculum'),
          ),
        ],
      ),
    );
  }
}
