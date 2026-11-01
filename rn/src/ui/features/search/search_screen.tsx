// Search screen. Port of app/lib/ui/features/search/search_screen.dart.
// Groups: lines (code/name), places ("Linhas que passam por"), recents and
// suggestions when the query is empty. No network.
import React, { useEffect, useMemo, useState } from "react";
import { FlatList, View, StyleSheet } from "react-native";
import { useRouter } from "expo-router";
import { useTheme } from "../../design/theme/context";
import { LineRow } from "../../design/components/line_row";
import { SearchField } from "../../design/components/search_field";
import { SectionHeader } from "../../design/components/section_header";
import { EmptyState } from "../../design/components/empty_state";
import { lineVmOf } from "../../adapters/lines_adapter";
import { useStaticStore } from "../../../stores";
import { staticData } from "../../../data/static/staticData";
import { busApi } from "../../../data/api/busApi";
import * as storage from "../../../data/prefs/storage";
import { recentsKey } from "../../adapters/local_stores";
import { buildLineIndex, searchLines } from "../../util/search_index";
import { uiStrings } from "../../strings/uiStrings";
import { searchPlaces } from "./place_search";

export function SearchScreen() {
  const t = useTheme();
  const router = useRouter();
  const storeLines = useStaticStore((s) => s.lines);
  const setStoreLines = useStaticStore((s) => s.setLines);
  const [query, setQuery] = useState("");
  const [liveCounts, setLiveCounts] = useState<Record<number, number>>({});
  const [recents, setRecents] = useState<string[]>([]);

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
    storage
      .getItem(recentsKey)
      .then((raw) => {
        if (raw) {
          const arr = JSON.parse(raw) as unknown;
          if (Array.isArray(arr)) setRecents(arr.filter((x): x is string => typeof x === "string"));
        }
      })
      .catch(() => {});
  }, [setStoreLines]);

  const vms = useMemo(
    () => storeLines.filter((l) => l.is_active).map((l) => lineVmOf(l, liveCounts[l.id] ?? 0)),
    [storeLines, liveCounts],
  );
  const index = useMemo(() => buildLineIndex(vms), [vms]);
  const lineHits = useMemo(
    () => (query.trim() === "" ? [] : searchLines(index, query).map((m) => m.line)),
    [index, query],
  );
  const placeHits = useMemo(() => searchPlaces(vms, query), [vms, query]);
  const recentVMs = useMemo(
    () => recents.flatMap((k) => vms.filter((l) => l.key === k).slice(0, 1)),
    [recents, vms],
  );
  const suggestions = useMemo(() => vms.filter((l) => l.isLive).slice(0, 5), [vms]);

  const openLine = (key: string) => router.push(`/line/${key}`);
  const empty = query.trim() !== "" && lineHits.length === 0 && placeHits.length === 0;

  return (
    <View style={[styles.root, { backgroundColor: t.colors.bg }]}>
      <View style={styles.head}>
        <SearchField hint={uiStrings.searchHint} value={query} onChange={setQuery} autoFocus />
      </View>
      {empty ? (
        <EmptyState art="search" title={uiStrings.searchEmptyTitle} message={uiStrings.searchEmptyTip} />
      ) : (
        <FlatList
          data={[{ kind: "root" }]}
          keyExtractor={() => "root"}
          renderItem={() => (
            <View>
              {query.trim() === "" ? (
                <>
                  {recentVMs.length > 0 ? (
                    <>
                      <SectionHeader title={uiStrings.searchRecents} />
                      {recentVMs.map((l) => (
                        <LineRow key={l.key} line={l} status={l.terminals?.join(" · ") ?? ""} onPress={() => openLine(l.key)} />
                      ))}
                    </>
                  ) : null}
                  {suggestions.length > 0 ? (
                    <>
                      <SectionHeader title={uiStrings.searchSuggestions} />
                      {suggestions.map((l) => (
                        <LineRow
                          key={l.key}
                          line={l}
                          status={`${l.liveVehicleCount ?? 0} ${uiStrings.liveCount}`}
                          onPress={() => openLine(l.key)}
                        />
                      ))}
                    </>
                  ) : null}
                </>
              ) : (
                <>
                  {lineHits.length > 0 ? (
                    <>
                      <SectionHeader title={uiStrings.searchLines} />
                      {lineHits.map((l) => (
                        <LineRow
                          key={l.key}
                          line={l}
                          status={
                            l.isLive
                              ? `${l.liveVehicleCount ?? 0} ${uiStrings.liveCount}`
                              : (l.terminals?.join(" · ") ?? "")
                          }
                          onPress={() => openLine(l.key)}
                        />
                      ))}
                    </>
                  ) : null}
                  {placeHits.length > 0 ? (
                    <>
                      <SectionHeader title={uiStrings.searchPlaces} />
                      {placeHits.map((h) => (
                        <LineRow
                          key={h.key}
                          line={h.line}
                          status={h.placeName}
                          onPress={() => openLine(h.line.key)}
                        />
                      ))}
                    </>
                  ) : null}
                </>
              )}
            </View>
          )}
        />
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1 },
  head: { padding: 16, paddingBottom: 8 },
});
