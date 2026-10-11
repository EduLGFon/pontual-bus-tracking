# Manual accessibility script (UI_SPEC 12.13)

Run on every release candidate and whenever a screen changes. Record the
result in `docs/ui/AUDIT.md`. No coordinates, ids or tokens may appear in
the notes.

## Android (TalkBack)

1. Open the app. TalkBack reads: "Veja onde o ônibus está. Quem está dentro
   compartilha a posição, de forma anônima."
2. Swipe through Início: greeting, search entry, shortcuts, live section,
   recents, all lines row. Every element announces its action in pt-BR.
3. Open a line. The map is one region: "Mapa da linha, N ônibus". Swipe to
   the vehicle list for the same information as text.
4. Start a trip. The dock says "Estou neste ônibus". The consent sheet is
   read in full before the OS permission dialog appears.
5. Explore the trip screen: connection, GPS and device rows announce icon
   and text, never colour alone.
6. End the trip. The end card announces the checkmark and the reason.
7. Turn the screen off and on during a trip. The sharing continues
   (foreground service) and the notification is announced.

## Web (NVDA or VoiceOver)

1. Load the site with the browser in pt-BR. `lang="pt-BR"` is honoured.
2. Tab from the top: wordmark, live summary chip, search entry, shortcuts,
   live section, recents, all lines, then the three tabs. No keyboard trap.
3. Press `/` anywhere: the search field takes focus. Type, use Up/Down to
   move through results, Enter opens the first result, Esc closes search.
4. Open a line by deep link (`/line/<key>`). The page renders, the tab
   order is logical, and the recenter button is reachable.
5. With keyboard only, start and end a trip.

## Keyboard only (desktop)

- `Tab` and `Shift+Tab` move forward and back with a visible focus ring.
- `Enter` and `Space` activate. `Esc` closes sheets and search.
- Arrow keys move inside the segmented control and the search results.
- `/` focuses search from anywhere.

## Screen reader phrasing to verify

- "Linha Litorâneo Aviação. Chega em 4 minutos, ao vivo."
- "Linha Litorâneo Aviação. Próxima saída às 14 e 35, em 12 minutos.
  Horário previsto pela tabela."
- "Previsão: chega em cerca de 4 minutos. Não é uma posição ao vivo."
- "Ônibus 1, atualizado há 8 segundos, 32 quilômetros por hora."
- Live updates announce at most once every 30 s per line, for example
  "2 ônibus ao vivo na linha Litorâneo".

## Text scale and colour

- Set the system text scale to 1.0, 1.5 and 2.0 on a 360 dp wide screen.
  No clipping, no overlap, rows grow in height.
- Verify every state with only the certainty shape and label (no colour):
  hide colours with a monochrome filter and check that live, predicted,
  scheduled and stale are still distinguishable.
- Verify contrast in light and dark with the automated token test
  (`flutter test test/ui/contrast_test.dart`).
