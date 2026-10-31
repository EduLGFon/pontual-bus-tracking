// Line map. Port of app/lib/ui/features/line/line_map.dart.
// Full-bleed map with vehicle markers; decorative stop dots stay decorative.
// Leaving the screen closes the viewer stream (the screen owns the polling).
import React from "react";
import { StyleSheet, View } from "react-native";
import { Map } from "../../components/Map";
import type { VehicleVM } from "../../models/vehicle_vm";

export function LineMap({
  tileUrl,
  vehicles,
  center,
  onSelect,
}: {
  tileUrl: string;
  vehicles: VehicleVM[];
  center: { lat: number; lng: number };
  onSelect?: (key: number) => void;
}) {
  void onSelect;
  return (
    <View style={styles.root}>
      <Map
        styleUrl={tileUrl}
        initialCenter={center}
        initialZoom={13}
        markers={vehicles.map((v) => ({ id: String(v.key), lat: v.lat, lng: v.lng }))}
      />
    </View>
  );
}

const styles = StyleSheet.create({ root: { flex: 1, minHeight: 240 } });
