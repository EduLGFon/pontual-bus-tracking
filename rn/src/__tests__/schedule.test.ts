import { nextDeparture, resolveNextDeparture, groupByHour, minutesOf } from "../domain/schedule";

describe("schedule", () => {
  test("next departure", () => {
    expect(nextDeparture(["08:00", "09:00"], 8 * 60 + 30)).toBe("09:00");
  });
  test("resolve tomorrow", () => {
    const r = resolveNextDeparture({ todayTimes: ["08:00"], tomorrowTimes: ["07:00"], nowMinutes: 9 * 60 });
    expect(r !== null && r.isTomorrow === true && r.time === "07:00").toBe(true);
  });
  test("group and minutes", () => {
    const g = groupByHour(["08:30", "08:45"]);
    expect(g["08"].length).toBe(2);
    expect(minutesOf("08:30")).toBe(510);
  });
});
