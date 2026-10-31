import { reportAreaOf, reportAreaCenterOf, isValidReportArea } from "../domain/reporting/reportArea";

function assert(cond: boolean, msg: string) {
  if (!cond) throw new Error(msg);
}

const id = reportAreaOf(-18.7, -39.8);
assert(/^g\d+_\d+$/.test(id), "area id");
assert(isValidReportArea(id), "valid");
const c = reportAreaCenterOf(id);
assert(c !== null, "center");
