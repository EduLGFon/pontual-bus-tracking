// Home (Início) screen. Port of app/lib/ui/features/home/home_screen.dart.
// Paints from cached lines; live info fills in later without layout jump.
// Live triggers: open, resume, pull-to-refresh (min 10 s). No polling timer.
import React, { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { AppState, Modal, RefreshControl, ScrollView, Text, View, StyleSheet } from "react-native";
import { useRouter } from "expo-router";
import { useTheme } from "../../design/theme/context";
import { Banner } from "../../design/components/banner";
import { Toast } from "../../design/components/toast";
import { lineVmOf } from "../../adapters/lines_adapter";
import { useStaticStore } from "../../../stores";
import { staticData, type StaticLine } from "../../../data/static/staticData";
import { busApi } from "../../../data/api/busApi";
import * as storage from "../../../data/prefs/storage";
import { recentsKey, shortcutsKey } from "../../adapters/local_stores";
import { uiStrings } from "../../strings/uiStrings";
import { greetingFor, nextDepartureToday, firstDepartureTomorrow, leavingNowThresholdMin, resolveShortcutState } from "./home_logic";
import { useHomeOnboarding } from "./welcome_state";
import { CoachmarkBubble, WelcomeCard } from "./first_run";
import { ShortcutSheet, maxShortcuts } from "./shortcut_sheet";
import {
  AllLinesRow,
  LiveNowSection,
  LiveSummaryChip,
  NoLiveCard,
  RecentsSection,
  SaindoAgoraSection,
  SearchEntry,
  ShortcutsSection,
  type ShortcutDatum,
} from "./home_sections";

const liveSectionMax = 5;
const liveMinIntervalMs = 10_000;

function greetingText(now: Date): string {
  const part = greetingFor(now.getHours());
  if (part === "morning") return uiStrings.greetingMorning;
  if (part === "afternoon") return uiStrings.greetingAfternoon;
  return uiStrings.greetingEvening;
}

async function readKeys(key: string): Promise<string[]> {
  try {
    const raw = await storage.getItem(key);
    if (!raw) return [];
    const arr = JSON.parse(raw);
    return Array.isArray(arr) ? arr.filter((x) => typeof x === "string") : [];
  } catch {
    return [];
  }
}

export function HomeScreen() {
  const t = useTheme();
  const router = useRouter();
  const storeLines = useStaticStore((s) => s.lines);
  const setStoreLines = useStaticStore((s) => s.setLines);
  const [liveCounts, setLiveCounts] = useState<Record<number, number>>({});
  const [liveKnown, setLiveKnown] = useState(false);
  const [liveFailed, setLiveFailed] = useState(false);
  const [refreshing, setRefreshing] = useState(false);
  const [shortcuts, setShortcuts] = useState<string[]>([]);
  const [recents, setRecents] = useState<string[]>([]);
  const [toast, setToast] = useState<string | null>(null);
  const [sheetOpen, setSheetOpen] = useState(false);
  const lastLiveMs = useRef(0);
  const onboarding = useHomeOnboarding();

  useEffect(() => {
    if (toast == null) return;
    const id = setTimeout(() => setToast(null), 3000);
    return () => clearTimeout(id);
  }, [toast]);

  const refreshLive = useCallback(async () => {
    const nowMs = Date.now();
    if (nowMs - lastLiveMs.current < liveMinIntervalMs) return;
    lastLiveMs.current = nowMs;
    const r = await busApi.getLive();
    if (r.ok) {
      const counts: Record<number, number> = {};
      for (const [lineId, n] of r.value) counts[lineId] = n;
      setLiveCounts(counts);
      setLiveKnown(true);
      setLiveFailed(false);
    } else {
      setLiveFailed(true);
    }
  }, []);

  useEffect(() => {
    let live = true;
    (async () => {
      const ls = await staticData.currentLines();
      if (live && ls.length > 0) setStoreLines(ls);
      const changed = await staticData.refresh();
      if (live && changed) {
        const fresh = await staticData.currentLines();
        if (live && fresh.length > 0) setStoreLines(fresh);
      }
      const r = await busApi.getLive();
      if (!live) return;
      if (r.ok) {
        const counts: Record<number, number> = {};
        for (const [lineId, n] of r.value) counts[lineId] = n;
        lastLiveMs.current = Date.now();
        setLiveCounts(counts);
        setLiveKnown(true);
      } else {
        setLiveFailed(true);
      }
      const [s, rec] = await Promise.all([readKeys(shortcutsKey), readKeys(recentsKey)]);
      if (!live) return;
      setShortcuts(s.slice(0, maxShortcuts));
      setRecents(rec.slice(0, 6));
    })();
    const sub = AppState.addEventListener("change", (st) => {
      if (st === "active") void refreshLive();
    });
    return () => {
      live = false;
      sub.remove();
    };
  }, [refreshLive, setStoreLines]);

  const onRefresh = useCallback(async () => {
    setRefreshing(true);
    try {
      await refreshLive();
    } finally {
      setRefreshing(false);
    }
  }, [refreshLive]);

  const activeLines = useMemo(() => storeLines.filter((l) => l.is_active), [storeLines]);
  const lineVMs = useMemo(
    () => activeLines.map((l) => lineVmOf(l, liveCounts[l.id] ?? 0)),
    [activeLines, liveCounts],
  );
  const byKey = useMemo(() => {
    const m = new Map<string, StaticLine>();
    for (const l of activeLines) m.set(l.code, l);
    return m;
  }, [activeLines]);

  const openLine = useCallback(
    (key: string) => {
      setRecents((prev) => {
        const next = [key, ...prev.filter((k) => k !== key)].slice(0, 6);
        storage.setItem(recentsKey, JSON.stringify(next)).catch(() => {});
        return next;
      });
      router.push(`/line/${key}`);
    },
    [router],
  );

  const toggleShortcut = useCallback((key: string) => {
    setShortcuts((prev) => {
      const next = prev.includes(key) ? prev.filter((k) => k !== key) : [...prev, key].slice(0, maxShortcuts);
      storage.setItem(shortcutsKey, JSON.stringify(next)).catch(() => {});
      return next;
    });
  }, []);

  const now = useMemo(() => new Date(), []);
  const saindoRows: ShortcutDatum[] = useMemo(
    () =>
      activeLines.flatMap((line) => {
        if ((liveCounts[line.id] ?? 0) > 0) return [];
        const next = nextDepartureToday(line, now);
        if (next == null) return [];
        const [h, m] = next.time.split(":").map(Number);
        const mins = h * 60 + m - (now.getHours() * 60 + now.getMinutes());
        if (mins < 0 || mins > leavingNowThresholdMin) return [];
        return [
          {
            key: line.code,
            line: lineVmOf(line, 0),
            statusText: `${next.time} · ${uiStrings.originLabel} ${next.origin}`,
            isLive: false,
            direction: line.terminals.join(" · ") || null,
            tomorrowAt: null,
          },
        ];
      }).slice(0, 5),
    [activeLines, liveCounts, now],
  );
  const cards: ShortcutDatum[] = useMemo(
    () =>
      shortcuts.flatMap((key) => {
        const line = byKey.get(key);
        if (!line) return [];
        const next = nextDepartureToday(line, now);
        const state = resolveShortcutState({
          isLive: (liveCounts[line.id] ?? 0) > 0,
          hasNext: next != null,
          nextInS: null,
          hasTimetable: line.schedules.length > 0,
        });
        const statusText =
          state === "live"
            ? `${liveCounts[line.id] ?? 0} ${uiStrings.liveCount}`
            : next
              ? `${uiStrings.originLabel} ${next.origin} · ${next.time}`
              : state === "noneToday"
                ? uiStrings.homeNoMoreToday
                : uiStrings.homeNoTime;
        return [
          {
            key,
            line: lineVmOf(line, liveCounts[line.id] ?? 0),
            statusText,
            isLive: state === "live",
            direction: line.terminals.join(" · ") || null,
            tomorrowAt: next == null ? firstDepartureTomorrow(line) : null,
          },
        ];
      }),
    [shortcuts, byKey, liveCounts, now],
  );

  const liveLines = useMemo(
    () => lineVMs.filter((l) => l.isLive).sort((a, b) => (b.liveVehicleCount ?? 0) - (a.liveVehicleCount ?? 0)),
    [lineVMs],
  );
  const liveTotal = useMemo(() => liveLines.reduce((n, l) => n + (l.liveVehicleCount ?? 0), 0), [liveLines]);
  const recentVMs = useMemo(
    () => recents.flatMap((k) => lineVMs.filter((l) => l.key === k).slice(0, 1)),
    [recents, lineVMs],
  );
  const offline = liveFailed && !liveKnown;

  return (
    <View style={[styles.root, { backgroundColor: t.colors.bg }]}>
      <ScrollView
        contentContainerStyle={styles.content}
        refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} />}>
        {!onboarding.welcomeSeen ? (
          <WelcomeCard onDismiss={onboarding.dismissWelcome} />
        ) : null}
        <Text style={[t.text.title, { color: t.colors.primary }]}>{uiStrings.wordmark}</Text>
        <View style={styles.headRow}>
          <View style={{ flex: 1 }}>
            <Text style={t.text.display}>{greetingText(now)}</Text>
            <Text style={[t.text.body, { color: t.colors.inkMuted }]}>{uiStrings.homeSubtitle}</Text>
          </View>
          <LiveSummaryChip total={liveTotal} known={liveKnown} offline={offline} />
        </View>
        <View style={{ marginTop: 12 }}>
          <SearchEntry />
        </View>
        {offline ? (
          <View style={{ marginTop: 12 }}>
            <Banner text={uiStrings.offlineBanner} />
          </View>
        ) : null}
        {liveFailed && liveKnown ? (
          <View style={{ marginTop: 12 }}>
            <Banner text={`${uiStrings.genericError} · ${uiStrings.retry}`} />
          </View>
        ) : null}
        <ShortcutsSection cards={cards} onOpen={openLine} onAdd={() => setSheetOpen(true)} />
        <SaindoAgoraSection rows={saindoRows} onOpen={openLine} />
        {liveLines.length > 0 ? (
          <LiveNowSection lines={liveLines.slice(0, liveSectionMax)} onOpen={openLine} onAll={() => router.push("/lines")} />
        ) : (
          <View style={{ marginTop: 16 }}>
            <NoLiveCard onShare={() => router.push("/trip")} />
          </View>
        )}
        <RecentsSection
          lines={recentVMs}
          onOpen={openLine}
          onClear={() => {
            setRecents([]);
            storage.setItem(recentsKey, "[]").catch(() => {});
            setToast(uiStrings.homeRecentsCleared);
          }}
        />
        <AllLinesRow onOpen={() => router.push("/lines")} />
        <View style={{ height: 96 }} />
      </ScrollView>
      {!onboarding.coachmarkSeen ? (
        <View style={styles.coach}>
          <CoachmarkBubble onDismiss={onboarding.dismissCoachmark} />
        </View>
      ) : null}
      {toast != null ? <Toast message={toast} /> : null}
      <Modal visible={sheetOpen} animationType="slide" onRequestClose={() => setSheetOpen(false)}>
        <View style={[styles.sheetWrap, { backgroundColor: t.colors.bg }]}>
          <ShortcutSheet
            lines={lineVMs}
            pinned={shortcuts}
            onToggle={toggleShortcut}
            statusOf={(l) => l.terminals?.join(" · ") ?? ""}
          />
        </View>
      </Modal>
    </View>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1 },
  content: { padding: 16, paddingBottom: 32 },
  headRow: { flexDirection: "row", alignItems: "center", marginTop: 12, gap: 12 },
  coach: { position: "absolute", left: 16, right: 16, bottom: 96 },
  sheetWrap: { flex: 1, paddingTop: 48 },
});
