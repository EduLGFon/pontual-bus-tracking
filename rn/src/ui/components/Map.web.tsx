// Web map using maplibre-gl via react-map-gl.
// @ts-ignore
import "maplibre-gl/dist/maplibre-gl.css";
import MapGL, { Marker } from "react-map-gl/maplibre";
import type { MapProps } from "./MapProps";

export function Map(props: MapProps) {
  return (
    <MapGL
      initialViewState={{
        latitude: props.initialCenter.lat,
        longitude: props.initialCenter.lng,
        zoom: props.initialZoom,
      }}
      style={{ width: "100%", height: "100%" }}
      mapStyle={props.styleUrl}
    >
      {props.markers.map((m) => (
        <Marker key={m.id} longitude={m.lng} latitude={m.lat} />
      ))}
    </MapGL>
  );
}
