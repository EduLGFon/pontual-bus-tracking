export interface MapMarker {
  id: string;
  lat: number;
  lng: number;
}
export interface MapProps {
  styleUrl: string;
  initialCenter: { lat: number; lng: number };
  initialZoom: number;
  markers: MapMarker[];
}
