// Typed DTOs / zod schemas. Mirrors app/lib/data/api/dto.dart.
import { z } from "zod";

export const TripInstructionSchema = z.object({
  r: z.string(),
  n: z.number().int(),
  e: z.string().optional(),
});
export type TripInstruction = z.infer<typeof TripInstructionSchema>;

export const ReportDTOSchema = z.object({
  kind: z.string(),
  area: z.string().nullable().optional(),
  count: z.number().int(),
  created_age_s: z.number().int(),
  updated_age_s: z.number().int(),
  expires_in_s: z.number().int(),
});
export type ReportDTO = z.infer<typeof ReportDTOSchema>;

export const VehiclesSnapshotSchema = z.object({
  t: z.number().int(),
  v: z.array(z.array(z.number().nullable())),
  r: z.array(ReportDTOSchema).optional().default([]),
});
export type VehiclesSnapshot = z.infer<typeof VehiclesSnapshotSchema>;

export const ArrivalsPayloadSchema = z.object({
  t: z.number().int().optional().default(0),
  line: z.number().int().optional().default(0),
  passages: z.array(z.number()).optional().default([]),
  headwayMin: z.number().nullable().optional().default(null),
  sampleSize: z.number().int().optional().default(0),
});
export type ArrivalsPayload = z.infer<typeof ArrivalsPayloadSchema>;

export const LiveLinesSchema = z.array(z.tuple([z.number().int(), z.number().int()]));
export type LiveLines = z.infer<typeof LiveLinesSchema>;

export const LearnedRouteSchema = z.object({
  v: z.number().int(),
  dir: z.number().int(),
  polyline: z.string().nullable().optional(),
  points: z.number().int().nullable().optional(),
  trips: z.number().int(),
  computed_at: z.string().nullable().optional(),
  fallback: z.boolean().optional(),
});
export type LearnedRoute = z.infer<typeof LearnedRouteSchema>;

export const LearnedStopSchema = z.object({
  id: z.string(),
  i: z.number().int(),
  lat: z.number(),
  lng: z.number(),
  r: z.number(),
  n: z.number().int(),
});
export type LearnedStop = z.infer<typeof LearnedStopSchema>;

export const LearnedStopsSchema = z.object({
  dir: z.number().int(),
  stops: z.array(LearnedStopSchema),
  fallback: z.boolean().optional(),
});
export type LearnedStops = z.infer<typeof LearnedStopsSchema>;

export const RemoteConfigSchema = z.object({
  min_app_version: z.string(),
  maintenance: z.boolean(),
  message_pt: z.string(),
  consent_version: z.number().int(),
  tile_url: z.string(),
});
export type RemoteConfig = z.infer<typeof RemoteConfigSchema>;

export function parseReports(raw: unknown): ReportDTO[] {
  const r = z.array(ReportDTOSchema).safeParse(raw);
  return r.success ? r.data : [];
}
