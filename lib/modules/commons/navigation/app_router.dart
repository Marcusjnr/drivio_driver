import 'package:flutter/material.dart';

import 'package:drivio_driver/modules/authentication/features/otp/presentation/ui/otp_page.dart';
import 'package:drivio_driver/modules/authentication/features/sign_in/presentation/ui/sign_in_page.dart';
import 'package:drivio_driver/modules/authentication/features/sign_up/presentation/ui/sign_up_page.dart';
import 'package:drivio_driver/modules/authentication/features/welcome/presentation/ui/welcome_page.dart';
import 'package:drivio_driver/modules/commons/navigation/app_routes.dart';
import 'package:drivio_driver/modules/dash/features/add_vehicle/presentation/ui/add_vehicle_page.dart';
import 'package:drivio_driver/modules/dash/features/drive_shell/presentation/ui/drive_shell_page.dart';
import 'package:drivio_driver/modules/dash/features/earnings/presentation/ui/earnings_page.dart';
import 'package:drivio_driver/modules/dash/features/pricing/presentation/ui/pricing_page.dart';
import 'package:drivio_driver/modules/dash/features/profile_hub/presentation/ui/profile_hub_page.dart';
import 'package:drivio_driver/modules/documents/features/reupload/presentation/ui/reupload_doc_page.dart';
import 'package:drivio_driver/modules/edge_states/features/no_requests/presentation/ui/edge_no_requests_page.dart';
import 'package:drivio_driver/modules/edge_states/features/offline/presentation/ui/edge_offline_page.dart';
import 'package:drivio_driver/modules/edge_states/features/rider_cancelled/presentation/ui/edge_rider_cancelled_page.dart';
import 'package:drivio_driver/modules/edge_states/features/subscription_expired/presentation/ui/edge_subscription_expired_page.dart';
import 'package:drivio_driver/modules/kyc/features/bvn_nin/presentation/ui/bvn_nin_page.dart';
import 'package:drivio_driver/modules/kyc/features/document_capture/presentation/ui/document_capture_page.dart';
import 'package:drivio_driver/modules/kyc/features/kyc_home/presentation/ui/kyc_home_page.dart';
import 'package:drivio_driver/modules/kyc/features/selfie/presentation/ui/selfie_page.dart';
import 'package:drivio_driver/modules/profile/features/appearance/presentation/ui/appearance_page.dart';
import 'package:drivio_driver/modules/profile/features/help/presentation/ui/help_page.dart';
import 'package:drivio_driver/modules/profile/features/notifications_inbox/presentation/ui/notifications_inbox_page.dart';
import 'package:drivio_driver/modules/profile/features/profile_edit/presentation/ui/profile_edit_page.dart';
import 'package:drivio_driver/modules/profile/features/payment_methods/presentation/ui/payment_methods_page.dart';
import 'package:drivio_driver/modules/profile/features/referral/presentation/ui/referral_page.dart';
import 'package:drivio_driver/modules/profile/features/reviews/presentation/ui/reviews_page.dart';
import 'package:drivio_driver/modules/profile/features/sign_out/presentation/ui/sign_out_page.dart';
import 'package:drivio_driver/modules/profile/features/vehicle_details/presentation/ui/vehicle_details_page.dart';
import 'package:drivio_driver/modules/splash/presentation/ui/splash_page.dart';
import 'package:drivio_driver/modules/subscription/features/manage/presentation/ui/subscription_manage_page.dart';
import 'package:drivio_driver/modules/subscription/features/paywall/presentation/ui/paywall_page.dart';
import 'package:drivio_driver/modules/support/features/help_article/presentation/ui/help_article_page.dart';
import 'package:drivio_driver/modules/support/features/support_chat/presentation/ui/support_chat_page.dart';
import 'package:drivio_driver/modules/trip/features/call/presentation/ui/call_page.dart';
import 'package:drivio_driver/modules/trip/features/chat/presentation/ui/chat_page.dart';
import 'package:drivio_driver/modules/trip/features/safety/presentation/ui/safety_page.dart';
import 'package:drivio_driver/modules/vehicle/features/preferred_trip_length/presentation/ui/preferred_trip_length_page.dart';
import 'package:drivio_driver/modules/vehicle/features/vehicle_change/presentation/ui/vehicle_change_page.dart';

