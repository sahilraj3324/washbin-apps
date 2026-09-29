import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:washbinpartner/app/app_services_scope.dart';
import 'package:washbinpartner/core/api/api_exception.dart';
import 'package:washbinpartner/core/session/session_scope.dart';
import 'package:washbinpartner/core/theme/app_theme.dart';
import 'package:washbinpartner/features/auth/data/phone_number_input.dart';
import 'package:washbinpartner/features/auth/widgets/auth_error_text.dart';
import 'package:washbinpartner/features/auth/widgets/auth_text_field.dart';
import 'package:washbinpartner/features/partner/domain/partner.dart';

/// The partner's own details.
///
/// Everything here goes to `PATCH /partners/me` in one write. Phone is shown
/// but not editable: it is the account identity, verified by OTP, and the
/// server does not accept a change to it.
class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key, required this.partner});

  final Partner partner;

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();

  late final _businessName = TextEditingController(
    text: widget.partner.businessName,
  );
  late final _ownerName = TextEditingController(text: widget.partner.ownerName);
  late final _email = TextEditingController(text: widget.partner.email ?? '');
  late final _experience = TextEditingController(
    text: widget.partner.experienceYears?.toString() ?? '',
  );
  late final _line1 = TextEditingController(
    text: widget.partner.address?.line1 ?? '',
  );
  late final _line2 = TextEditingController(
    text: widget.partner.address?.line2 ?? '',
  );
  late final _city = TextEditingController(
    text: widget.partner.address?.city ?? '',
  );
  late final _state = TextEditingController(
    text: widget.partner.address?.state ?? '',
  );
  late final _pincode = TextEditingController(
    text: widget.partner.address?.pincode ?? '',
  );
  late final _contactName = TextEditingController(
    text: widget.partner.emergencyContact?.name ?? '',
  );
  late final _contactPhone = TextEditingController(
    text: widget.partner.emergencyContact?.phone ?? '',
  );

  late Gender? _gender = widget.partner.gender;

  bool _isSaving = false;
  String? _errorMessage;

  @override
  void dispose() {
    for (final controller in [
      _businessName,
      _ownerName,
      _email,
      _experience,
      _line1,
      _line2,
      _city,
      _state,
      _pincode,
      _contactName,
      _contactPhone,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final repository = AppServicesScope.of(context).partners;
    final session = SessionScope.read(context);
    final navigator = Navigator.of(context);

    try {
      final updated = await repository.updateMe(
        businessName: _businessName.text,
        ownerName: _ownerName.text,
        email: _email.text,
        gender: _gender,
        experienceYears: int.tryParse(_experience.text.trim()),
        address: _address(),
        emergencyContact: _emergencyContact(),
      );

      // The router reads the session, so a profile that has just become
      // complete unlocks the submit button without a round trip.
      session.applyPartner(updated);
      navigator.pop(true);
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _errorMessage = error.message);
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  /// Null when the partner has not filled the address in at all, so a blank
  /// form does not send an empty address the server would reject.
  PartnerAddress? _address() {
    if (_line1.text.trim().isEmpty) {
      return null;
    }

    return PartnerAddress(
      line1: _line1.text.trim(),
      line2: _line2.text.trim().isEmpty ? null : _line2.text.trim(),
      city: _city.text.trim(),
      state: _state.text.trim(),
      pincode: _pincode.text.trim(),
    );
  }

  EmergencyContact? _emergencyContact() {
    final name = _contactName.text.trim();
    final phone = _contactPhone.text.trim();

    if (name.isEmpty || phone.isEmpty) {
      return null;
    }
    return EmergencyContact(name: name, phone: phone);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.canvas,
      appBar: AppBar(
        title: const Text('Edit profile'),
        backgroundColor: AppTheme.canvas,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              const _SectionHeading(
                title: 'Your business',
                subtitle: 'What customers see when you are assigned a job.',
              ),
              AuthTextField(
                controller: _businessName,
                label: 'Business name',
                icon: Icons.store_mall_directory_outlined,
                enabled: !_isSaving,
                validator: (value) => _required(value, 'business name'),
              ),
              const SizedBox(height: 14),
              AuthTextField(
                controller: _ownerName,
                label: 'Owner full name',
                icon: Icons.person_outline_rounded,
                enabled: !_isSaving,
                validator: (value) => _required(value, 'own name'),
              ),
              const SizedBox(height: 14),
              _PhoneField(phone: widget.partner.phone),
              const SizedBox(height: 14),
              AuthTextField(
                controller: _email,
                label: 'Email address',
                icon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
                enabled: !_isSaving,
                validator: _validateEmail,
              ),
              const SizedBox(height: 26),
              const _SectionHeading(
                title: 'About you',
                subtitle: 'Helps Washbin match you to the right work.',
              ),
              AuthTextField(
                controller: _experience,
                label: 'Years of experience',
                icon: Icons.workspace_premium_outlined,
                keyboardType: TextInputType.number,
                enabled: !_isSaving,
                validator: _validateExperience,
              ),
              const SizedBox(height: 14),
              _GenderField(
                value: _gender,
                enabled: !_isSaving,
                onChanged: (value) => setState(() => _gender = value),
              ),
              const SizedBox(height: 26),
              const _SectionHeading(
                title: 'Where you are based',
                subtitle: 'Your own address, not the area you cover.',
              ),
              AuthTextField(
                controller: _line1,
                label: 'Address line 1',
                icon: Icons.home_outlined,
                enabled: !_isSaving,
                validator: (value) => _required(value, 'address'),
              ),
              const SizedBox(height: 14),
              AuthTextField(
                controller: _line2,
                label: 'Landmark (optional)',
                icon: Icons.signpost_outlined,
                enabled: !_isSaving,
              ),
              const SizedBox(height: 14),
              AuthTextField(
                controller: _city,
                label: 'City',
                icon: Icons.location_city_outlined,
                enabled: !_isSaving,
                validator: (value) => _required(value, 'city'),
              ),
              const SizedBox(height: 14),
              AuthTextField(
                controller: _state,
                label: 'State',
                icon: Icons.map_outlined,
                enabled: !_isSaving,
                validator: (value) => _required(value, 'state'),
              ),
              const SizedBox(height: 14),
              AuthTextField(
                controller: _pincode,
                label: 'Pincode',
                icon: Icons.markunread_mailbox_outlined,
                keyboardType: TextInputType.number,
                enabled: !_isSaving,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                validator: _validatePincode,
              ),
              const SizedBox(height: 26),
              const _SectionHeading(
                title: 'Emergency contact',
                subtitle: 'Optional. Who Washbin calls if something happens '
                    'while you are on a job.',
              ),
              AuthTextField(
                controller: _contactName,
                label: 'Contact name (optional)',
                icon: Icons.contact_emergency_outlined,
                enabled: !_isSaving,
              ),
              const SizedBox(height: 14),
              AuthTextField(
                controller: _contactPhone,
                label: 'Contact number (optional)',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                enabled: !_isSaving,
                textInputAction: TextInputAction.done,
                validator: _validateContactPhone,
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 18),
                AuthErrorText(message: _errorMessage!),
              ],
              const SizedBox(height: 26),
              FilledButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_rounded),
                label: Text(_isSaving ? 'Saving...' : 'Save profile'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _required(String? value, String label) =>
      (value?.trim() ?? '').length < 2 ? 'Enter your $label' : null;

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';

    if (email.isEmpty) {
      return 'Enter your email address';
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return 'Enter a valid email address';
    }
    return null;
  }

  String? _validateExperience(String? value) {
    final text = value?.trim() ?? '';

    if (text.isEmpty) {
      return 'Enter your years of experience';
    }

    final years = int.tryParse(text);
    if (years == null) {
      return 'Enter a whole number of years';
    }
    // Matches the server's bounds, so a rejection never comes as a surprise.
    if (years < 0 || years > 70) {
      return 'Enter between 0 and 70 years';
    }
    return null;
  }

  String? _validatePincode(String? value) {
    final pincode = value?.trim() ?? '';

    if (pincode.isEmpty) {
      return 'Enter your pincode';
    }
    if (!RegExp(r'^[1-9][0-9]{5}$').hasMatch(pincode)) {
      return 'Enter a valid 6-digit pincode';
    }
    return null;
  }

  /// The contact is optional, but half of one is not usable — a name with no
  /// number cannot be called.
  String? _validateContactPhone(String? value) {
    final phone = value?.trim() ?? '';
    final name = _contactName.text.trim();

    if (name.isEmpty && phone.isEmpty) {
      return null;
    }
    if (phone.isEmpty) {
      return 'Add a number, or clear the contact name';
    }
    if (phone.replaceAll(RegExp(r'\D'), '').length < 10) {
      return 'Enter a valid contact number';
    }
    return null;
  }
}

class _PhoneField extends StatelessWidget {
  const _PhoneField({required this.phone});

  final String phone;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: 'Mobile number',
        prefixIcon: const Icon(Icons.phone_rounded),
        // Says why it cannot be typed in, rather than looking broken.
        helperText: 'Verified by OTP. Contact support to change it.',
        helperStyle: const TextStyle(
          color: AppTheme.muted,
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
        ),
        filled: true,
        fillColor: AppTheme.canvas,
      ),
      child: Text(
        formatForDisplay(phone),
        style: const TextStyle(
          color: AppTheme.muted,
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _GenderField extends StatelessWidget {
  const _GenderField({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final Gender? value;
  final bool enabled;
  final ValueChanged<Gender?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<Gender>(
      initialValue: value,
      onChanged: enabled ? onChanged : null,
      decoration: const InputDecoration(
        labelText: 'Gender (optional)',
        prefixIcon: Icon(Icons.badge_outlined),
      ),
      items: [
        for (final gender in Gender.values)
          DropdownMenuItem(value: gender, child: Text(gender.label)),
      ],
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppTheme.ink,
              fontSize: 17,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              color: AppTheme.muted,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
