/// Mixpanel event names (Title Case) for the Driver app. Centralised to keep
/// names consistent and typo-free. See the Mixpanel tracking plan for the
/// full taxonomy, triggers, and properties.
abstract final class AnalyticsEvents {
  // ── Shared ──────────────────────────────────────────────────────────
  static const String appOpened = 'App Opened';
  static const String signIn = 'Sign In';
  static const String signOut = 'Sign Out';
  static const String pushPermissionResult = 'Push Permission Result';
  static const String notificationOpened = 'Notification Opened';
  static const String errorOccurred = 'Error Occurred';

  // ── Auth / onboarding ──────────────────────────────────────────────
  static const String driverSignupStarted = 'Driver Signup Started';
  static const String otpVerified = 'OTP Verified';
  static const String otpFailed = 'OTP Failed';
  static const String driverAccountCreated = 'Driver Account Created';

  // ── KYC ────────────────────────────────────────────────────────────
  static const String kycStarted = 'KYC Started';
  static const String documentUploaded = 'Document Uploaded';
  static const String vehicleAdded = 'Vehicle Added';
  static const String livenessCheckStarted = 'Liveness Check Started';
  static const String livenessCheckPassed = 'Liveness Check Passed';
  static const String livenessCheckFailed = 'Liveness Check Failed';
  static const String kycSubmitted = 'KYC Submitted';
  static const String kycStatusChanged = 'KYC Status Changed';

  // ── Subscription ───────────────────────────────────────────────────
  static const String subscriptionPlanViewed = 'Subscription Plan Viewed';
  static const String subscriptionPlanSelected = 'Subscription Plan Selected';
  static const String subscriptionPaymentInitiated =
      'Subscription Payment Initiated';
  static const String subscriptionPurchased = 'Subscription Purchased';
  static const String subscriptionPurchaseFailed =
      'Subscription Purchase Failed';
  static const String subscriptionActivated = 'Subscription Activated';
  static const String subscriptionRenewed = 'Subscription Renewed';
  static const String subscriptionExpired = 'Subscription Expired';

  // ── Presence / permissions ─────────────────────────────────────────
  static const String driverWentOnline = 'Driver Went Online';
  static const String driverWentOffline = 'Driver Went Offline';
  static const String backgroundLocationPermissionResult =
      'Background Location Permission Result';

  // ── Marketplace / bidding ──────────────────────────────────────────
  static const String rideRequestReceived = 'Ride Request Received';
  static const String bidComposerOpened = 'Bid Composer Opened';
  static const String driverOfferSubmitted = 'Driver Offer Submitted';
  static const String driverOfferAccepted = 'Driver Offer Accepted';
  static const String driverOfferExpired = 'Driver Offer Expired';
  static const String driverOfferRejected = 'Driver Offer Rejected';
  static const String pricingDefaultsUpdated = 'Pricing Defaults Updated';

  // ── Trip lifecycle ─────────────────────────────────────────────────
  static const String tripStarted = 'Trip Started';
  static const String tripCompleted = 'Trip Completed';
  static const String tripCancelled = 'Trip Cancelled';

  // ── Earnings / payout ──────────────────────────────────────────────
  static const String earningsViewed = 'Earnings Viewed';
  static const String withdrawalRequested = 'Withdrawal Requested';
  static const String withdrawalSucceeded = 'Withdrawal Succeeded';
  static const String withdrawalFailed = 'Withdrawal Failed';
}