class AppRouter {
  AppRouter._();

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final WidgetBuilder builder = _builderFor(settings.name ?? AppRoutes.welcome);
    return MaterialPageRoute<dynamic>(
      builder: builder,
      settings: settings,
    );
  }

  static WidgetBuilder _builderFor(String name) {
    switch (name) {
      case AppRoutes.splash:
        return (BuildContext _) => const SplashPage();
      case AppRoutes.welcome:
        return (BuildContext _) => const WelcomePage();
      case AppRoutes.signIn:
        return (BuildContext _) => const SignInPage();
      case AppRoutes.signUp:
        return (BuildContext _) => const SignUpPage();
      case AppRoutes.otp:
        return (BuildContext _) => const OtpPage();
      case AppRoutes.paywall:
        return (BuildContext _) => const PaywallPage();
      case AppRoutes.kycHome:
        return (BuildContext _) => const KycHomePage();
      case AppRoutes.kycBvnNin:
        return (BuildContext _) => const BvnNinPage();
      case AppRoutes.kycSelfie:
        return (BuildContext _) => const SelfiePage();
      case AppRoutes.kycDocumentCapture:
        return (BuildContext _) => const DocumentCapturePage();
      case AppRoutes.home:
      case AppRoutes.activeTrip:
      case AppRoutes.rideRequest:
        // All three routes resolve to the shared driving canvas. The shell
        // reads the route arguments (trip id for activeTrip, request id
        // for rideRequest) and switches its own mode.
        return (BuildContext _) => const DriveShellPage();
      case AppRoutes.addVehicle:
        return (BuildContext _) => const AddVehiclePage();
      case AppRoutes.earnings:
        return (BuildContext _) => const EarningsPage();
      case AppRoutes.pricing:
        return (BuildContext _) => const PricingPage();
      case AppRoutes.subscriptionManage:
        return (BuildContext _) => const SubscriptionManagePage();
      case AppRoutes.profileHub:
        return (BuildContext _) => const ProfileHubPage();
      // (rideRequest + activeTrip handled in the shared block above)
      case AppRoutes.chat:
        return (BuildContext _) => const ChatPage();
      case AppRoutes.call:
        return (BuildContext _) => const CallPage();
      case AppRoutes.safety:
        return (BuildContext _) => const SafetyPage();
      case AppRoutes.vehicleDetails:
        return (BuildContext _) => const VehicleDetailsPage();
      case AppRoutes.reviews:
        return (BuildContext _) => const ReviewsPage();
      case AppRoutes.paymentMethods:
        return (BuildContext _) => const PaymentMethodsPage();
      case AppRoutes.referral:
        return (BuildContext _) => const ReferralPage();
      case AppRoutes.notificationsInbox:
        return (BuildContext _) => const NotificationsInboxPage();
      case AppRoutes.profileEdit:
        return (BuildContext _) => const ProfileEditPage();
      case AppRoutes.help:
        return (BuildContext _) => const HelpPage();
      case AppRoutes.appearance:
        return (BuildContext _) => const AppearancePage();
      case AppRoutes.signOut:
        return (BuildContext _) => const SignOutPage();
      case AppRoutes.reuploadDoc:
        return (BuildContext _) => const ReuploadDocPage();
      case AppRoutes.vehicleChange:
        return (BuildContext _) => const VehicleChangePage();
      case AppRoutes.preferredTripLength:
        return (BuildContext _) => const PreferredTripLengthPage();
      case AppRoutes.helpArticle:
        return (BuildContext _) => const HelpArticlePage();
      case AppRoutes.supportChat:
        return (BuildContext _) => const SupportChatPage();
      case AppRoutes.edgeNoRequests:
        return (BuildContext _) => const EdgeNoRequestsPage();
      case AppRoutes.edgeOffline:
        return (BuildContext _) => const EdgeOfflinePage();
      case AppRoutes.edgeSubExpired:
        return (BuildContext _) => const EdgeSubscriptionExpiredPage();
      case AppRoutes.edgeRiderCancelled:
        return (BuildContext _) => const EdgeRiderCancelledPage();
      default:
        return (BuildContext _) => const WelcomePage();
    }
  }
}
