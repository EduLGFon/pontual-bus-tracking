// Favorites bridge. Port of app/lib/ui/features/lines/favorites_store_bridge.dart.
// Favorite line keys persisted locally; toggling reports a short message.
import { useCallback, useEffect, useState } from "react";
import * as storage from "../../../data/prefs/storage";
import { favoritesKey } from "../../adapters/local_stores";
import { uiStrings } from "../../strings/uiStrings";

export function useFavorites(): {
  favorites: string[];
  toggle: (key: string) => string;
  isFavorite: (key: string) => boolean;
} {
  const [favorites, setFavorites] = useState<string[]>([]);
  useEffect(() => {
    let live = true;
    (async () => {
      try {
        const raw = await storage.getItem(favoritesKey);
        const arr = raw ? (JSON.parse(raw) as unknown) : [];
        if (live && Array.isArray(arr)) setFavorites(arr.filter((x): x is string => typeof x === "string"));
      } catch {
        // Keep empty.
      }
    })();
    return () => {
      live = false;
    };
  }, []);
  const toggle = useCallback(
    (key: string) => {
      const added = !favorites.includes(key);
      const next = added ? [...favorites, key] : favorites.filter((k) => k !== key);
      setFavorites(next);
      storage.setItem(favoritesKey, JSON.stringify(next)).catch(() => {});
      return added ? uiStrings.linesFavAdded : uiStrings.linesFavRemoved;
    },
    [favorites],
  );
  const isFavorite = useCallback((key: string) => favorites.includes(key), [favorites]);
  return { favorites, toggle, isFavorite };
}
