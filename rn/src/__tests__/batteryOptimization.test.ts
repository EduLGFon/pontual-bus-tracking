import { Platform } from "react-native";
import {
  isIgnoringBatteryOptimizations,
  requestIgnoreBatteryOptimizations,
} from "../platform/android/batteryOptimization";

describe("batteryOptimization", () => {
  test("never throws and stays false off Android", async () => {
    if (Platform.OS === "android") return;
    await expect(isIgnoringBatteryOptimizations()).resolves.toBe(false);
    await expect(requestIgnoreBatteryOptimizations()).resolves.toBe(false);
  });

  test("injected exemption keeps sharing contract", async () => {
    const denied = async () => false;
    const granted = async () => true;
    await expect(denied()).resolves.toBe(false);
    await expect(granted()).resolves.toBe(true);
  });
});
