// Line screen. Port of app/lib/ui/features/line/line_screen.dart.
// Compact: full-bleed map with bottom sheet. Wide: side panel replaces
// the sheet. Leaving the screen closes the viewer stream (polling stops).
// The camera never moves when the sheet tab changes.
import React, { useEffect, useMemo, useState } from "react";
import { AppState, ScrollView, StyleSheet, View, useWindowDimensions } from "react-native";
import { lineVmOf } from "../../adapters/lines_adapter";
import { vehicleVmOf } from "../../adapters/vehicles_adapter";
import { useStaticStore } from "../../../stores";
import { staticData } from "../../../data/static/staticData";
import { busApi, type BusApi } from "../../../data/api/busApi";
import type { VehiclesSnapshot } from "../../../data/api/dto";
import * as storage from "../../../data/prefs/storage";
import { recentsKey } from "../../adapters/local_stores";
import type { VehicleVM } from "../../models/vehicle_vm";
import type { ArrivalVM } from "../../models/arrival_vm";
import { uiStrings } from "../../strings/uiStrings";
import { useFavorites } from "../lines/favorites_bridge";
import { useReports } from "../reports/reports_providers";
import { learningRepo } from "../../../data/learning/learningRepository";
import { decodePolyline } from "../../../core/geo/geo";
import { LineDock } from "./line_dock";
import { LineExpanded } from "./line_expanded";
import { LineMap } from "./line_map";
import { LineMapControls, type MapStatus } from "./line_map_controls";
import { LineNotFound } from "./line_not_found";
import { LineSheet, type LineTab } from "./line_sheet";
import { useViewerLocation } from "./viewer_location";

const tileFallback = "https://tile.openstreetmap.org/{z}/{x}/{y}.png";
const pollMs = 5000;
const wideMin = 600;

function rowToVehicle(row: (number | null)[], lineKey: string, ordinal: number): VehicleVM | null {
  if (row[0] == null || row[1] == null || row[2] == null) return null;
  return vehicleVmOf(
    {
      id: row[0],
      lat: row[1],
      lng: row[2],
      heading: row[3] ?? null,
      kmh: row[4] ?? null,
      members: row[5] ?? 1,
      ageS: row[6] ?? 999,
      paceKmh: row.length > 7 ? (row[7] ?? null) : null,
    },
    lineKey,
    ordinal,
  );
}

