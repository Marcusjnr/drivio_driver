import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:drivio_driver/modules/commons/config/config.dart';
import 'package:drivio_driver/modules/commons/config/flavor.dart';
import 'package:drivio_driver/modules/commons/supabase/supabase_module.dart';
import 'package:drivio_driver/modules/commons/data/coach_tip_repository.dart';
import 'package:drivio_driver/modules/commons/data/coach_tip_repository_impl.dart';
import 'package:drivio_driver/modules/commons/data/dashboard_repository.dart';
import 'package:drivio_driver/modules/commons/data/dashboard_repository_impl.dart';
import 'package:drivio_driver/modules/commons/data/directions_repository.dart';
import 'package:drivio_driver/modules/commons/data/directions_repository_impl.dart';
import 'package:drivio_driver/modules/commons/network/network_client.dart';
import 'package:drivio_driver/modules/commons/location/location_permission_service.dart';
import 'package:drivio_driver/modules/commons/data/demand_heatmap_repository.dart';
import 'package:drivio_driver/modules/commons/data/demand_heatmap_repository_impl.dart';
import 'package:drivio_driver/modules/commons/data/document_repository.dart';
import 'package:drivio_driver/modules/commons/data/document_repository_impl.dart';
import 'package:drivio_driver/modules/commons/data/driver_rating_repository.dart';
import 'package:drivio_driver/modules/commons/data/driver_rating_repository_impl.dart';
import 'package:drivio_driver/modules/commons/data/message_repository.dart';
import 'package:drivio_driver/modules/commons/data/message_repository_impl.dart';
import 'package:drivio_driver/modules/commons/data/notification_repository.dart';
import 'package:drivio_driver/modules/commons/data/notification_repository_impl.dart';
import 'package:drivio_driver/modules/commons/data/passenger_rating_repository.dart';
import 'package:drivio_driver/modules/commons/data/passenger_rating_repository_impl.dart';
import 'package:drivio_driver/modules/commons/data/payout_account_repository.dart';
import 'package:drivio_driver/modules/commons/data/payout_account_repository_impl.dart';
import 'package:drivio_driver/modules/commons/data/pricing_repository.dart';
import 'package:drivio_driver/modules/commons/data/pricing_repository_impl.dart';
import 'package:drivio_driver/modules/commons/data/profile_repository.dart';
import 'package:drivio_driver/modules/commons/data/profile_repository_impl.dart';
import 'package:drivio_driver/modules/commons/data/profile_summary_repository.dart';
import 'package:drivio_driver/modules/commons/data/profile_summary_repository_impl.dart';
import 'package:drivio_driver/modules/commons/data/presence_repository.dart';
import 'package:drivio_driver/modules/commons/data/presence_repository_impl.dart';
import 'package:drivio_driver/modules/commons/data/safety_repository.dart';
import 'package:drivio_driver/modules/commons/data/safety_repository_impl.dart';
import 'package:drivio_driver/modules/commons/data/ride_request_repository.dart';
import 'package:drivio_driver/modules/commons/data/ride_request_repository_impl.dart';
import 'package:drivio_driver/modules/commons/data/subscription_repository.dart';
import 'package:drivio_driver/modules/commons/data/subscription_repository_impl.dart';
import 'package:drivio_driver/modules/commons/data/trip_location_repository.dart';
import 'package:drivio_driver/modules/commons/data/trip_location_repository_impl.dart';
import 'package:drivio_driver/modules/commons/data/trip_repository.dart';
import 'package:drivio_driver/modules/commons/data/trip_repository_impl.dart';
import 'package:drivio_driver/modules/commons/data/trusted_contacts_repository.dart';
import 'package:drivio_driver/modules/commons/data/trusted_contacts_repository_impl.dart';
import 'package:drivio_driver/modules/commons/data/wallet_repository.dart';
import 'package:drivio_driver/modules/commons/data/wallet_repository_impl.dart';
import 'package:drivio_driver/modules/dash/features/add_vehicle/presentation/logic/data/vehicle_repository.dart';
import 'package:drivio_driver/modules/dash/features/add_vehicle/presentation/logic/data/vehicle_repository_impl.dart';
import 'package:drivio_driver/modules/kyc/features/kyc_home/presentation/logic/data/kyc_repository.dart';
import 'package:drivio_driver/modules/kyc/features/kyc_home/presentation/logic/data/kyc_repository_impl.dart';

