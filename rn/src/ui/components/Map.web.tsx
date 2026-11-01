// Web map using maplibre-gl via react-map-gl.
// @ts-ignore
import "maplibre-gl/dist/maplibre-gl.css";
import MapGL, { Marker, Source, Layer } from "react-map-gl/maplibre";
import type { MapProps } from "./MapProps";

export function Map(props: MapProps) {
  const route = props.route ?? [];
  const coords = route.map((p) => [p.lng, p.lat]);
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
      {coords.length >= 2 ? (
        <Source
          id="learned-route"
          type="geojson"
          data={{ type: "Feature", properties: {}, geometry: { type: "LineString", coordinates: coords } }}
        >
          <Layer
            id="learned-route-line"
            type="line"
            paint={{ "line-color": "#0B6E4F", "line-width": 3, "line-opacity": 0.85 }}
          />
        </Source>
      ) : null}
      {props.markers.map((m) => (
        <Marker key={m.id} longitude={m.lng} latitude={m.lat} />
      ))}
    </MapGL>
  );
}
