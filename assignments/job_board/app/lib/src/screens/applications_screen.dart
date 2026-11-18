import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../format.dart';
import '../models.dart';
import '../widgets/common.dart';
import 'application_detail_screen.dart';

/// Applications received for one of the company's jobs (R7).
class ApplicationsScreen extends StatefulWidget {
  const ApplicationsScreen({super.key, required this.job});

  final Job job;

  @override
  State<ApplicationsScreen> createState() => _ApplicationsScreenState();
}

class _ApplicationsScreenState extends State<ApplicationsScreen>
    with ReloadOnReturn {
  Future<List<JobApplication>>? _applications;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _applications ??= AppScope.of(context).api.applications(widget.job.id);
  }

  @override
  void reload() {
    final applications = AppScope.of(context).api.applications(widget.job.id);
    setState(() {
      _applications = applications;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Candidature')),
      body: RefreshIndicator(
        onRefresh: () async {
          reload();
          await _applications;
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            HeaderCard(
              icon: Icons.work_outline,
              label: 'Annuncio',
              title: widget.job.title,
              subtitle: widget.job.location.isEmpty
                  ? null
                  : widget.job.location,
            ),
            AsyncList<JobApplication>(
              future: _applications,
              onRetry: reload,
              builder: (context, applications) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SectionTitle(
                    applications.length == 1
                        ? '1 candidatura ricevuta'
                        : '${applications.length} candidature ricevute',
                  ),
                  if (applications.isEmpty)
                    const MessageView(
                      icon: Icons.hourglass_empty,
                      title: 'Ancora nessuna candidatura',
                      message:
                          'Le candidature a questo annuncio compariranno qui.',
                    )
                  else
                    for (final a in applications)
                      _ApplicationTile(application: a, job: widget.job),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ApplicationTile extends StatelessWidget {
  const _ApplicationTile({required this.application, required this.job});

  final JobApplication application;
  final Job job;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: colors.secondaryContainer,
          foregroundColor: colors.onSecondaryContainer,
          child: Text(application.initials),
        ),
        title: Text(
          application.fullName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${application.email}\n${formatRelativeDate(application.createdAt)}',
        ),
        isThreeLine: true,
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) =>
                ApplicationDetailScreen(application: application, job: job),
          ),
        ),
      ),
    );
  }
}
