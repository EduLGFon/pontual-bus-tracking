// Home sections. Port of app/lib/ui/features/home/home_sections.dart
// and home_lists.dart. Presentational: the screen computes data and passes
// it down, so these stay free of data fetching.
import React from "react";
import { View, Text, FlatList, StyleSheet } from "react-native";
import { useRouter } from "expo-router";
import { useTheme } from "../../design/theme/context";
import { LineRow } from "../../design/components/line_row";
import { LiveDot } from "../../design/components/live_dot";
import { Pressable } from "../../design/components/pressable";
import { SearchField } from "../../design/components/search_field";
import { SectionHeader } from "../../design/components/section_header";
import { ShortcutCard } from "../../design/components/shortcut_card";
import { SurfaceCard } from "../../design/components/surface_card";
import { GhostLink } from "../../design/components/ghost_link";
import type { LineVM } from "../../models/line_vm";
import { uiStrings, homeTomorrowAt } from "../../strings/uiStrings";

export function SearchEntry({ onPress }: { onPress?: () => void }) {
  const router = useRouter();
  const go = () => {
    if (onPress) onPress();
    else router.push("/search");
  };
  return (
    <Pressable onPress={go} accessibilityLabel={uiStrings.searchHint} borderRadius={12}>
      <View pointerEvents="none">
        <SearchField hint={uiStrings.searchHint} value="" onChange={() => {}} />
      </View>
    </Pressable>
  );
}

export function LiveSummaryChip({ total, known, offline }: { total: number; known: boolean; offline: boolean }) {
  const t = useTheme();
  if (!known) return <View style={styles.chipSlot} />;
  const text = offline ? uiStrings.homeOffline : total <= 0 ? uiStrings.homeLiveNone : `${total} ${uiStrings.liveCount}`;
  return (
    <View style={styles.chipSlot}>
      <View
        accessibilityLabel={text}
        style={[styles.chip, { backgroundColor: t.colors.surfaceSunken, borderColor: t.colors.line }]}>
        <LiveDot certainty={offline || total <= 0 ? "stale" : "live"} />
        <Text style={[t.text.label, { color: t.colors.ink }]}>{text}</Text>
      </View>
    </View>
  );
}

export interface ShortcutDatum {
  key: string;
  line: LineVM;
  statusText: string;
  isLive: boolean;
  direction: string | null;
  tomorrowAt: string | null;
}

export function ShortcutsSection({
  cards,
  onOpen,
  onAdd,
}: {
  cards: ShortcutDatum[];
  onOpen: (key: string) => void;
  onAdd: () => void;
}) {
  if (cards.length === 0) return null;
  return (
    <View>
      <SectionHeader title={uiStrings.homeShortcuts} />
      <FlatList
        horizontal
        data={cards}
        keyExtractor={(c) => c.key}
        showsHorizontalScrollIndicator={false}
        contentContainerStyle={styles.strip}
        renderItem={({ item }) => (
          <View style={styles.cardWrap}>
            <ShortcutCard
              label={item.line.name}
              line={item.line}
              statusText={item.tomorrowAt != null ? `${item.statusText} · ${homeTomorrowAt(item.tomorrowAt)}` : item.statusText}
              isLive={item.isLive}
              direction={item.direction ?? undefined}
              onPress={() => onOpen(item.key)}
            />
          </View>
        )}
      />
      {cards.length < 4 ? (
        <GhostLink label={uiStrings.addShortcut} onPress={onAdd} />
      ) : null}
    </View>
  );
}

export function SaindoAgoraSection({ rows, onOpen }: { rows: ShortcutDatum[]; onOpen: (key: string) => void }) {
  if (rows.length === 0) return null;
  return (
    <View>
      <SectionHeader title={uiStrings.saindoAgora} />
      {rows.map((r) => (
        <LineRow key={r.key} line={r.line} status={r.statusText} onPress={() => onOpen(r.key)} />
      ))}
    </View>
  );
}

export function LiveNowSection({
  lines,
  onOpen,
  onAll,
}: {
  lines: LineVM[];
  onOpen: (key: string) => void;
  onAll: () => void;
}) {
  const t = useTheme();
  return (
    <View>
      <SectionHeader title={uiStrings.homeLiveNow} actionLabel={uiStrings.homeLiveAll} onAction={onAll} />
      {lines.map((l) => (
        <LineRow
          key={l.key}
          line={l}
          status={`${l.liveVehicleCount ?? 0} ${uiStrings.liveCount}`}
          onPress={() => onOpen(l.key)}
        />
      ))}
      <Text style={[t.text.caption, styles.trust]}>{uiStrings.homeTrust}</Text>
    </View>
  );
}

export function NoLiveCard({ onShare }: { onShare?: () => void }) {
  const t = useTheme();
  return (
    <SurfaceCard>
      <Text style={t.text.headline}>{uiStrings.homeNoLive}</Text>
      <Text style={[t.text.body, { color: t.colors.inkMuted, marginTop: 8 }]}>{uiStrings.homeNoLiveHint}</Text>
      {onShare ? (
        <View style={{ marginTop: 12 }}>
          <GhostLink label={uiStrings.dockIdle} onPress={onShare} />
        </View>
      ) : null}
    </SurfaceCard>
  );
}

export function RecentsSection({
  lines,
  onOpen,
  onClear,
}: {
  lines: LineVM[];
  onOpen: (key: string) => void;
  onClear: () => void;
}) {
  if (lines.length === 0) return null;
  return (
    <View>
      <SectionHeader title={uiStrings.homeRecents} actionLabel={uiStrings.homeRecentsClear} onAction={onClear} />
      {lines.map((l) => (
        <LineRow key={l.key} line={l} status={l.terminals?.join(" · ") ?? ""} onPress={() => onOpen(l.key)} />
      ))}
    </View>
  );
}

export function AllLinesRow({ onOpen }: { onOpen: () => void }) {
  return (
    <View>
      <SectionHeader title={uiStrings.homeAllLines} actionLabel={uiStrings.homeAllLinesGo} onAction={onOpen} />
    </View>
  );
}

const styles = StyleSheet.create({
  chipSlot: { minHeight: 30, justifyContent: "center" },
  chip: {
    flexDirection: "row",
    alignItems: "center",
    gap: 8,
    height: 30,
    paddingHorizontal: 12,
    borderWidth: 1,
    borderRadius: 999,
  },
  strip: { gap: 12, paddingVertical: 4 },
  cardWrap: { width: 220 },
  trust: { marginTop: 8 },
});
