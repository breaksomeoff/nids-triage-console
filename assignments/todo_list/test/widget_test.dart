import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:todo_list/main.dart';
import 'package:todo_list/src/models/task.dart';
import 'package:todo_list/src/screens/task_list_screen.dart';

String countText(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('completed-count'))).data!;

Future<void> pumpList(WidgetTester tester, List<Task> tasks) =>
    tester.pumpWidget(MaterialApp(home: TaskListScreen(initialTasks: tasks)));

void main() {
  testWidgets('S2 variant: empty list shows how to add a task', (tester) async {
    await tester.pumpWidget(const TodoApp());

    expect(find.text('Nessuna attività'), findsOneWidget);
    expect(countText(tester), 'Completate: 0 su 0');
  });

  testWidgets('S2: list shows title, state, importance and count', (
    tester,
  ) async {
    await pumpList(tester, [
      Task(title: 'Studiare Flutter', important: true),
      Task(title: 'Fare la spesa', done: true),
      Task(title: 'Chiamare Marco'),
    ]);

    expect(find.text('Studiare Flutter'), findsOneWidget);
    expect(find.text('Completata'), findsOneWidget);
    expect(find.text('Da fare'), findsNWidgets(2));
    expect(find.text('Importante'), findsOneWidget);
    expect(countText(tester), 'Completate: 1 su 3');
  });

  testWidgets('S1: add a task, back to list with confirmation message', (
    tester,
  ) async {
    await tester.pumpWidget(const TodoApp());

    await tester.tap(find.text('Nuova attività'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '  Pagare bolletta ');
    await tester.tap(find.byType(Switch));
    await tester.tap(find.text('Aggiungi'));
    await tester.pumpAndSettle();

    expect(find.byType(TaskListScreen), findsOneWidget);
    expect(find.text('Pagare bolletta'), findsOneWidget);
    expect(find.text('Importante'), findsOneWidget);
    expect(find.text('Da fare'), findsOneWidget);
    expect(find.text('Attività "Pagare bolletta" aggiunta'), findsOneWidget);
    expect(countText(tester), 'Completate: 0 su 1');
  });

  testWidgets('S1 variant: missing title shows an error until corrected', (
    tester,
  ) async {
    await tester.pumpWidget(const TodoApp());
    await tester.tap(find.text('Nuova attività'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), '   ');
    await tester.tap(find.text('Aggiungi'));
    await tester.pumpAndSettle();
    expect(find.text('Il titolo è obbligatorio'), findsOneWidget);
    expect(find.byType(TaskListScreen), findsNothing);

    await tester.enterText(find.byType(TextFormField), 'Leggere');
    await tester.pump();
    expect(find.text('Il titolo è obbligatorio'), findsNothing);
  });

  testWidgets('S1 variant: going back creates nothing and shows no message', (
    tester,
  ) async {
    await tester.pumpWidget(const TodoApp());
    await tester.tap(find.text('Nuova attività'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Non salvare');

    final popped = await tester.binding.handlePopRoute();
    expect(popped, isTrue);
    await tester.pumpAndSettle();

    expect(find.text('Nessuna attività'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('S3: tapping a task toggles its state and the count', (
    tester,
  ) async {
    await pumpList(tester, [Task(title: 'Correre')]);

    await tester.tap(find.text('Correre'));
    await tester.pump();
    expect(find.text('Completata'), findsOneWidget);
    expect(countText(tester), 'Completate: 1 su 1');

    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    expect(find.text('Da fare'), findsOneWidget);
    expect(countText(tester), 'Completate: 0 su 1');
  });

  testWidgets('S4: delete after confirmation updates the count', (
    tester,
  ) async {
    await pumpList(tester, [
      Task(title: 'A', done: true),
      Task(title: 'B'),
    ]);

    await tester.tap(find.byTooltip('Elimina').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Elimina'));
    await tester.pumpAndSettle();

    expect(find.text('A'), findsNothing);
    expect(countText(tester), 'Completate: 0 su 1');
  });

  testWidgets('S4 variant: cancelling keeps the task unchanged', (
    tester,
  ) async {
    await pumpList(tester, [Task(title: 'A', done: true)]);

    await tester.tap(find.byTooltip('Elimina'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Annulla'));
    await tester.pumpAndSettle();

    expect(find.text('A'), findsOneWidget);
    expect(find.text('Completata'), findsOneWidget);
    expect(countText(tester), 'Completate: 1 su 1');
  });
}
