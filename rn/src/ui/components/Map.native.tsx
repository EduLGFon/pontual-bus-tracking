import { Map as MapLibreMap, Camera, Marker, GeoJSONSource, Layer } from "@maplibre/maplibre-react-native";
import { StyleSheet } from "react-native";
import type { MapProps } from "./MapProps";

export function Map(props: MapProps) {
  const route = props.route ?? [];
  const coords = route.map((p) => [p.lng, p.lat]);
  return (
    <MapLibreMap style={styles.map} mapStyle={props.styleUrl}>
      <Camera
        initialViewState={{
          center: [props.initialCenter.lng, props.initialCenter.lat],
          zoom: props.initialZoom,
        }}
      />
      {coords.length >= 2 ? (
        <GeoJSONSource
          id="learned-route"
          data={{ type: "Feature", properties: {}, geometry: { type: "LineString", coordinates: coords } }}
        >
          <Layer
            id="learned-route-line"
            type="line"
            style={{ lineColor: "#0B6E4F", lineWidth: 3, lineOpacity: 0.85 }}
          />
        </GeoJSONSource>
      ) : null}
      {props.markers.map((m) => (
        <Marker key={m.id} lngLat={[m.lng, m.lat]}>
          <></>
        </Marker>
      ))}
    </MapLibreMap>
  );
}

const styles = StyleSheet.create({ map: { flex: 1 } });
