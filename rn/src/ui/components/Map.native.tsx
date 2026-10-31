import { Map as MapLibreMap, Camera, Marker } from "@maplibre/maplibre-react-native";
import { StyleSheet, View } from "react-native";
import type { MapProps } from "./MapProps";

export function Map(props: MapProps) {
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
