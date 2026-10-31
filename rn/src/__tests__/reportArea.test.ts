import { reportAreaOf, reportAreaCenterOf, isValidReportArea } from "../domain/reporting/reportArea";

describe("reportArea", () => {
  test("cell id format and center", () => {
    const id = reportAreaOf(-18.7, -39.8);
    expect(id).toMatch(/^g\d+_\d+$/);
    expect(isValidReportArea(id)).toBe(true);
    expect(reportAreaCenterOf(id)).not.toBeNull();
  });
});
