import 'package:drivio_driver/modules/commons/types/dashboard_summary.dart';

abstract class DashboardRepository {
  /// Fetch the calling driver's "today" dashboard tile metrics:
  /// earnings, completed-trip count, online-time proxy, and (when
  /// available) overall rating.
  Future<DashboardSummary> getMyToday();
}
