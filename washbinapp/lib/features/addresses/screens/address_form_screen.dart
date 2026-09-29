import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:washbinapp/app/app_services_scope.dart';
import 'package:washbinapp/core/api/api_exception.dart';
import 'package:washbinapp/core/theme/app_theme.dart';
import 'package:washbinapp/features/addresses/data/location_service.dart';
import 'package:washbinapp/features/addresses/domain/address.dart';
import 'package:washbinapp/features/addresses/domain/coordinates.dart';
import 'package:washbinapp/features/addresses/widgets/label_selector.dart';
import 'package:washbinapp/features/auth/widgets/auth_error_text.dart';

/// Adds a new address or edits an existing one.
///
/// Coordinates are the part a customer cannot type, so the screen insists on
/// having them: either carried in from "use my current location", or fetched
/// here. Everything else is text they can correct.
class AddressFormScreen extends StatefulWidget {
  const AddressFormScreen({super.key, this.existing, this.initialPoint});

  /// Null when adding.
  final Address? existing;

  /// A fix already obtained elsewhere, so the customer is not asked twice.
  final Coordinates? initialPoint;

  @override
  State<AddressFormScreen> createState() => _AddressFormScreenState();
}

class _AddressFormScreenState extends State<AddressFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullAddress = TextEditingController();
  final _houseNumber = TextEditingController();
  final _landmark = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController();
  final _pincode = TextEditingController();

  late AddressLabel _label;
  late bool _makeDefault;
  Coordinates? _point;

  bool _isSaving = false;
  bool _isLocating = false;
  String? _errorMessage;
  LocationException? _locationError;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;

    _label = existing?.label ?? AddressLabel.home;
    // An address that is already the default cannot be un-defaulted here; the
    // API rejects that, so the switch is not offered for it.
    _makeDefault = existing?.isDefault ?? false;
    _point =
        widget.initialPoint ??
        (existing == null
            ? null
            : Coordinates(
                latitude: existing.latitude,
                longitude: existing.longitude,
              ));

    if (existing != null) {
      _fullAddress.text = existing.fullAddress;
      _houseNumber.text = existing.houseNumber ?? '';
      _landmark.text = existing.landmark ?? '';
      _city.text = existing.city;
      _state.text = existing.state;
      _pincode.text = existing.pincode;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // A point carried in from the picker has no address text with it yet.
    if (widget.initialPoint != null && _city.text.isEmpty && !_isLocating) {
      _prefillFrom(widget.initialPoint!);
    }
  }

  @override
  void dispose() {
    _fullAddress.dispose();
    _houseNumber.dispose();
    _landmark.dispose();
    _city.dispose();
    _state.dispose();
    _pincode.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    final location = AppServicesScope.of(context).location;
    setState(() {
      _isLocating = true;
      _locationError = null;
      _errorMessage = null;
    });

    try {
      final point = await location.currentPosition();
      if (!mounted) {
        return;
      }
      setState(() => _point = point);
      await _prefillFrom(point);
    } on LocationException catch (error) {
      if (mounted) {
        setState(() => _locationError = error);
      }
    } finally {
      if (mounted) {
        setState(() => _isLocating = false);
      }
    }
  }

  /// Fills in whatever the platform geocoder knows, without overwriting
  /// anything the customer has already typed.
  Future<void> _prefillFrom(Coordinates point) async {
    final location = AppServicesScope.of(context).location;
    setState(() => _isLocating = true);

    final place = await location.describe(point);
    if (!mounted) {
      return;
    }

    setState(() {
      _isLocating = false;
      if (_fullAddress.text.isEmpty && place.street != null) {
        _fullAddress.text = place.street!;
      }
      if (_city.text.isEmpty && place.city != null) {
        _city.text = place.city!;
      }
      if (_state.text.isEmpty && place.state != null) {
        _state.text = place.state!;
      }
      if (_pincode.text.isEmpty && place.pincode != null) {
        _pincode.text = place.pincode!;
      }
    });
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final point = _point;
    if (point == null) {
      setState(
        () => _errorMessage =
            'Set the location on the map first, so your partner can find you.',
      );
      return;
    }

    final addresses = AppServicesScope.of(context).addresses;
    final navigator = Navigator.of(context);
    final existing = widget.existing;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final draft = AddressDraft(
      label: _label,
      fullAddress: _fullAddress.text,
      city: _city.text,
      state: _state.text,
      pincode: _pincode.text,
      latitude: point.latitude,
      longitude: point.longitude,
      houseNumber: _houseNumber.text.trim().isEmpty ? null : _houseNumber.text,
      landmark: _landmark.text.trim().isEmpty ? null : _landmark.text,
      // Never sent as false: the API refuses to clear a default outright.
      isDefault: _makeDefault ? true : null,
    );

    try {
      final saved = existing == null
          ? await addresses.addAddress(draft)
          : await addresses.updateAddress(existing.id, draft);

      navigator.pop(saved);
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

  @override
  Widget build(BuildContext context) {
    final canEditDefault = !(widget.existing?.isDefault ?? false);

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      appBar: AppBar(
        backgroundColor: AppTheme.red,
        foregroundColor: Colors.white,
        title: Text(
          _isEditing ? 'Edit address' : 'Add address',
          style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              const _FieldLabel('Save this address as'),
              LabelSelector(
                value: _label,
                enabled: !_isSaving,
                onChanged: (label) => setState(() => _label = label),
              ),
              const SizedBox(height: 22),
              _LocationRow(
                point: _point,
                isBusy: _isLocating,
                onUse: _isSaving || _isLocating ? null : _useCurrentLocation,
              ),
              if (_locationError != null) ...[
                const SizedBox(height: 12),
                _LocationErrorNote(error: _locationError!),
              ],
              const SizedBox(height: 22),
              _Field(
                controller: _houseNumber,
                label: 'Flat / house number',
                hint: 'Flat 4B',
                enabled: !_isSaving,
              ),
              const SizedBox(height: 14),
              _Field(
                controller: _fullAddress,
                label: 'Address',
                hint: 'Building, street, area',
                enabled: !_isSaving,
                maxLines: 2,
                validator: (value) => (value?.trim().length ?? 0) < 5
                    ? 'Enter the building and street'
                    : null,
              ),
              const SizedBox(height: 14),
              _Field(
                controller: _landmark,
                label: 'Landmark (optional)',
                hint: 'Opposite the metro station',
                enabled: !_isSaving,
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _Field(
                      controller: _city,
                      label: 'City',
                      enabled: !_isSaving,
                      validator: (value) => (value?.trim().length ?? 0) < 2
                          ? 'Enter the city'
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _Field(
                      controller: _state,
                      label: 'State',
                      enabled: !_isSaving,
                      validator: (value) => (value?.trim().length ?? 0) < 2
                          ? 'Enter the state'
                          : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _Field(
                controller: _pincode,
                label: 'PIN code',
                hint: '400001',
                enabled: !_isSaving,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                validator: _validatePincode,
              ),
              if (canEditDefault) ...[
                const SizedBox(height: 8),
                SwitchListTile.adaptive(
                  value: _makeDefault,
                  onChanged: _isSaving
                      ? null
                      : (value) => setState(() => _makeDefault = value),
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: AppTheme.red,
                  title: const Text(
                    'Use as my default address',
                    style: TextStyle(
                      color: AppTheme.ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
              if (_errorMessage != null) ...[
                const SizedBox(height: 14),
                AuthErrorText(message: _errorMessage!),
              ],
              const SizedBox(height: 22),
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
                label: Text(
                  _isSaving
                      ? 'Saving...'
                      : (_isEditing ? 'Save changes' : 'Save address'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Indian PIN codes are six digits and never start with zero — the same rule
  /// the API enforces, checked here so a round trip is not wasted on it.
  String? _validatePincode(String? value) {
    final pincode = value?.trim() ?? '';

    if (!RegExp(r'^[1-9][0-9]{5}$').hasMatch(pincode)) {
      return 'Enter a six-digit PIN code';
    }
    return null;
  }
}

class _LocationRow extends StatelessWidget {
  const _LocationRow({
    required this.point,
    required this.isBusy,
    required this.onUse,
  });

  final Coordinates? point;
  final bool isBusy;
  final VoidCallback? onUse;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.line),
      ),
      child: Row(
        children: [
          Icon(
            point == null
                ? Icons.location_searching_rounded
                : Icons.my_location_rounded,
            color: point == null ? AppTheme.muted : AppTheme.red,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  point == null ? 'Map location not set' : 'Map location set',
                  style: const TextStyle(
                    color: AppTheme.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  point?.toString() ??
                      'Needed so your partner can find the place.',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (isBusy)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppTheme.red,
              ),
            )
          else
            TextButton(
              onPressed: onUse,
              child: Text(point == null ? 'Use current' : 'Update'),
            ),
        ],
      ),
    );
  }
}

class _LocationErrorNote extends StatelessWidget {
  const _LocationErrorNote({required this.error});

  final LocationException error;

  @override
  Widget build(BuildContext context) {
    final location = AppServicesScope.of(context).location;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AuthErrorText(message: error.message),
        if (error.needsSettings)
          TextButton.icon(
            onPressed: location.openSettings,
            icon: const Icon(Icons.settings_rounded, size: 18),
            label: const Text('Open settings'),
          ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
          color: AppTheme.ink,
          fontSize: 14,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    this.hint,
    this.enabled = true,
    this.maxLines = 1,
    this.keyboardType,
    this.inputFormatters,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool enabled;
  final int maxLines;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      maxLines: maxLines,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      decoration: InputDecoration(labelText: label, hintText: hint),
    );
  }
}
