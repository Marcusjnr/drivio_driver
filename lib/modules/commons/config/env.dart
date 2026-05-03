import 'package:flutter_dotenv/flutter_dotenv.dart';

abstract final class Env {
  static String get supabaseUrl => dotenv.get('SUPABASE_URL');
  static String get supabaseAnonKey => dotenv.get('SUPABASE_ANON_KEY');
  static String get sentryDsn => dotenv.get('SENTRY_DSN', fallback: '');
  static String get posthogKey => dotenv.get('POSTHOG_KEY', fallback: '');
  static String get paystackPublicKey =>
      dotenv.get('PAYSTACK_PUBLIC_KEY', fallback: '');

  /// Paystack secret key. The `pay_with_paystack` plugin requires this on
  /// device. When this is empty or starts with `sk_test_DUMMY`, the
  /// activation flow short-circuits to a dev-mode SQL RPC and skips the
  /// real Paystack call. Replace with a real key (`sk_test_…` / `sk_live_…`)
  /// when ready to take real payments.
  static String get paystackSecretKey =>
      dotenv.get('PAYSTACK_SECRET_KEY', fallback: 'sk_test_DUMMY_REPLACE_ME');

  static bool get hasRealPaystackKey {
    final String k = paystackSecretKey;
    return k.isNotEmpty &&
        !k.startsWith('sk_test_DUMMY') &&
        (k.startsWith('sk_test_') || k.startsWith('sk_live_'));
  }
}
