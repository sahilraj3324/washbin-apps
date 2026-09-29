import 'package:washbinpartner/features/partner/domain/partner.dart';

/// One thing a partner must supply before Washbin will review them.
enum ProfileRequirement {
  email,
  experienceYears,
  address;

  String get label => switch (this) {
    ProfileRequirement.email => 'Email address',
    ProfileRequirement.experienceYears => 'Years of experience',
    ProfileRequirement.address => 'Where you are based',
  };

  bool isSatisfiedBy(Partner partner) => switch (this) {
    ProfileRequirement.email => (partner.email ?? '').trim().isNotEmpty,
    // Zero years is a complete answer, so only absence counts.
    ProfileRequirement.experienceYears => partner.experienceYears != null,
    ProfileRequirement.address => partner.address != null,
  };
}

/// How far a partner's profile is from being reviewable.
///
/// **This mirrors `REQUIRED_PROFILE_FIELDS` in
/// `api/src/partners/partners.service.ts` and must stay in step with it.**
/// The server is the authority — `POST /partners/me/submit-for-review` refuses
/// an incomplete profile whatever this says. This copy exists so the partner
/// can see what is outstanding while they fill the form in, rather than
/// finding out from a rejected submit.
///
/// Business name, owner name and phone are not requirements: the account
/// cannot exist without them, because registration collects all three.
class ProfileCompleteness {
  const ProfileCompleteness._(this.missing);

  factory ProfileCompleteness.of(Partner partner) {
    return ProfileCompleteness._(
      ProfileRequirement.values
          .where((requirement) => !requirement.isSatisfiedBy(partner))
          .toList(growable: false),
    );
  }

  final List<ProfileRequirement> missing;

  bool get isComplete => missing.isEmpty;

  int get satisfiedCount => ProfileRequirement.values.length - missing.length;

  int get totalCount => ProfileRequirement.values.length;

  /// 0.0 to 1.0, for a progress bar.
  double get fraction => satisfiedCount / totalCount;
}
