// Lines screen. Port of app/lib/ui/features/lines/lines_screen.dart.
// Full line list with search and All/Live/Favorites filters.
import React, { useEffect, useMemo, useState } from "react";
import { FlatList, Text, View, StyleSheet } from "react-native";
import { useRouter } from "expo-router";
import { useTheme } from "../../design/theme/context";
import { Chip } from "../../design/components/chip";
import { EmptyState } from "../../design/components/empty_state";
import { LineRow } from "../../design/components/line_row";
import { SearchField } from "../../design/components/search_field";
import { Toast } from "../../design/components/toast";
import { lineVmOf } from "../../adapters/lines_adapter";
import { useStaticStore } from "../../../stores";
import { staticData } from "../../../data/static/staticData";
import { busApi } from "../../../data/api/busApi";
import * as storage from "../../../data/prefs/storage";
import { recentsKey } from "../../adapters/local_stores";
import { uiStrings, favoriteLine, unfavoriteLine } from "../../strings/uiStrings";
import { filterLines, type LinesFilter } from "./lines_logic";
import { useFavorites } from "./favorites_bridge";

export function LinesScreen() {
  const t = useTheme();
  const router = useRouter();
  const storeLines = useStaticStore((s) => s.lines);
  const setStoreLines = useStaticStore((s) => s.setLines);
  const [query, setQuery] = useState("");
  const [filter, setFilter] = useState<LinesFilter>("all");
  const [liveCounts, setLiveCounts] = useState<Record<number, number>>({});
  const [toast, setToast] = useState<string | null>(null);
  const { favorites, toggle, isFavorite } = useFavorites();

  useEffect(() => {
    if (toast == null) return;
    const id = setTimeout(() => setToast(null), 2500);
    return () => clearTimeout(id);
  }, [toast]);

  useEffect(() => {
    (async () => {
      const ls = await staticData.currentLines();
      if (ls.length > 0) setStoreLines(ls);
    })();
    busApi.getLive().then((r) => {
      if (r.ok) {
        const counts: Record<number, number> = {};
        for (const [id, n] of r.value) counts[id] = n;
        setLiveCounts(counts);
      }
    });
  }, [setStoreLines]);

  const vms = useMemo(
    () => storeLines.filter((l) => l.is_active).map((l) => lineVmOf(l, liveCounts[l.id] ?? 0)),
    [storeLines, liveCounts],
  );
  const shown = useMemo(
    () => filterLines({ lines: vms, query, filter, favorites }),
    [vms, query, filter, favorites],
  );

  const openLine = (key: string) => {
    storage.getItem(recentsKey).then((raw) => {
      try {
        const arr = raw ? (JSON.parse(raw) as string[]) : [];
        const next = [key, ...arr.filter((k) => k !== key)].slice(0, 6);
        void storage.setItem(recentsKey, JSON.stringify(next));
      } catch {}
    });
    router.push(`/line/${key}`);
  };

  return (
    <View style={[styles.root, { backgroundColor: t.colors.bg }]}>
      <View style={styles.head}>
        <Text style={t.text.title} accessibilityRole="header">
          {uiStrings.linesTitle}
        </Text>
        <Text style={[t.text.caption, { color: t.colors.inkMuted }]}>
          {`${shown.length} ${uiStrings.linesCount}`}
        </Text>
        <View style={{ marginTop: 8 }}>
          <SearchField hint={uiStrings.searchHint} value={query} onChange={setQuery} />
        </View>
        <View style={styles.filters} accessibilityRole="radiogroup">
          <Chip label={uiStrings.filterAll} selected={filter === "all"} onPress={() => setFilter("all")} />
          <Chip label={uiStrings.filterLive} selected={filter === "live"} onPress={() => setFilter("live")} />
          <Chip
            label={uiStrings.filterFavorites}
            selected={filter === "favorites"}
            onPress={() => setFilter("favorites")}
          />
        </View>
      </View>
      {shown.length === 0 ? (
        <EmptyState
          art="search"
          title={uiStrings.searchEmptyTitle}
          message={filter === "favorites" ? uiStrings.linesNoFavorites : uiStrings.searchEmptyTip}
        />
      ) : (
        <FlatList
          data={shown}
          keyExtractor={(l) => l.key}
          renderItem={({ item }) => {
            const fav = isFavorite(item.key);
            return (
              <LineRow
                line={item}
                status={
                  item.isLive
                    ? `${item.liveVehicleCount ?? 0} ${uiStrings.liveCount}`
                    : (item.terminals?.join(" · ") ?? uiStrings.linesNoTimetable)
                }
                isFavorite={fav}
                onPress={() => openLine(item.key)}
                onToggleFavorite={() => setToast(toggle(item.key))}
                semanticLabel={`${item.name}. ${fav ? unfavoriteLine(item.short ?? "") : favoriteLine(item.short ?? "")}`}
              />
            );
          }}
        />
      )}
      {toast != null ? <Toast message={toast} /> : null}
    </View>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1 },
  head: { padding: 16, paddingBottom: 8 },
  filters: { flexDirection: "row", gap: 8, marginTop: 12 },
});
