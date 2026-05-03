class Profile {
  const Profile({
    required this.userId,
    required this.fullName,
    this.phoneE164,
    this.email,
    this.dob,
    this.gender,
    this.avatarUrl,
    this.referralCode,
    this.referredBy,
  });

  final String userId;
  final String fullName;
  final String? phoneE164;
  final String? email;
  final DateTime? dob;
  final String? gender;
  final String? avatarUrl;
  final String? referralCode;
  final String? referredBy;

  Profile copyWith({
    String? fullName,
    String? phoneE164,
    String? email,
    DateTime? dob,
    String? gender,
    String? avatarUrl,
  }) {
    return Profile(
      userId: userId,
      fullName: fullName ?? this.fullName,
      phoneE164: phoneE164 ?? this.phoneE164,
      email: email ?? this.email,
      dob: dob ?? this.dob,
      gender: gender ?? this.gender,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      referralCode: referralCode,
      referredBy: referredBy,
    );
  }

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      userId: json['user_id'] as String,
      fullName: json['full_name'] as String,
      phoneE164: json['phone_e164'] as String?,
      email: json['email'] as String?,
      dob: json['dob'] == null ? null : DateTime.parse(json['dob'] as String),
      gender: json['gender'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      referralCode: json['referral_code'] as String?,
      referredBy: json['referred_by'] as String?,
    );
  }
}
