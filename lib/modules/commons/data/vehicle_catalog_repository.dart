/// One make with its models, as served by the `get_vehicle_catalog`
/// RPC. Ordered server-side (sort_order, then name); models are
/// alphabetical. An empty [models] list means the make exists but has
/// no curated models yet — the UI falls back to free-text model entry,
/// exactly like the "Other" make.
class VehicleCatalogEntry {
  const VehicleCatalogEntry({required this.make, required this.models});

  final String make;
  final List<String> models;

  factory VehicleCatalogEntry.fromJson(Map<String, dynamic> json) {
    return VehicleCatalogEntry(
      make: json['make'] as String,
      models: (json['models'] as List<dynamic>? ?? const <dynamic>[])
          .map((dynamic m) => m as String)
          .toList(growable: false),
    );
  }
}

/// Server-driven vehicle make/model catalog (admin-curated in the
/// dashboard's Vehicle catalog page). Replaces the bundled static list
/// so ops can add cars without an app release; the static list survives
/// only as the offline fallback in `vehicle_options.dart`.
abstract class VehicleCatalogRepository {
  /// Active makes with their active models. Throws on failure — the
  /// caller (AddVehicleController) falls back to the bundled catalog.
  Future<List<VehicleCatalogEntry>> getCatalog();
}
