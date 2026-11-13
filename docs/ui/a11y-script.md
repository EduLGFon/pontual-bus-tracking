# Manual accessibility script (UI_SPEC 12.13)

Run on every release candidate and when a screen changes. Record in `docs/ui/UI_SPEC.md`. No coordinates, ids or tokens in notes.

## Android (TalkBack)

1. Open app; TalkBack reads: "Veja onde o ônibus está. Quem está dentro compartilha a posição, de forma anônima."
2. Swipe Início: greeting, search entry, shortcuts, live section, recents, all lines row. Every element announces its action in pt-BR.
3. Open a line. Map is one region: "Mapa da linha, N ônibus". Swipe to vehicle list for the same info as text.
4. Start a trip. Dock says "Estou neste ônibus". Consent sheet is read fully before the OS permission dialog.
5. Explore trip screen: connection, GPS and device rows announce icon and text, never colour alone.
6. End trip. End card announces checkmark and reason.
7. Turn screen off/on during a trip. Sharing continues (foreground service) and notification is announced.

## Web (NVDA or VoiceOver)

1. Load site in pt-BR; `lang="pt-BR"` honoured.
2. Tab from top: wordmark, live summary chip, search entry, shortcuts, live section, recents, all lines, then three tabs. No keyboard trap.
3. Press `/` anywhere: search field takes focus. Type, Up/Down through results, Enter opens first result, Esc closes search.
4. Open line by deep link (`/line/<key>`). Page renders, tab order logical, recenter button reachable.
5. Keyboard only: start and end a trip.

## Keyboard only (desktop)

- `Tab`/`Shift+Tab` move forward/back with visible focus ring.
- `Enter`/`Space` activate. `Esc` closes sheets and search.
- Arrows move inside segmented control and search results.
- `/` focuses search from anywhere.

## Screen reader phrasing to verify

- "Linha Litorâneo Aviação. Chega em 4 minutos, ao vivo."
- "Linha Litorâneo Aviação. Próxima saída às 14 e 35, em 12 minutos. Horário previsto pela tabela."
- "Previsão: chega em cerca de 4 minutos. Não é uma posição ao vivo."
- "Ônibus 1, atualizado há 8 segundos, 32 quilômetros por hora."
- Live updates announce at most once every 30 s per line, e.g. "2 ônibus ao vivo na linha Litorâneo".

## Text scale and colour

- System text scale 1.0, 1.5 and 2.0 on 360 dp wide screen. No clipping, no overlap; rows grow in height.
- Verify every state with only certainty shape and label (no colour): monochrome filter; live, predicted, scheduled and stale still distinguishable.
- Verify contrast in light and dark with automated token test (`flutter test test/ui/contrast_test.dart`).
