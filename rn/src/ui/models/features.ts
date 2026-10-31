// Feature flags. Port of app/lib/ui/models/features.dart.
export interface Features {
  shortcuts: boolean;
  recents: boolean;
  favorites: boolean;
  dataSaver: boolean;
  predictions: boolean;
  eta: boolean;
  arrivalAlerts: boolean;
  reliability: boolean;
  followVehicle: boolean;
  routeLine: boolean;
  localKudos: boolean;
  reports: boolean;
}

export const defaultFeatures: Features = {
  shortcuts: true,
  recents: true,
  favorites: true,
  dataSaver: true,
  predictions: true,
  eta: true,
  arrivalAlerts: true,
  reliability: true,
  followVehicle: true,
  routeLine: false,
  localKudos: true,
  reports: true,
};

export function featuresFromJson(json: any): Features {
  const f = (key: string, fallback: boolean): boolean => {
    const v = json?.[key];
    return typeof v === "boolean" ? v : fallback;
  };
  return {
    shortcuts: f("shortcuts", defaultFeatures.shortcuts),
    recents: f("recents", defaultFeatures.recents),
    favorites: f("favorites", defaultFeatures.favorites),
    dataSaver: f("data_saver", defaultFeatures.dataSaver),
    predictions: f("predictions", defaultFeatures.predictions),
    eta: f("eta", defaultFeatures.eta),
    arrivalAlerts: f("arrival_alerts", defaultFeatures.arrivalAlerts),
    reliability: f("reliability", defaultFeatures.reliability),
    followVehicle: f("follow_vehicle", defaultFeatures.followVehicle),
    routeLine: f("route_line", defaultFeatures.routeLine),
    localKudos: f("local_kudos", defaultFeatures.localKudos),
    reports: f("reports", defaultFeatures.reports),
  };
}