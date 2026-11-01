// PredictionInfoSheet. Port of app/lib/ui/design/components/prediction_info_sheet.dart.
import React from "react";
import { Text } from "react-native";
import { useTheme } from "../theme/context";
import { uiStrings } from "../../strings/uiStrings";
import { PontualSheet } from "./pontual_sheet";

export function PredictionInfoSheet() {
  const t = useTheme();
  return (
    <PontualSheet title={uiStrings.predictionInfoTitle}>
      <Text style={t.text.body}>{uiStrings.predictionInfoBody}</Text>
    </PontualSheet>
  );
}
