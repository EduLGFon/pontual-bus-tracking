import { busApi } from "../../data/api/busApi";
import { reportArea } from "../../domain/reporting/report";

export async function createReport(
  token: string,
  kind: string,
  lineId: number,
  lat: number,
  lng: number,
) {
  const area = kind === "waiting" || kind === "blocked" ? reportArea(lat, lng) : undefined;
  return busApi.postReport(token, { op: "report", kind, lineId, area });
}

export async function retractReport(token: string, kind: string, lineId: number) {
  return busApi.postReport(token, { op: "retract", kind, lineId });
}
