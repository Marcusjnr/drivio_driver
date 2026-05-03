import 'package:drivio_driver/modules/commons/data/profile_summary_repository.dart';
import 'package:drivio_driver/modules/commons/logging/supabase_logging.dart';
import 'package:drivio_driver/modules/commons/supabase/supabase_module.dart';
import 'package:drivio_driver/modules/commons/types/profile_summary.dart';

class SupabaseProfileSummaryRepository implements ProfileSummaryRepository {
  SupabaseProfileSummaryRepository(this._supabase);

  final SupabaseModule _supabase;

  @override
  Future<ProfileSummary> getMyProfileSummary() async {
    final dynamic raw =
        await loggedRpc(_supabase, 'get_my_profile_summary');
    if (raw == null) return ProfileSummary.empty;
    if (raw is List<dynamic>) {
      if (raw.isEmpty) return ProfileSummary.empty;
      return ProfileSummary.fromJson(raw.first as Map<String, dynamic>);
    }
    if (raw is Map<String, dynamic>) {
      return ProfileSummary.fromJson(raw);
    }
    return ProfileSummary.empty;
  }

  @override
  Future<ReferralSummary> getMyReferralSummary() async {
    final dynamic raw =
        await loggedRpc(_supabase, 'get_my_referral_summary');
    if (raw == null) return ReferralSummary.empty;
    if (raw is List<dynamic>) {
      if (raw.isEmpty) return ReferralSummary.empty;
      return ReferralSummary.fromJson(raw.first as Map<String, dynamic>);
    }
    if (raw is Map<String, dynamic>) {
      return ReferralSummary.fromJson(raw);
    }
    return ReferralSummary.empty;
  }
}
