// Line chooser sheet. Port of app/lib/ui/features/trip/line_chooser_sheet.dart.
import React, { useMemo, useState } from "react";
import { FlatList, View } from "react-native";
import { PontualSheet } from "../../design/components/pontual_sheet";
import { SearchField } from "../../design/components/search_field";
import { LineRow } from "../../design/components/line_row";
import { uiStrings } from "../../strings/uiStrings";
import type { LineVM } from "../../models/line_vm";
import { buildLineIndex, searchLines } from "../../util/search_index";

export function LineChooserSheet({
  lines,
  onChoose,
}: {
  lines: LineVM[];
  onChoose: (line: LineVM) => void;
}) {
  const [q, setQ] = useState("");
  const index = useMemo(() => buildLineIndex(lines), [lines]);
  const shown = useMemo(
    () => (q.trim() === "" ? lines : searchLines(index, q).map((m) => m.line)),
    [index, lines, q],
  );
  return (
    <PontualSheet title={uiStrings.chooseLineTitle} scrollable>
      <SearchField hint={uiStrings.searchHint} value={q} onChange={setQ} autoFocus />
      <View style={{ height: 8 }} />
      <FlatList
        data={shown}
        keyExtractor={(l) => l.key}
        renderItem={({ item }) => (
          <LineRow
            line={item}
            status={item.terminals?.join(" · ") ?? ""}
            onPress={() => onChoose(item)}
          />
        )}
      />
      <View style={{ height: 24 }} />
    </PontualSheet>
  );
}
