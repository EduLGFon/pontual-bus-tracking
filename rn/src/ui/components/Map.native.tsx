import { Map as MapLibreMap, Camera, Marker } from "@maplibre/maplibre-react-native";
import { StyleSheet } from "react-native";
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
          <></>
        </Marker>
      ))}
    </MapLibreMap>
  );
}

const styles = StyleSheet.create({ map: { flex: 1 } });
