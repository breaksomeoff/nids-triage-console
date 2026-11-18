import 'package:file_picker_web/file_picker_web.dart';

/// iOS Safari gives the window focus back before the chosen file is ready
/// (e.g. while it is copied from iCloud). With the default options the
/// plugin takes that as a cancel and drops the file, so only the input's
/// own `change`/`cancel` events are used.
const pickerWebOptions = FilePickerWebOptions(cancelUploadOnWindowBlur: false);
