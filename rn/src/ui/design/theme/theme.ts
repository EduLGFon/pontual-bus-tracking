// Theme helpers. Port of app/lib/ui/design/theme/theme.dart.
import { colorsLight, colorsDark } from "../tokens/colors";
export function pontualColors(resolved: "light" | "dark") {
  return resolved === "dark" ? colorsDark : colorsLight;
}