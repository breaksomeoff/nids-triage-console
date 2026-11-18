import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:job_board/main.dart';
import 'package:job_board/src/api_client.dart';
import 'package:job_board/src/models.dart';
import 'package:job_board/src/session.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_backend.dart';

void main() {
  late FakeBackend backend;
  late List<Uri> openedUrls;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    backend = FakeBackend();
    openedUrls = [];
  });

  Future<Session> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);

    final api = ApiClient(
      Uri.parse('http://server/'),
      httpClient: backend.client,
    );
    final session = await Session.restore(api);
    await tester.pumpWidget(
      JobBoardApp(
        api: api,
        session: session,
        pickCv: () async => PickedCv(
          name: 'cv_mario_rossi.pdf',
          bytes: utf8.encode('%PDF-1.4 fake'),
        ),
        openUrl: (uri) async {
          openedUrls.add(uri);
          return true;
        },
      ),
    );
    await tester.pumpAndSettle();
    return session;
  }

  Future<void> fill(WidgetTester tester, String label, String text) =>
      tester.enterText(find.widgetWithText(TextFormField, label), text);

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text).last);
    await tester.tap(find.text(text).last);
    await tester.pumpAndSettle();
  }

  Future<void> registerAndLogin(WidgetTester tester) async {
    await tapText(tester, 'Aziende');
    await tapText(tester, 'Registra la tua azienda');
    await fill(tester, 'Nome azienda', 'Acme Srl');
    await fill(tester, 'Email', 'hr@acme.it');
    await fill(tester, 'Password', 'password1');
    await fill(tester, 'Conferma password', 'password1');
    await tapText(tester, 'Crea account');
    expect(
      find.text('Account creato. Ora accedi con email e password.'),
      findsOneWidget,
    );

    await fill(tester, 'Password', 'password1');
    await tapText(tester, 'Accedi');
  }

  Future<void> publish(WidgetTester tester, String title) async {
    await tapText(tester, 'Nuovo annuncio');
    await fill(tester, 'Titolo', title);
    await fill(tester, 'Sede (facoltativa)', 'Salerno');
    await fill(tester, 'Descrizione', 'App mobile per clienti enterprise.');
    await tapText(tester, 'Pubblica annuncio');
  }

  /// Lets the confirmation snackbar time out, as a user would.
  Future<void> waitSnackBar(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  }

  testWidgets('empty board explains that companies publish jobs', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(find.text('Ancora nessun annuncio'), findsOneWidget);
    expect(find.text('Aziende'), findsOneWidget);
  });

  testWidgets('S1: register, log in, publish; the job is on the board', (
    tester,
  ) async {
    await pumpApp(tester);
    await registerAndLogin(tester);

    expect(find.text('Area azienda'), findsOneWidget);
    expect(find.text('Acme Srl'), findsOneWidget);

    await publish(tester, 'Sviluppatore Flutter');
    expect(
      find.text('"Sviluppatore Flutter" è pubblicato in bacheca.'),
      findsOneWidget,
    );
    expect(find.text('Sviluppatore Flutter'), findsWidgets);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Bacheca Lavoro'), findsOneWidget);
    expect(find.text('Sviluppatore Flutter'), findsOneWidget);
    expect(find.text('1 annuncio'), findsOneWidget);
  });

  testWidgets('S1: wrong password and duplicate email show server errors', (
    tester,
  ) async {
    await pumpApp(tester);
    await registerAndLogin(tester);
    await tapText(tester, 'Esci');

    await tapText(tester, 'Aziende');
    await fill(tester, 'Email', 'hr@acme.it');
    await fill(tester, 'Password', 'sbagliata');
    await tapText(tester, 'Accedi');
    expect(find.text('Email o password non corretti.'), findsOneWidget);

    await tapText(tester, 'Registra la tua azienda');
    await fill(tester, 'Nome azienda', 'Acme 2');
    await fill(tester, 'Email', 'hr@acme.it');
    await fill(tester, 'Password', 'password1');
    await fill(tester, 'Conferma password', 'password1');
    await tapText(tester, 'Crea account');
    expect(
      find.text('Esiste già un account con questa email.'),
      findsOneWidget,
    );
  });

  testWidgets('S2: a candidate applies without logging in', (tester) async {
    backend.companies.add({'id': 99, 'name': 'Acme Srl', 'email': 'a@a.it'});
    backend.jobs.add({
      'id': 100,
      'companyId': 99,
      'companyName': 'Acme Srl',
      'title': 'Sviluppatore Flutter',
      'description': 'App mobile per clienti enterprise.',
      'location': 'Salerno',
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    });
    await pumpApp(tester);

    await tapText(tester, 'Sviluppatore Flutter');
    expect(find.text('App mobile per clienti enterprise.'), findsOneWidget);
    await tapText(tester, 'Candidati');

    // Missing data and CV are reported, nothing is sent.
    await tapText(tester, 'Invia candidatura');
    expect(find.text('Il nome è obbligatorio'), findsOneWidget);
    expect(find.text('Allega il curriculum in PDF'), findsOneWidget);
    expect(backend.applications, isEmpty);

    await fill(tester, 'Nome', 'Mario');
    await fill(tester, 'Cognome', 'Rossi');
    await fill(tester, 'Email', 'mario.rossi@example.com');
    await tapText(tester, 'Allega curriculum');
    expect(find.text('cv_mario_rossi.pdf'), findsOneWidget);
    await tapText(tester, 'Invia candidatura');

    expect(
      find.textContaining('Candidatura inviata a Acme Srl'),
      findsOneWidget,
    );
    expect(backend.applications.single['lastName'], 'Rossi');
    expect(backend.applications.single['cvFilename'], 'cv_mario_rossi.pdf');
  });

  testWidgets('S3: see applications, open the CV, log out', (tester) async {
    final session = await pumpApp(tester);
    await registerAndLogin(tester);
    await publish(tester, 'Sviluppatore Flutter');
    backend.applications.add({
      'id': 500,
      'jobId': backend.jobs.single['id'],
      'firstName': 'Mario',
      'lastName': 'Rossi',
      'email': 'mario.rossi@example.com',
      'cvFilename': 'cv_mario_rossi.pdf',
      'cvSize': 2048,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    });
    await tester.drag(find.byType(ListView).first, const Offset(0, 400));
    await tester.pumpAndSettle();
    expect(find.text('1 candidatura'), findsOneWidget);

    await tapText(tester, 'Sviluppatore Flutter');
    expect(find.text('1 candidatura ricevuta'), findsOneWidget);
    await waitSnackBar(tester);
    await tapText(tester, 'Mario Rossi');
    expect(find.text('mario.rossi@example.com'), findsOneWidget);
    await tapText(tester, 'Apri curriculum');
    expect(openedUrls.single.path, '/api/applications/500/cv');
    expect(openedUrls.single.queryParameters['token'], isNotEmpty);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tapText(tester, 'Esci');

    expect(find.text('Bacheca Lavoro'), findsOneWidget);
    expect(find.text('Sei uscito dall\'area aziende.'), findsOneWidget);
    expect(find.text('Area azienda'), findsNothing);
    expect(find.text('Aziende'), findsOneWidget);
    expect(session.isLoggedIn, isFalse);
    expect(backend.sessions, isEmpty);
  });

  testWidgets('session survives an app restart', (tester) async {
    await pumpApp(tester);
    await registerAndLogin(tester);
    await pumpApp(tester);
    expect(find.text('Area azienda'), findsOneWidget);
  });
}
