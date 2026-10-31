import { StyleSheet, View, Text } from "react-native";
import type { MapProps } from "./MapProps";

// MapLibre native is loaded lazily so a missing native module (e.g. running in
// Expo Go or an incompatible dev build) degrades to a placeholder instead of
// crashing the whole route.
let MapLibre: any = null;
let loadError: string | null = null;
try {
  // eslint-disable-next-line @typescript-eslint/no-var-requires
  MapLibre = require("@maplibre/maplibre-react-native");
} catch (e: any) {
  loadError = String(e?.message ?? e);
}

export function Map(props: MapProps) {
  if (!MapLibre) {
    return (
      <View style={[styles.map, { alignItems: "center", justifyContent: "center" }]}>
        <Text style={{ color: "#666", textAlign: "center", padding: 12 }}>
          Mapa indisponível neste build.{"\n"}
          {loadError ? loadError.slice(0, 120) : ""}
        </Text>
      </View>
    );
  }
  const { Map: MapLibreMap, Camera, Marker } = MapLibre;
  return (
    <MapLibreMap style={styles.map} mapStyle={props.styleUrl}>
      <Camera
        initialViewState={{
          center: [props.initialCenter.lng, props.initialCenter.lat],
          zoom: props.initialZoom,
        }}
      />
      {props.markers.map((m) => (
        <Marker key={m.id} lngLat={[m.lng, m.lat]}>
          <View style={{ width: 12, height: 12, borderRadius: 6, backgroundColor: "#208AEF" }} />
        </Marker>
      ))}
    </MapLibreMap>
  );
}

const styles = StyleSheet.create({ map: { flex: 1 } });