export function LineScreen({ lineKey, tab, api }: { lineKey: string; tab?: string; api?: BusApi }) {
  const storeLines = useStaticStore((s) => s.lines);
  const setStoreLines = useStaticStore((s) => s.setLines);
  const [snapshot, setSnapshot] = useState<VehiclesSnapshot | null>(null);
  const [fetchFailed, setFetchFailed] = useState(false);
  const [arrivals, setArrivals] = useState<ArrivalVM[]>([]);
  const [routePoints, setRoutePoints] = useState<{ lat: number; lng: number }[]>([]);
  const [activeTab, setActiveTab] = useState<LineTab>(tab === "horarios" ? "horarios" : "agora");
  const [following, setFollowing] = useState(false);
  const { width } = useWindowDimensions();
  const { favorites, toggle } = useFavorites();
  const viewer = useViewerLocation();
  const client: BusApi = useMemo(() => api ?? busApi, [api]);

  const line = useMemo(
    () => storeLines.find((l) => l.code === lineKey || String(l.id) === lineKey) ?? null,
    [storeLines, lineKey],
  );
  const lineVM = useMemo(() => (line ? lineVmOf(line, 0) : null), [line]);
  const reports = useReports(snapshot, line?.id ?? 0);

  useEffect(() => {
    if (storeLines.length === 0) {
      staticData.currentLines().then((ls) => {
        if (ls.length > 0) setStoreLines(ls);
      });
    }
  }, [storeLines.length, setStoreLines]);

  useEffect(() => {
    if (!line || !line.pilot) return;
    const lineId = line.id;
    let mounted = true;
    const apply = (r: Awaited<ReturnType<BusApi["getVehicles"]>>) => {
      if (!mounted) return;
      if (r.ok) {
        setSnapshot(r.value);
        setFetchFailed(false);
      } else {
        setFetchFailed(true);
      }
    };
    const applyArrivals = (r: Awaited<ReturnType<BusApi["getArrivals"]>>) => {
      if (!mounted || !r.ok) return;
      const at = new Date();
      setArrivals(
        (r.value.passages ?? []).slice(0, 4).map((s) => ({
          lineKey: line.code,
          at: new Date(at.getTime() + Math.max(0, s) * 1000),
          certainty: "predicted" as const,
          asOf: at,
        })),
      );
    };
    const load = () => {
      void client.getVehicles(lineId).then(apply);
      void client.getArrivals(lineId).then(applyArrivals);
    };
    load();
    // Learned route overlay, fetched once per line. Silent when absent:
    // viewers still get vehicles, reports, and arrivals.
    void (async () => {
      try {
        const lr = await learningRepo.fetchLearnedRoute(lineId);
        const poly = lr?.polyline;
        if (mounted && typeof poly === "string" && poly.length > 0) {
          setRoutePoints(decodePolyline(poly).map((p) => ({ lat: p.lat, lng: p.lng })));
        }
      } catch {}
    })();
    const id = setInterval(() => {
      if (mounted && AppState.currentState === "active") load();
    }, pollMs);
    const sub = AppState.addEventListener("change", (st) => {
      if (st === "active" && mounted) void client.getVehicles(lineId).then(apply);
    });
    return () => {
      mounted = false;
      clearInterval(id);
      sub.remove();
    };
  }, [line, client]);

  useEffect(() => {
    if (line) {
      storage.getItem(recentsKey).then((raw) => {
        try {
          const arr = raw ? (JSON.parse(raw) as string[]) : [];
          const next = [line.code, ...arr.filter((k) => k !== line.code)].slice(0, 6);
          void storage.setItem(recentsKey, JSON.stringify(next));
        } catch {}
      });
    }
  }, [line]);

  const vehicles: VehicleVM[] = useMemo(() => {
    if (!snapshot || !line) return [];
    return snapshot.v.flatMap((row, i) => {
      const v = rowToVehicle(row, line.code, i + 1);
      return v ? [v] : [];
    });
  }, [snapshot, line]);
  const liveCount = vehicles.length;
  const status: MapStatus =
    !line || !line.pilot
      ? "empty"
      : snapshot == null
        ? fetchFailed
          ? "offline"
          : "connecting"
        : fetchFailed
          ? "stale"
          : liveCount > 0
            ? "live"
            : "empty";
  const center = useMemo(() => {
    if (following && vehicles.length > 0) return { lat: vehicles[0].lat, lng: vehicles[0].lng };
    if (viewer.fix) return { lat: viewer.fix.lat, lng: viewer.fix.lng };
    if (vehicles.length > 0) return { lat: vehicles[0].lat, lng: vehicles[0].lng };
    return { lat: -18.715, lng: -39.856 };
  }, [following, vehicles, viewer.fix]);

  if (!line || !lineVM) return <LineNotFound />;

  const sheet = (
    <LineSheet
      line={line}
      lineVM={lineVM}
      liveCount={liveCount}
      vehicles={vehicles}
      arrivals={arrivals}
      reports={reports}
      tab={activeTab}
      onTab={setActiveTab}
      onToggleFavorite={() => toggle(line.code)}
      isFavorite={favorites.includes(line.code)}
    />
  );
  const wide = width >= wideMin;

  return (
    <View style={styles.root}>
      <View style={wide ? styles.wideMap : styles.map}>
        <LineMap tileUrl={tileFallback} vehicles={vehicles} center={center} routePoints={routePoints} />
        <View style={styles.controls}>
          <LineMapControls
            status={line.pilot ? status : "empty"}
            count={liveCount}
            following={following}
            onToggleFollow={() => setFollowing((f) => !f)}
            onLocate={() => void viewer.locate()}
            locating={viewer.loading}
          />
        </View>
      </View>
      {wide ? (
        <View style={styles.panel}>
          <LineExpanded
            line={line}
            lineVM={lineVM}
            liveCount={liveCount}
            vehicles={vehicles}
            arrivals={arrivals}
            reports={reports}
            tab={activeTab}
            onTab={setActiveTab}
            onToggleFavorite={() => toggle(line.code)}
            isFavorite={favorites.includes(line.code)}
          />
        </View>
      ) : (
        <ScrollView style={styles.sheetWrap}>{sheet}</ScrollView>
      )}
      <View style={styles.dock} accessibilityLabel={uiStrings.tripSheetLabel}>
        <LineDock lineKey={line.code} shareable={line.pilot} />
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1 },
  map: { height: 300 },
  wideMap: { flex: 1 },
  panel: { width: 380, borderLeftWidth: 1 },
  sheetWrap: { flex: 1 },
  controls: { position: "absolute", top: 12, left: 12, right: 12 },
  dock: { position: "absolute", bottom: 24, left: 16, right: 16, alignItems: "center" },
});