final GetIt locator = GetIt.instance;

Future<void> setupServiceLocator(Flavor flavor) async {
  await dotenv.load();

  final Config config = Config(flavor);
  locator.registerSingleton<Config>(config);

  assert(
    config.supabaseUrl != 'YOUR_SUPABASE_URL',
    'SUPABASE_URL is not set. Update your .env file.',
  );
  assert(
    config.supabaseAnonKey != 'YOUR_SUPABASE_ANON_KEY',
    'SUPABASE_ANON_KEY is not set. Update your .env file.',
  );

  await Supabase.initialize(
    url: config.supabaseUrl,
    anonKey: config.supabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
      autoRefreshToken: true,
    ),
  );

  locator.registerSingleton<SupabaseModule>(SupabaseModule.fromInstance());

  locator.registerLazySingleton<VehicleRepository>(
    () => SupabaseVehicleRepository(locator<SupabaseModule>()),
  );

  locator.registerLazySingleton<DocumentRepository>(
    () => SupabaseDocumentRepository(locator<SupabaseModule>()),
  );

  locator.registerLazySingleton<KycRepository>(
    () => SupabaseKycRepository(locator<SupabaseModule>()),
  );

  locator.registerLazySingleton<SubscriptionRepository>(
    () => SupabaseSubscriptionRepository(locator<SupabaseModule>()),
  );

  locator.registerLazySingleton<PresenceRepository>(
    () => SupabasePresenceRepository(locator<SupabaseModule>()),
  );

  locator.registerLazySingleton<RideRequestRepository>(
    () => SupabaseRideRequestRepository(locator<SupabaseModule>()),
  );

  locator.registerLazySingleton<TripRepository>(
    () => SupabaseTripRepository(locator<SupabaseModule>()),
  );

  locator.registerLazySingleton<TripLocationRepository>(
    () => SupabaseTripLocationRepository(locator<SupabaseModule>()),
  );

  locator.registerLazySingleton<WalletRepository>(
    () => SupabaseWalletRepository(locator<SupabaseModule>()),
  );

  locator.registerLazySingleton<MessageRepository>(
    () => SupabaseMessageRepository(locator<SupabaseModule>()),
  );

  locator.registerLazySingleton<SafetyRepository>(
    () => SupabaseSafetyRepository(locator<SupabaseModule>()),
  );

  locator.registerLazySingleton<PassengerRatingRepository>(
    () => SupabasePassengerRatingRepository(locator<SupabaseModule>()),
  );

  locator.registerLazySingleton<NotificationRepository>(
    () => SupabaseNotificationRepository(locator<SupabaseModule>()),
  );

  locator.registerLazySingleton<ProfileRepository>(
    () => SupabaseProfileRepository(locator<SupabaseModule>()),
  );

  locator.registerLazySingleton<PricingRepository>(
    () => SupabasePricingRepository(locator<SupabaseModule>()),
  );

  locator.registerLazySingleton<TrustedContactsRepository>(
    () => SupabaseTrustedContactsRepository(locator<SupabaseModule>()),
  );

  locator.registerLazySingleton<DashboardRepository>(
    () => SupabaseDashboardRepository(locator<SupabaseModule>()),
  );

  locator.registerLazySingleton<DriverRatingRepository>(
    () => SupabaseDriverRatingRepository(locator<SupabaseModule>()),
  );

  locator.registerLazySingleton<CoachTipRepository>(
    () => SupabaseCoachTipRepository(locator<SupabaseModule>()),
  );

  locator.registerLazySingleton<DemandHeatmapRepository>(
    () => SupabaseDemandHeatmapRepository(locator<SupabaseModule>()),
  );

  locator.registerLazySingleton<ProfileSummaryRepository>(
    () => SupabaseProfileSummaryRepository(locator<SupabaseModule>()),
  );

  locator.registerLazySingleton<PayoutAccountRepository>(
    () => SupabasePayoutAccountRepository(locator<SupabaseModule>()),
  );

  locator.registerLazySingleton<DirectionsRepository>(
    () => SupabaseDirectionsRepository(NetworkClient()),
  );

  locator.registerLazySingleton<LocationPermissionService>(
    () => const LocationPermissionService(),
  );
}
