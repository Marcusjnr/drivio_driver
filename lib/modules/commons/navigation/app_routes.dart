class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String welcome = '/welcome';
  static const String signIn = '/sign-in';
  static const String signUp = '/sign-up';
  static const String otp = '/otp';
  static const String paywall = '/paywall';

  static const String kycHome = '/kyc';
  static const String kycBvnNin = '/kyc/bvn-nin';
  static const String kycSelfie = '/kyc/selfie';
  static const String kycDocumentCapture = '/kyc/document';

  static const String home = '/home';
  static const String addVehicle = '/add-vehicle';
  static const String earnings = '/earnings';
  static const String pricing = '/pricing';
  static const String subscriptionManage = '/subscription/manage';
  static const String profileHub = '/profile';

  static const String rideRequest = '/ride-request';
  static const String activeTrip = '/active-trip';
  static const String chat = '/chat';
  static const String call = '/call';
  static const String safety = '/safety';

  static const String vehicleDetails = '/profile/vehicle';
  // Insurance / inspection / per-document detail pages collapsed into
  // the existing KYC document-capture flow (Q3) — those routes are
  // gone; tapping a document on the profile hub uses
  // `kycDocumentCapture` with the right DocumentKind argument.
  static const String reviews = '/profile/reviews';
  static const String paymentMethods = '/profile/payment-methods';
  static const String referral = '/profile/referral';
  // notifications preferences page removed (Q4/Q7) until prefs have a
  // server-side store. The bell inbox at /notifications still exists.
  static const String notificationsInbox = '/notifications';
  static const String profileEdit = '/profile/edit';
  static const String help = '/profile/help';
  static const String signOut = '/profile/sign-out';

  // addCard route removed (Q2) — we no longer let drivers store
  // cards. Subscription billing runs through Paystack-managed cards
  // via the paywall, not stored on our side.
  static const String reuploadDoc = '/documents/reupload';
  static const String vehicleChange = '/vehicle/change';
  static const String pickupDistance = '/pricing/pickup-distance';
  static const String preferredTripLength = '/pricing/preferred-trip-length';
  static const String helpArticle = '/support/article';
  static const String supportChat = '/support/chat';

  static const String edgeNoRequests = '/edge/no-requests';
  static const String edgeOffline = '/edge/offline';
  static const String edgeSubExpired = '/edge/subscription-expired';
  static const String edgeRiderCancelled = '/edge/rider-cancelled';
}
