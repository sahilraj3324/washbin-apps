/// Mirrors `PartnerStatus` in the API: whether the account itself is in good
/// standing, independently of how far document checking has got.
///
/// A `suspended` partner is refused a token outright — `PartnerAuthService`
/// throws 403 — so the app usually learns about suspension at sign-in rather
/// than from a profile read. `inactive` is a partner who has stepped away;
/// they keep the app, they just do not get matched.
enum PartnerStatus {
  active,
  inactive,
  suspended;

  static PartnerStatus parse(Object? value) => switch (value) {
    'inactive' => PartnerStatus.inactive,
    'suspended' => PartnerStatus.suspended,
    _ => PartnerStatus.active,
  };
}

/// Where Washbin has got to in checking a partner's details.
///
/// Only `submitted` is something the partner causes, by asking for a review;
/// `verified` and `rejected` are Washbin's to set, which is why no partner-
/// facing route accepts this field.
enum VerificationStatus {
  /// Registered, not yet put forward for review.
  pending,

  /// Under review.
  submitted,

  verified,
  rejected;

  static VerificationStatus parse(Object? value) => switch (value) {
    'submitted' => VerificationStatus.submitted,
    'verified' => VerificationStatus.verified,
    'rejected' => VerificationStatus.rejected,
    _ => VerificationStatus.pending,
  };
}

/// How a partner describes themselves. Optional everywhere — a partner who
/// would rather not say is not blocked from working.
enum Gender {
  male,
  female,
  other,
  preferNotToSay;

  /// The API's spelling, which is snake_case.
  String get wireValue => switch (this) {
    Gender.preferNotToSay => 'prefer_not_to_say',
    _ => name,
  };

  String get label => switch (this) {
    Gender.male => 'Male',
    Gender.female => 'Female',
    Gender.other => 'Other',
    Gender.preferNotToSay => 'Prefer not to say',
  };

  static Gender? parse(Object? value) => switch (value) {
    'male' => Gender.male,
    'female' => Gender.female,
    'other' => Gender.other,
    'prefer_not_to_say' => Gender.preferNotToSay,
    _ => null,
  };
}

/// Where the partner is based. Not a service area — that is a later phase.
class PartnerAddress {
  const PartnerAddress({
    required this.line1,
    required this.city,
    required this.state,
    required this.pincode,
    this.line2,
  });

  static PartnerAddress? fromJson(Object? value) {
    if (value is! Map<String, dynamic>) {
      return null;
    }

    final line1 = (value['line1'] as String? ?? '').trim();
    if (line1.isEmpty) {
      return null;
    }

    return PartnerAddress(
      line1: line1,
      line2: _nonEmpty(value['line2']),
      city: (value['city'] as String? ?? '').trim(),
      state: (value['state'] as String? ?? '').trim(),
      pincode: (value['pincode'] as String? ?? '').trim(),
    );
  }

  final String line1;
  final String? line2;
  final String city;
  final String state;
  final String pincode;

  Map<String, dynamic> toJson() => {
    'line1': line1,
    if (line2 != null && line2!.isNotEmpty) 'line2': line2,
    'city': city,
    'state': state,
    'pincode': pincode,
  };

  /// One line, for showing back to the partner.
  String get summary =>
      [line1, ?line2, city, state, pincode].where((p) => p.isNotEmpty).join(', ');
}

/// Who Washbin calls if something happens on a job. Optional.
class EmergencyContact {
  const EmergencyContact({
    required this.name,
    required this.phone,
    this.relationship,
  });

  static EmergencyContact? fromJson(Object? value) {
    if (value is! Map<String, dynamic>) {
      return null;
    }

    final name = (value['name'] as String? ?? '').trim();
    final phone = (value['phone'] as String? ?? '').trim();
    if (name.isEmpty || phone.isEmpty) {
      return null;
    }

    return EmergencyContact(
      name: name,
      phone: phone,
      relationship: _nonEmpty(value['relationship']),
    );
  }

  final String name;
  final String phone;
  final String? relationship;

  Map<String, dynamic> toJson() => {
    'name': name,
    'phone': phone,
    if (relationship != null && relationship!.isNotEmpty)
      'relationship': relationship,
  };
}

/// What the app should *do* about a partner, collapsed from the backend's two
/// status fields into the one question the router asks.
///
/// The server keeps `status` and `verificationStatus` apart because they are
/// decided by different people at different times; the app only ever needs to
/// know which screen this partner belongs on. Deriving it in one place means a
/// new backend state is a change here and nowhere else.
///
/// Not to be confused with `SessionStatus.registrationRequired`, which is the
/// state *before* any of this: a verified number with no partner account at
/// all.
enum PartnerStage {
  /// Registered, but not yet put forward for review — the profile and the
  /// service list still need finishing. The brief's `profile_incomplete`.
  profileIncomplete,

  /// Submitted, waiting on Washbin. Nothing to do but wait.
  pendingApproval,

  /// Reviewed and refused. `Partner.rejectionReason` says why.
  rejected,

