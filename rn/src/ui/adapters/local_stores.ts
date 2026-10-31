// Local stores adapter. Port of app/lib/ui/adapters/local_stores.dart.
export const shortcutsKey = "ui_shortcuts_v1";
export const recentsKey = "ui_recents_v1";
export const favoritesKey = "ui_favorites_v1";
export const dataSaverKey = "ui_data_saver_v1";
export const diagnosticsOptInKey = "diag_opt_in_v1";
export const reduceMotionKey = "ui_reduce_motion_v1";
export const reduceMotionModeKey = "ui_reduce_motion_mode_v1";
export const kudosKey = "ui_kudos_v1";

export class KudosStore {
  async read(): Promise<number> {
    try {
      const raw = globalThis.localStorage?.getItem(kudosKey);
      return raw ? parseInt(raw, 10) || 0 : 0;
    } catch {
      return 0;
    }
  }
  async addOne(): Promise<void> {
    const cur = await this.read();
    globalThis.localStorage?.setItem(kudosKey, String(cur + 1));
  }
}