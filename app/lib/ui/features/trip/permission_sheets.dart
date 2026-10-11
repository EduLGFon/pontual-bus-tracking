// Sheets of the trip flow: the consent disclosure and the permission
// pre-prompt. The disclosure never records anything itself: acceptance is
// handed to the existing ConsentSheet call, which owns the stored choice.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pontual/ui/design/components/buttons.dart';
import 'package:pontual/ui/design/components/ghost_link.dart';
import 'package:pontual/ui/design/components/pontual_sheet.dart';
import 'package:pontual/ui/design/theme/context.dart';
import 'package:pontual/ui/design/tokens/spacing.dart';
import 'package:pontual/ui/strings/ui_strings.dart';
import 'package:pontual/ui/util/platform.dart';

/// Consent disclosure body. Acceptance goes through the existing consent
/// call, which records the choice; this UI only presents it.
class ConsentBody extends StatelessWidget {
  /// Creates the consent sheet body.
  const ConsentBody({super.key});

  @override
  Widget build(BuildContext context) {
    final bool web = PlatformInfo.isWeb;
    return PontualSheet(
      title: UiStrings.consentTitle,
      scrollable: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            web ? UiStrings.consentBodyWeb : UiStrings.consentBody,
            style: context.text.body,
          ),
          const SizedBox(height: Space.x4),
          const _ConsentBullet(UiStrings.consentBulletPurpose),
          const _ConsentBullet(UiStrings.consentBulletNoIdentity),
          const _ConsentBullet(UiStrings.consentBulletDeleted),
          const _ConsentBullet(UiStrings.consentBulletOthers),
          const _ConsentBullet(UiStrings.consentBulletControl),
          const SizedBox(height: Space.x4),
          GhostLink(
            label: UiStrings.privacyPolicy,
            onTap: () => context.push('/privacy/policy'),
          ),
          const SizedBox(height: Space.x2),
          PrimaryButton(
            label: UiStrings.consentAccept,
            onPressed: () => _accept(context),
          ),
          const SizedBox(height: Space.x2),
          SecondaryButton(
            label: UiStrings.consentDecline,
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    );
  }

  /// Records nothing here: accepting only closes the disclosure. The
  /// existing share flow records the choice through its own consent call
  /// when the trip starts, so the decision is stored exactly once and in
  /// exactly one place. A decline closes this sheet with no trip.
  void _accept(BuildContext context) {
    Navigator.of(context).pop(true);
  }
}

/// One bullet of the disclosure, icon plus text, never colour alone.
class _ConsentBullet extends StatelessWidget {
  /// Creates a bullet with [text].
  const _ConsentBullet(this.text);

  /// Bullet copy in pt-BR.
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

/// Permission pre-prompt body, shown before the OS dialog. Returns true
/// when the rider continues and false when they cancel or dismiss.
class PermissionPromptBody extends StatelessWidget {
  /// Creates the pre-prompt sheet body.
  const PermissionPromptBody({super.key});

  @override
  Widget build(BuildContext context) {
    return PontualSheet(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(UiStrings.permissionPrompt, style: context.text.body),
          const SizedBox(height: Space.x6),
          PrimaryButton(
            label: UiStrings.permissionContinue,
            onPressed: () => Navigator.of(context).pop(true),
          ),
          const SizedBox(height: Space.x2),
          SecondaryButton(
            label: UiStrings.cancel,
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    );
  }
}