  /// The account is closed to the partner until Washbin reopens it.
  suspended,

  /// Cleared to work. The only stage that opens the app shell.
  approved;

  bool get opensApp => this == PartnerStage.approved;

  /// Whether this partner can still change their profile and services.
  ///
  /// A suspended partner cannot: nothing they edit would change the decision,
  /// and offering the form would suggest otherwise. A partner under review
  /// can — waiting is not a reason to lock someone out of a typo fix.
  bool get canEditOnboarding => this != PartnerStage.suspended;

  String get label => switch (this) {
    PartnerStage.profileIncomplete => 'Profile incomplete',
    PartnerStage.pendingApproval => 'Pending approval',
    PartnerStage.rejected => 'Profile rejected',
    PartnerStage.suspended => 'Account suspended',
    PartnerStage.approved => 'Verified partner',
  };
}

/// A Washbin partner, as the API describes them.
///
/// Phone is the account identity: it is verified by OTP and is the only thing
/// a partner signs in with. It is deliberately not editable in the app —
/// changing it would break the link between the Firebase account and this
/// record, so `PATCH /partners/me` does not accept it.
class Partner {
  const Partner({
    required this.id,
    required this.businessName,
    required this.ownerName,
    required this.phone,
    this.email,
    this.profileImage,
    this.gender,
    this.experienceYears,
    this.address,
    this.emergencyContact,
    this.status = PartnerStatus.active,
    this.verificationStatus = VerificationStatus.pending,
    this.rejectionReason,
    this.submittedAt,
    this.rating = 0,
  });

  /// Accepts both shapes the API produces: `id` from
  /// `POST /partner-auth/phone`, and Mongo's `_id` from `GET /partners/me`.
  factory Partner.fromJson(Map<String, dynamic> json) {
    final id = json['id'] ?? json['_id'];

    return Partner(
      id: id is String ? id : id.toString(),
      businessName: json['businessName'] as String? ?? '',
      ownerName: json['ownerName'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      email: _nonEmpty(json['email']),
      profileImage: _nonEmpty(json['profileImage']),
      gender: Gender.parse(json['gender']),
      experienceYears: (json['experienceYears'] as num?)?.toInt(),
      address: PartnerAddress.fromJson(json['address']),
      emergencyContact: EmergencyContact.fromJson(json['emergencyContact']),
      status: PartnerStatus.parse(json['status']),
      verificationStatus: VerificationStatus.parse(json['verificationStatus']),
      rejectionReason: _nonEmpty(json['rejectionReason']),
      submittedAt: DateTime.tryParse(json['submittedAt'] as String? ?? ''),
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
    );
  }

  final String id;
  final String businessName;
  final String ownerName;
  final String phone;
  final String? email;
  final String? profileImage;
  final Gender? gender;
  final int? experienceYears;
  final PartnerAddress? address;
  final EmergencyContact? emergencyContact;
  final PartnerStatus status;
  final VerificationStatus verificationStatus;

  /// Why the last review was refused. Cleared by the server on resubmission,
  /// so a reason on screen always describes the current state.
  final String? rejectionReason;

  final DateTime? submittedAt;
  final double rating;

  /// The one question the router asks. Suspension outranks everything: a
  /// suspended partner who happens to be verified is still suspended.
  ///
  /// `inactive` is not a gate — an inactive partner is simply not taking work
  /// and can still open the app to change that.
  PartnerStage get stage {
    if (status == PartnerStatus.suspended) {
      return PartnerStage.suspended;
    }

    return switch (verificationStatus) {
      VerificationStatus.verified => PartnerStage.approved,
      VerificationStatus.rejected => PartnerStage.rejected,
      VerificationStatus.submitted => PartnerStage.pendingApproval,
      VerificationStatus.pending => PartnerStage.profileIncomplete,
    };
  }

  /// The first name of the owner, for greetings.
  String get ownerGivenName => ownerName.trim().split(RegExp(r'\s+')).first;

  /// Applied after a successful `PATCH /partners/me` so the session reflects
  /// the edit without a second read.
  Partner copyWith({
    String? businessName,
    String? ownerName,
    String? email,
    String? profileImage,
    Gender? gender,
    int? experienceYears,
    PartnerAddress? address,
    EmergencyContact? emergencyContact,
  }) {
    return Partner(
      id: id,
      businessName: businessName ?? this.businessName,
      ownerName: ownerName ?? this.ownerName,
      phone: phone,
      email: email ?? this.email,
      profileImage: profileImage ?? this.profileImage,
      gender: gender ?? this.gender,
      experienceYears: experienceYears ?? this.experienceYears,
      address: address ?? this.address,
      emergencyContact: emergencyContact ?? this.emergencyContact,
      status: status,
      verificationStatus: verificationStatus,
      rejectionReason: rejectionReason,
      submittedAt: submittedAt,
      rating: rating,
    );
  }
}

String? _nonEmpty(Object? value) =>
    value is String && value.trim().isNotEmpty ? value.trim() : null;
