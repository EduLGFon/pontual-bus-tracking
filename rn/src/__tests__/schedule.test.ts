import { nextDeparture, resolveNextDeparture, groupByHour, minutesOf } from "../domain/schedule";

function assert(cond: boolean, msg: string) {
  if (!cond) throw new Error(msg);
}

assert(nextDeparture(["08:00", "09:00"], 8 * 60 + 30) === "09:00", "next");
const r = resolveNextDeparture({ todayTimes: ["08:00"], tomorrowTimes: ["07:00"], nowMinutes: 9 * 60 });
assert(r !== null && r.isTomorrow === true && r.time === "07:00", "resolve tomorrow");
const g = groupByHour(["08:30", "08:45"]);
assert(Array.isArray(g["08"]) && g["08"].length === 2, "group");
assert(minutesOf("08:30") === 510, "minutes");
