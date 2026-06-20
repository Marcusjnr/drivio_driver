import 'package:flutter/material.dart';

/// Maps a driver-amenity code to a Material icon. Labels come from the
/// `amenity_catalog` row; only the icon is resolved client-side.
IconData amenityIcon(String code) {
  switch (code) {
    case 'ac':
      return Icons.ac_unit;
    case 'phone_charger':
      return Icons.power_outlined;
    case 'phone_holder':
      return Icons.phone_android_outlined;
    case 'bottled_water':
      return Icons.local_drink_outlined;
    case 'sweets':
      return Icons.cake_outlined;
    case 'child_seat':
      return Icons.child_friendly_outlined;
    case 'quiet_ride':
      return Icons.volume_off_outlined;
    case 'luggage_space':
      return Icons.luggage_outlined;
    case 'music_on_request':
      return Icons.music_note_outlined;
    case 'pos_card':
      return Icons.credit_card_outlined;
    case 'umbrella':
      return Icons.umbrella_outlined;
    case 'extra_legroom':
      return Icons.airline_seat_legroom_extra;
    default:
      return Icons.check_circle_outline;
  }
}
