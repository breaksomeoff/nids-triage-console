import 'package:file_picker/file_picker.dart';
import 'package:flutter/widgets.dart';
import 'package:url_launcher/url_launcher.dart';

import 'api_client.dart';
import 'models.dart';
import 'picker_options_io.dart'
    if (dart.library.js_interop) 'picker_options_web.dart';
import 'session.dart';

typedef CvPicker = Future<PickedCv?> Function();
typedef UrlOpener = Future<bool> Function(Uri uri);

/// Lets the user choose a PDF from the device.
Future<PickedCv?> pickPdf() async {
  final file = await FilePicker.pickFile(
    type: FileType.custom,
    allowedExtensions: ['pdf'],
    webOptions: pickerWebOptions,
  );
  if (file == null) return null;
  return PickedCv(name: file.name, bytes: await file.readAsBytes());
}

/// Opens [uri] in the browser (a new tab on the web).
Future<bool> openInBrowser(Uri uri) =>
    launchUrl(uri, webOnlyWindowName: '_blank');

/// App-wide dependencies, reachable from any screen with [AppScope.of].
/// Device features are injectable so widget tests can fake them.
class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.api,
    required this.session,
    required this.routeObserver,
    required this.pickCv,
    required this.openUrl,
    required super.child,
  });

  final ApiClient api;
  final Session session;
  final RouteObserver<ModalRoute<void>> routeObserver;
  final CvPicker pickCv;
  final UrlOpener openUrl;

  static AppScope of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!;

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      api != oldWidget.api ||
      session != oldWidget.session ||
      pickCv != oldWidget.pickCv ||
      openUrl != oldWidget.openUrl;
}

/// Calls [reload] whenever the screen becomes visible again after the screen
/// on top of it is popped, so lists are fresh after creating or applying.
mixin ReloadOnReturn<T extends StatefulWidget> on State<T>
    implements RouteAware {
  RouteObserver<ModalRoute<void>>? _observer;

  void reload();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    _observer = AppScope.of(context).routeObserver;
    if (route != null) _observer!.subscribe(this, route);
  }

  @override
  void dispose() {
    _observer?.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() => reload();

  @override
  void didPush() {}

  @override
  void didPop() {}

  @override
  void didPushNext() {}
}
