// Local acceptance flag for the report-location notice. This is a
// transparency notice plus the OS permission, not a server consent record.
// Legal review before public release must confirm whether a versioned
// consent record is required. See DECISIONS.md#D83.
import 'package:shared_preferences/shared_preferences.dart';

/// Storage key of the report-location notice version.
const String reportLocationNoticeKey = 'report_location_notice_v1';

/// Reads and writes the local notice acceptance.
class ReportLocationNoticeStore {
  /// Creates the store.
  const ReportLocationNoticeStore();

  /// True when this install already accepted the notice.
  Future<bool> accepted() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(reportLocationNoticeKey) ?? false;
  }

  /// Records acceptance on this device.
  Future<void> accept() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(reportLocationNoticeKey, true);
  }
}
