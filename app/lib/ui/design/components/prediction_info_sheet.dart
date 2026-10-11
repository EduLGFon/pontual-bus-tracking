// PredictionInfoSheet: "Como calculamos" with the one-paragraph
// explanation from the copy deck. Flagged off with predictions.
// See docs/ui/UI_SPEC.md 13.1 and 14.
import 'package:flutter/material.dart';
import 'package:pontual/ui/design/components/pontual_sheet.dart';
import 'package:pontual/ui/design/theme/context.dart';
import 'package:pontual/ui/strings/ui_strings.dart';

/// Sheet explaining a prediction. Never shown for live values.
class PredictionInfoSheet extends StatelessWidget {
  /// Creates the sheet.
  const PredictionInfoSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return PontualSheet(
      title: UiStrings.predictionInfoTitle,
      child: Text(UiStrings.predictionInfoBody, style: context.text.body),
    );
  }
}
