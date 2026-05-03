import 'package:drivio_driver/modules/commons/types/coach_tip.dart';

abstract class CoachTipRepository {
  /// Fetch the highest-priority coaching tips for the calling driver.
  /// Empty list = no actionable insights right now (UI hides the
  /// surface). Server caps at 5.
  Future<List<CoachTip>> getMyTips({int limit = 3});
}
