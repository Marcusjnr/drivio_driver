import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Translate any thrown error into a short, human-friendly sentence.
///
/// The rules:
///   1. Never expose database internals (SQLSTATE codes, table names,
///      column names, constraint names, full SQL, raw stack frames).
///   2. Map known Drivio backend codes (raised via RAISE EXCEPTION in
///      RPCs, returned as JSON `{code, message}` from edge functions)
///      to the exact copy product wants the driver to read.
///   3. Fall back to a generic, calm sentence — never to "Exception:
///      PostgrestException(message: …, …)".
///
/// Pass a `fallback` to give the user better context than the default
/// "Something went wrong. Please try again." (e.g. "Couldn't load
/// earnings.").
String humaniseError(Object? error, {String? fallback}) {
  final String generic = fallback ?? 'Something went wrong. Please try again.';
  if (error == null) return generic;

  if (error is String) {
    final String? mapped = _mapKnownCode(error);
    if (mapped != null) return mapped;
    return _looksUserSafe(error) ? error : generic;
  }

  if (error is SocketException) {
    return "You're offline. Check your connection and try again.";
  }
  if (error is TimeoutException || error is HttpException) {
    return 'The network took too long. Try again in a moment.';
  }

  if (error is PostgrestException) {
    return _humanisePostgrest(error, fallback: generic);
  }
  if (error is AuthException) {
    return _humaniseAuth(error, fallback: generic);
  }
  if (error is FunctionException) {
    return _humaniseFunction(error, fallback: generic);
  }
  if (error is StorageException) {
    return _humaniseStorage(error, fallback: generic);
  }

  // Drivio-internal exceptions usually carry `.code` and `.message`
  // fields. Try those reflectively before giving up.
  final String? fromMessage = _tryReadField(error, 'message');
  final String? fromCode = _tryReadField(error, 'code');
  if (fromCode != null) {
    final String? mapped = _mapKnownCode(fromCode);
    if (mapped != null) return mapped;
  }
  if (fromMessage != null) {
    final String? mapped = _mapKnownCode(fromMessage);
    if (mapped != null) return mapped;
    if (_looksUserSafe(fromMessage)) return fromMessage;
  }

  return generic;
}

String _humanisePostgrest(PostgrestException e, {required String fallback}) {
  // First: Postgres SQLSTATE codes that are universally meaningful.
  switch (e.code) {
    case '23505':
      return "That already exists. Try a different value.";
    case '23503':
      return "That's still in use somewhere — can't remove it yet.";
    case '23514':
      return "That doesn't meet the rules. Check the value and try again.";
    case '23502':
      return 'A required field is missing.';
    case '42501':
      return "You don't have permission to do that.";
    case 'PGRST116':
    case 'PGRST204':
      return "We couldn't find what you were looking for.";
    case 'PGRST301':
    case 'PGRST302':
      return 'Please sign in again.';
  }

  // Then: Drivio RPC raise codes — these come back as the .message
  // when an RPC does `RAISE EXCEPTION 'subscription_required'`.
  final String message = e.message;
  final String? mappedFromMessage = _mapKnownCode(message);
  if (mappedFromMessage != null) return mappedFromMessage;

  final String? mappedFromDetails = _mapKnownCode(e.details?.toString());
  if (mappedFromDetails != null) return mappedFromDetails;

  // Generic fingerprints in the message text.
  final String lower = message.toLowerCase();
  if (lower.contains('jwt') || lower.contains('not_authenticated')) {
    return 'Please sign in again.';
  }
  if (lower.contains('row level security') ||
      lower.contains('permission denied')) {
    return "You don't have permission to do that.";
  }
  if (lower.contains('connection') || lower.contains('network')) {
    return "You're offline. Check your connection and try again.";
  }
  if (lower.contains('timeout')) {
    return 'The network took too long. Try again in a moment.';
  }

  return fallback;
}

String _humaniseAuth(AuthException e, {required String fallback}) {
  final String lower = e.message.toLowerCase();

  if (lower.contains('invalid login') ||
      (lower.contains('invalid') && lower.contains('credentials'))) {
    return 'That phone or password didn\'t match. Try again.';
  }
  if (lower.contains('otp') && lower.contains('expired')) {
    return 'That code has expired. Tap resend to get a new one.';
  }
  if (lower.contains('otp') || lower.contains('token has expired')) {
    return "That code didn't work. Try again or tap resend.";
  }
  if (lower.contains('rate') && lower.contains('limit')) {
    return 'Too many attempts. Try again in a few minutes.';
  }
  if (lower.contains('user already') || lower.contains('already registered')) {
    return 'An account with these details already exists. Sign in instead.';
  }
  if (lower.contains('email_not_confirmed') ||
      lower.contains('email not confirmed')) {
    return 'Confirm your email first, then come back.';
  }
  if (lower.contains('user not found') || lower.contains('no user')) {
    return "We couldn't find that account. Sign up to get started.";
  }
  if (lower.contains('weak') && lower.contains('password')) {
    return 'Pick a stronger password — at least 8 characters.';
  }
  if (lower.contains('signup is disabled')) {
    return 'New sign-ups are paused right now. Try again later.';
  }
  if (lower.contains('confirmation') && lower.contains('required')) {
    return 'Please confirm your account first.';
  }

  if (e.statusCode == '401' || e.statusCode == '403') {
    return 'Please sign in again.';
  }

  return fallback;
}

