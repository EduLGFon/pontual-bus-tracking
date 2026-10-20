// First-use disclosure before a report reads the device location. The OS
// permission prompt follows only after acceptance. The notice is stored
// locally, not as a server consent record (D83; legal review pending).
import 'package:flutter/material.dart';
import 'package:pontual/ui/design/components/buttons.dart';
import 'package:pontual/ui/design/components/pontual_sheet.dart';
import 'package:pontual/ui/design/theme/context.dart';
import 'package:pontual/ui/design/tokens/spacing.dart';
import 'package:pontual/ui/strings/ui_strings.dart';

/// Shows the one-time report-location notice. Returns true on acceptance.
Future<bool> showReportLocationNotice(BuildContext context) async {
  final bool? accepted = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    elevation: 0,
    builder: (BuildContext context) => const ReportLocationNoticeBody(),
  );
  return accepted == true;
}

/// Modal body of the report-location notice.
class ReportLocationNoticeBody extends StatelessWidget {
  /// Creates the notice body.
  const ReportLocationNoticeBody({super.key});

  @override
  Widget build(BuildContext context) {
    return PontualSheet(
      title: UiStrings.reportLocationTitle,
      scrollable: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(UiStrings.reportLocationBody, style: context.text.body),
          const SizedBox(height: Space.x4),
          const _Bullet(UiStrings.reportLocationBulletOnce),
          const _Bullet(UiStrings.reportLocationBulletArea),
          const _Bullet(UiStrings.reportLocationBulletDeny),
          const SizedBox(height: Space.x4),
          PrimaryButton(
            label: UiStrings.reportLocationAccept,
            onPressed: () => Navigator.of(context).pop(true),
          ),
          const SizedBox(height: Space.x2),
          SecondaryButton(
            label: UiStrings.reportLocationDeny,
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.x2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.check_rounded, size: 18, color: context.colors.liveText),
          const SizedBox(width: Space.x2),
          Expanded(child: Text(text, style: context.text.body)),
        ],
      ),
    );
  }
}
