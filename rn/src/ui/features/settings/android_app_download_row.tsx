// Android app download row (web only). Port of
// app/lib/ui/features/settings/android_app_download_row.dart.
// On native builds there is nothing to install, so this renders nothing.
import React from "react";
import { Platform } from "react-native";
import { SettingsRow } from "./settings_row";

export function AndroidAppDownloadRow() {
  if (Platform.OS !== "web") return null;
  return <SettingsRow title="Baixar app Android" subtitle="Instale para compartilhar a posição" />;
}