String _humaniseFunction(FunctionException e, {required String fallback}) {
  // Edge functions return JSON like `{"code":"…","message":"…"}`
  // when they fail. Pull out both fields if we can.
  final Object? details = e.details;
  if (details is Map) {
    final String? code = details['code']?.toString();
    final String? message = details['message']?.toString();

    if (code != null) {
      final String? mapped = _mapKnownCode(code);
      if (mapped != null) return mapped;
    }
    if (message != null && message.isNotEmpty) {
      final String? mapped = _mapKnownCode(message);
      if (mapped != null) return mapped;
      if (_looksUserSafe(message)) return message;
    }
  }

  final int? status = e.status;
  if (status == 401 || status == 403) return 'Please sign in again.';
  if (status == 404) return "We couldn't find what you were looking for.";
  if (status == 408 || status == 504) {
    return 'The network took too long. Try again in a moment.';
  }
  if (status == 429) return 'Too many requests. Wait a moment and try again.';
  if (status == 503) return "That feature isn't available right now.";
  if (status != null && status >= 500) {
    return "We hit a snag on our side. Try again in a moment.";
  }

  return fallback;
}

String _humaniseStorage(StorageException e, {required String fallback}) {
  final String lower = e.message.toLowerCase();
  if (lower.contains('not found') || lower.contains('object not found')) {
    return "That file isn't available anymore.";
  }
  if (lower.contains('payload too large') || lower.contains('too large')) {
    return 'That file is too big. Try a smaller one.';
  }
  if (lower.contains('mime') || lower.contains('content type')) {
    return "That file type isn't supported. Try a different format.";
  }
  if (lower.contains('permission') || lower.contains('unauthorized')) {
    return "You don't have permission to do that.";
  }
  return fallback;
}

