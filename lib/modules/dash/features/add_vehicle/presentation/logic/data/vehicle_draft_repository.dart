import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:drivio_driver/modules/commons/supabase/supabase_module.dart';

/// A driver's saved add-vehicle progress, one row per driver
/// (`vehicle_onboarding_drafts`). Steps write here as they complete so
/// killing the app mid-flow resumes at the next step; the final submit
/// creates the real vehicle row and deletes the draft.
class VehicleDraft {
  const VehicleDraft({
    required this.details,
    required this.amenities,
    required this.documents,
    required this.stepCompleted,
  });

  /// Step 1 payload: make, model, year, colour, transmission, fuel_type,
  /// plate, vin, mileage - all as entered.
  final Map<String, dynamic>? details;

  /// Step 2 selection. An empty list after step 2 completes means the
  /// driver explicitly skipped amenities.
  final List<String> amenities;

  /// Step 3 uploads so far: kind name -> {path, name}.
  final Map<String, dynamic> documents;

  /// Highest fully completed step (0 = nothing, 1 = details, 2 =
  /// amenities). 3 never persists: submitting deletes the draft.
  final int stepCompleted;

  static VehicleDraft fromJson(Map<String, dynamic> json) {
    return VehicleDraft(
      details: (json['details'] as Map<dynamic, dynamic>?)
          ?.cast<String, dynamic>(),
      amenities: ((json['amenities'] as List<dynamic>?) ?? const <dynamic>[])
          .cast<String>(),
      documents: ((json['documents'] as Map<dynamic, dynamic>?) ??
              const <dynamic, dynamic>{})
          .cast<String, dynamic>(),
      stepCompleted: (json['step_completed'] as num?)?.toInt() ?? 0,
    );
  }
}

class VehicleDraftRepository {
  VehicleDraftRepository(this._supabase);

  final SupabaseModule _supabase;

  String get _uid {
    final User? user = _supabase.auth.currentUser;
    if (user == null) {
      throw StateError('no signed-in user');
    }
    return user.id;
  }

  Future<VehicleDraft?> load() async {
    final Map<String, dynamic>? row = await _supabase
        .db('vehicle_onboarding_drafts')
        .select()
        .eq('driver_id', _uid)
        .maybeSingle();
    return row == null ? null : VehicleDraft.fromJson(row);
  }

  /// Step 1 done: save the vehicle details.
  Future<void> saveDetails(Map<String, dynamic> details) async {
    await _supabase.db('vehicle_onboarding_drafts').upsert(<String, dynamic>{
      'driver_id': _uid,
      'details': details,
      'step_completed': 1,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  /// Step 2 done (Continue with a selection, or Skip with none).
  Future<void> saveAmenities(List<String> codes) async {
    await _supabase
        .db('vehicle_onboarding_drafts')
        .update(<String, dynamic>{
          'amenities': codes,
          'step_completed': 2,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('driver_id', _uid);
  }

  /// Remember an uploaded file mid-step-3 so re-entry keeps it.
  Future<void> saveDocuments(Map<String, dynamic> documents) async {
    await _supabase
        .db('vehicle_onboarding_drafts')
        .update(<String, dynamic>{
          'documents': documents,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('driver_id', _uid);
  }

  /// Final submit succeeded: the real vehicle row exists, drop the draft.
  Future<void> clear() async {
    await _supabase
        .db('vehicle_onboarding_drafts')
        .delete()
        .eq('driver_id', _uid);
  }
}
