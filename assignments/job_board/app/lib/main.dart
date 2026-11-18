import 'package:flutter/material.dart';

import 'src/api_client.dart';
import 'src/app_scope.dart';
import 'src/config.dart';
import 'src/screens/board_screen.dart';
import 'src/session.dart';
import 'src/theme.dart';
import 'src/widgets/common.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final api = ApiClient(apiBaseUrl());
  final session = await Session.restore(api);
  runApp(JobBoardApp(api: api, session: session));
}

class JobBoardApp extends StatefulWidget {
  const JobBoardApp({
    super.key,
    required this.api,
    required this.session,
    this.pickCv = pickPdf,
    this.openUrl = openInBrowser,
  });

  final ApiClient api;
  final Session session;
  final CvPicker pickCv;
  final UrlOpener openUrl;

  @override
  State<JobBoardApp> createState() => _JobBoardAppState();
}

class _JobBoardAppState extends State<JobBoardApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _routeObserver = RouteObserver<ModalRoute<void>>();
  late bool _wasLoggedIn = widget.session.isLoggedIn;

  @override
  void initState() {
    super.initState();
    widget.session.addListener(_onSessionChanged);
  }

  @override
  void dispose() {
    widget.session.removeListener(_onSessionChanged);
    super.dispose();
  }

  /// After logout (or an expired session) go back to the public board: no
  /// reserved screen stays reachable.
  void _onSessionChanged() {
    final loggedIn = widget.session.isLoggedIn;
    if (_wasLoggedIn && !loggedIn) {
      final navigator = _navigatorKey.currentState;
      navigator?.popUntil((route) => route.isFirst);
      final context = _navigatorKey.currentContext;
      if (context != null) {
        showMessage(
          context,
          widget.session.expired
              ? 'Sessione scaduta: accedi di nuovo.'
              : 'Sei uscito dall\'area aziende.',
          icon: Icons.logout,
        );
      }
    }
    _wasLoggedIn = loggedIn;
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      api: widget.api,
      session: widget.session,
      routeObserver: _routeObserver,
      pickCv: widget.pickCv,
      openUrl: widget.openUrl,
      child: MaterialApp(
        title: 'Bacheca Lavoro',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        navigatorKey: _navigatorKey,
        navigatorObservers: [_routeObserver],
        home: const BoardScreen(),
      ),
    );
  }
}
