// Unknown line key state of the line screen: the honest empty state with a
// way back, shown for any key that is not in the static data.
// See docs/ui/UI_SPEC.md 7.5.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pontual/ui/design/components/empty_state.dart';
import 'package:pontual/ui/design/components/icon_btn.dart';
import 'package:pontual/ui/design/theme/context.dart';
import 'package:pontual/ui/design/tokens/spacing.dart';
import 'package:pontual/ui/strings/ui_strings.dart';

/// Renders the empty state of an unknown line key.
class LineNotFound extends StatelessWidget {
  /// Creates the state.
  const LineNotFound({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Space.x6),
          child: Column(
            children: <Widget>[
              Align(
                alignment: Alignment.centerLeft,
                child: IconBtn(
                  icon: Icons.arrow_back_rounded,
                  semanticLabel: UiStrings.back,
                  onTap: () => Navigator.of(context).maybePop(),
                ),
              ),
              Expanded(
                child: EmptyState(
                  title: UiStrings.lineNotFound,
                  message: UiStrings.notFoundTitle,
                  art: EmptyArt.pin,
                  actionLabel: UiStrings.navLines,
                  onAction: () => GoRouter.of(context).go('/lines'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
