// Place search: lines whose learned route passes through a searched place.
// Offline: gazetteer is bundled and the learned index is cached in memory.
import 'package:flutter/material.dart';
import 'package:pontual/core/geo/route_proximity.dart';
import 'package:pontual/domain/learning/learned_route_index.dart';
import 'package:pontual/domain/learning/place.dart';
import 'package:pontual/ui/design/components/line_badge.dart';
import 'package:pontual/ui/design/components/surface_card.dart';
import 'package:pontual/ui/design/theme/context.dart';
import 'package:pontual/ui/design/tokens/spacing.dart';
import 'package:pontual/ui/features/search/search_screen.dart';
import 'package:pontual/ui/models/line_vm.dart';
import 'package:pontual/ui/strings/ui_strings.dart';
import 'package:pontual/ui/util/search_index.dart';

/// One place-search result.
class PlaceHit implements SearchHit {
  /// Creates a hit.
  PlaceHit({required this.line, required this.placeName});

  /// Matched line.
  final LineVM line;

  /// Place that matched.
  final String placeName;

  @override
  String get key => line.key;
}

/// Searches lines by the places their learned route passes through.
class PlaceSearchProvider implements SearchProvider {
  /// Creates a provider over [places], [index] and [lines].
  /// Normalized place names and the line code map are built once here,
  /// so per-keystroke `search` does no string normalization of the
  /// gazetteer and no linear line scan.
  PlaceSearchProvider({
    required this.places,
    required this.index,
    required this.lines,
  }) : _normPlaces = <_NormPlace>[
         for (final Place p in places)
           _NormPlace(
             place: p,
             normFields: <String>[
               p.name,
               ...p.aliases,
             ].map(normalizeText).toList(),
           ),
       ],
       _lineByCode = <String, LineVM>{for (final LineVM l in lines) l.key: l};

  /// Bundled gazetteer.
  final List<Place> places;

  /// Cached learned routes.
  final LearnedRoutesIndex index;

  /// Available lines.
  final List<LineVM> lines;

  final List<_NormPlace> _normPlaces;
  final Map<String, LineVM> _lineByCode;

  @override
  String get groupLabel => UiStrings.searchPlaces;

  @override
  List<SearchHit> search(String query) {
    final String q = normalizeText(query);
    if (q.isEmpty) return const <SearchHit>[];
    // Places matching the query, using pre-normalized fields.
    final List<_NormPlace> matchedPlaces = _normPlaces.where((_NormPlace n) {
      return matchesAllTokens(n.normFields, q) ||
          n.normFields.any((String f) => f.contains(q));
    }).toList();
    if (matchedPlaces.isEmpty) return const <SearchHit>[];

    final Map<String, _Scored> best = <String, _Scored>{};
    for (final _NormPlace n in matchedPlaces) {
      for (final LearnedRouteEntry entry in index.entries) {
        // Single route scan per pair; the stop scan runs only on a miss.
        final double routeD = minDistanceToPolylineM(
          n.place.point,
          entry.points,
        );
        final bool near =
            routeD <= 500 ||
            minDistanceToEntryStopsM(n.place.point, entry) <= 300;
        if (!near) continue;
        final LineVM? line = _lineByCode[entry.code];
        if (line == null) continue;
        final _Scored candidate = _Scored(
          line: line,
          place: n.place.name,
          distance: routeD,
        );
        final _Scored? prev = best[line.key];
        if (prev == null || routeD < prev.distance) {
          best[line.key] = candidate;
        }
      }
    }
    final List<_Scored> sorted = best.values.toList()
      ..sort((_Scored a, _Scored b) {
        final int byDist = a.distance.compareTo(b.distance);
        if (byDist != 0) return byDist;
        return a.line.name.toLowerCase().compareTo(b.line.name.toLowerCase());
      });
    return sorted
        .map((_Scored s) => PlaceHit(line: s.line, placeName: s.place))
        .toList();
  }

  @override
  Widget row(SearchHit hit, VoidCallback onTap) {
    if (hit is! PlaceHit) return const SizedBox.shrink();
    return _PlaceResultRow(
      line: hit.line,
      placeName: hit.placeName,
      onTap: onTap,
    );
  }
}

/// Row for a place-search hit.
class _PlaceResultRow extends StatelessWidget {
  const _PlaceResultRow({
    required this.line,
    required this.placeName,
    required this.onTap,
  });

  final LineVM line;
  final String placeName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: Space.x4,
        vertical: Space.x3,
      ),
      child: Row(
        children: <Widget>[
          LineBadge.ofLine(line, size: BadgeSize.m),
          const SizedBox(width: Space.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  line.name,
                  style: context.text.headline,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  UiStrings.searchPlacePassesBy(placeName),
                  style: context.text.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Scored {
  const _Scored({
    required this.line,
    required this.place,
    required this.distance,
  });

  final LineVM line;
  final String place;
  final double distance;
}

class _NormPlace {
  const _NormPlace({required this.place, required this.normFields});

  final Place place;
  final List<String> normFields;
}