/// Drivio-specific backend codes. These strings are raised by the
/// Postgres RPCs (via `RAISE EXCEPTION '<code>'`) and by edge functions
/// (via `{ code: '<code>' }` JSON bodies). The right-hand sides are
/// the driver-facing copy.
const Map<String, String> _knownCodes = <String, String>{
  // Subscription / activity gate.
  'subscription_required':
      'Your subscription is paused. Renew it to keep accepting trips.',
  'subscription_expired':
      'Your subscription has expired. Renew to start driving again.',
  'kyc_required':
      'Finish verifying your account to continue.',
  'no_active_vehicle':
      'Add an approved vehicle before going online.',
  'driver_offline':
      "You're offline right now. Go online to receive requests.",

  // Marketplace / bidding races.
  'request_no_longer_open':
      'Another driver was picked for this trip.',
  'request_expired':
      'That request expired before you could bid.',
  'request_unavailable':
      'That request is no longer available.',
  'bid_unavailable':
      'That bid is no longer available.',
  'bid_already_accepted':
      'That bid was already taken.',
  'bid_withdrawn':
      'That bid was withdrawn.',
  'duplicate_bid':
      "You've already bid on this trip.",
  'price_out_of_range':
      'That price is outside the allowed range. Adjust and try again.',
  'price_too_high':
      'That price is too high. Lower it and try again.',
  'price_too_low':
      'That price is too low. Raise it and try again.',

  // Trip lifecycle.
  'trip_in_progress':
      "You're already on a trip. Finish it first.",
  'active_trip_in_progress':
      'Finish your current trip before doing that.',
  'trip_already_completed':
      'That trip is already finished.',
  'trip_already_cancelled':
      'That trip was already cancelled.',
  'invalid_trip_state':
      "Can't do that at this stage of the trip.",
  'invalid_transition':
      "Can't do that at this stage of the trip.",
  'not_your_trip':
      "You can't update someone else's trip.",
  'trip_not_found':
      'That trip no longer exists.',
  'too_far_from_pickup':
      "You're not close enough to the pickup yet.",
  'no_location_fix':
      'Need a GPS fix first. Wait a few seconds and try again.',
  'pickup_required':
      'Set a pickup location first.',
  'dropoff_required':
      'Choose where you\'re going.',
  'service_area':
      "We don't serve that area yet.",
  'distance_too_short':
      "That's too close. Trip distance is too short.",
  'distance_too_long':
      "That's too far. Trip distance is over the limit.",
  'concurrent_request':
      'You already have a ride request in progress.',

  // Wallet / payments.
  'insufficient_balance':
      'Your wallet balance is too low. Top up to continue.',
  'insufficient_funds':
      'Your wallet balance is too low. Top up to continue.',
  'topup_failed':
      "That top-up didn't go through. Try again.",
  'topup_pending':
      "That top-up is still processing. We'll update your balance shortly.",
  'topup_amount_too_low':
      "That amount is below the minimum. Try a bit more.",
  'topup_amount_too_high':
      "That amount is over the maximum. Try a smaller value.",
  'payout_failed':
      "We couldn't send that payout. Try again or contact support.",
  'no_payout_account':
      "Add your bank account before requesting a payout.",
  'invalid_account_number':
      'That account number is not valid.',
  'invalid_bank':
      "We couldn't recognise that bank.",

  // Auth / identity.
  'not_authenticated':
      'Please sign in again.',
  'phone_in_use':
      'That phone number is already linked to another account.',
  'invalid_phone':
      'That phone number doesn\'t look right. Check and try again.',
  'invalid_otp':
      "That code didn't work. Try again or tap resend.",
  'otp_expired':
      'That code has expired. Tap resend to get a new one.',
  'rate_limited':
      'Too many requests. Wait a moment and try again.',

  // KYC / docs.
  'document_rejected':
      'That document was rejected. Check the notes and re-upload.',
  'document_expired':
      'That document has expired. Upload a current one.',
  'document_invalid':
      "That document didn't pass our checks. Try uploading again.",
  'bvn_mismatch':
      "Your BVN didn't match. Double-check the details.",
  'nin_mismatch':
      "Your NIN didn't match. Double-check the details.",
  'liveness_failed':
      'That selfie check failed. Try again in good lighting.',

  // Vehicle.
  'vehicle_not_approved':
      'Your vehicle is still under review. Hang tight.',
  'vehicle_already_exists':
      'That vehicle is already on your account.',
  'plate_in_use':
      'That plate number is already registered to another driver.',

  // Generic edge-function codes.
  'config': "That feature isn't available right now.",
  'upstream': "An external service had a glitch. Try again.",
  'upstream_timeout': 'The network took too long. Try again in a moment.',
  'bad_request': "Something about that request wasn't valid.",
  'forbidden': "You don't have permission to do that.",
  'unauthenticated': 'Please sign in again.',
  'not_found': "We couldn't find what you were looking for.",
  'conflict': 'That conflicts with something else. Refresh and try again.',
  'server_error': "We hit a snag on our side. Try again in a moment.",
};

String? _mapKnownCode(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  // Keep the body of the message; trim whitespace and casing.
  final String key = raw.trim().toLowerCase();
  // Direct hit.
  final String? direct = _knownCodes[key];
  if (direct != null) return direct;
  // Some servers return things like "ERROR: subscription_required" —
  // peel the obvious prefix and try once more.
  for (final String prefix in const <String>[
    'error: ',
    'exception: ',
    'failed: ',
  ]) {
    if (key.startsWith(prefix)) {
      final String rest = key.substring(prefix.length);
      final String? hit = _knownCodes[rest];
      if (hit != null) return hit;
    }
  }
  return null;
}

/// A message is "user-safe" if it is short, doesn't contain stack
/// frames, doesn't contain SQL, and doesn't look like a class name
/// dump. We err on the side of NOT showing custom strings unless we
/// recognise the shape.
bool _looksUserSafe(String message) {
  if (message.isEmpty) return false;
  if (message.length > 200) return false;
  final String lower = message.toLowerCase();
  const List<String> reject = <String>[
    'exception',
    'stacktrace',
    'stack trace',
    'null check',
    'type \'',
    'no element',
    'sqlstate',
    'pgrst',
    'postgrest',
    'syntax error',
    'duplicate key value',
    'violates ',
    'relation "',
    'column "',
    'function ',
    '#0 ',
  ];
  for (final String marker in reject) {
    if (lower.contains(marker)) return false;
  }
  return true;
}

String? _tryReadField(Object error, String field) {
  try {
    final dynamic value = (error as dynamic);
    final dynamic raw = field == 'message' ? value.message : value.code;
    if (raw is String) return raw;
  } catch (_) {
    // The object doesn't expose that field; fine.
  }
  return null;
}
