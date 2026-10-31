// Shortcut picker sheet. Port of app/lib/ui/features/home/shortcut_sheet.dart.
// Lists lines so the rider can pin up to a few shortcuts (stored locally).
import React, { useMemo, useState } from "react";
import { View, Text, FlatList, StyleSheet } from "react-native";
import { useTheme } from "../../design/theme/context";
import { PontualSheet } from "../../design/components/pontual_sheet";
import { SearchField } from "../../design/components/search_field";
import { LineRow } from "../../design/components/line_row";
import { uiStrings } from "../../strings/uiStrings";
import type { LineVM } from "../../models/line_vm";
import { buildLineIndex, searchLines } from "../../util/search_index";

export const maxShortcuts = 4;

export function ShortcutSheet({
  lines,
  pinned,
  onToggle,
  statusOf,
}: {
  lines: LineVM[];
  pinned: string[];
  onToggle: (key: string) => void;
  statusOf: (line: LineVM) => string;
}) {
  const t = useTheme();
  const [q, setQ] = useState("");
  const index = useMemo(() => buildLineIndex(lines), [lines]);
  const shown = useMemo(() => {
    if (q.trim() === "") return lines;
    return searchLines(index, q).map((m) => m.line);
  }, [index, lines, q]);
  return (
    <PontualSheet title={uiStrings.addShortcut} scrollable>
      <SearchField hint={uiStrings.searchHint} value={q} onChange={setQ} />
      <Text style={[t.text.caption, styles.hint]}>
        {pinned.length}/{maxShortcuts}
      </Text>
      <FlatList
        data={shown}
        keyExtractor={(l) => l.key}
        renderItem={({ item }) => (
          <LineRow
            line={item}
            status={statusOf(item)}
            isFavorite={pinned.includes(item.key)}
            onPress={() => onToggle(item.key)}
            onToggleFavorite={() => onToggle(item.key)}
          />
        )}
      />
      <View style={{ height: 24 }} />
    </PontualSheet>
  );
}

const styles = StyleSheet.create({ hint: { marginTop: 8 } });
