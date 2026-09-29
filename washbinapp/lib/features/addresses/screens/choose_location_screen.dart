import 'package:flutter/material.dart';
import 'package:washbinapp/app/app_services_scope.dart';
import 'package:washbinapp/app/router/app_router.dart';
import 'package:washbinapp/core/api/api_exception.dart';
import 'package:washbinapp/core/async/async_controller.dart';
import 'package:washbinapp/core/async/async_state.dart';
import 'package:washbinapp/core/theme/app_theme.dart';
import 'package:washbinapp/core/widgets/app_error_view.dart';
import 'package:washbinapp/core/widgets/app_loading_indicator.dart';
import 'package:washbinapp/features/addresses/data/location_service.dart';
import 'package:washbinapp/features/addresses/domain/address.dart';
import 'package:washbinapp/features/addresses/domain/coordinates.dart';
import 'package:washbinapp/features/addresses/widgets/address_card.dart';
import 'package:washbinapp/features/bookings/domain/booking_draft.dart';
import 'package:washbinapp/features/catalogue/domain/service.dart';

/// Where the booking should happen: the customer's current location, or one of
/// their saved addresses.
///
/// Nothing is accepted until the server confirms Washbin covers it for this
/// service, so a customer can never carry an unserviceable point into booking.
class ChooseLocationScreen extends StatefulWidget {
  const ChooseLocationScreen({super.key, required this.service});

  final Service service;

  @override
  State<ChooseLocationScreen> createState() => _ChooseLocationScreenState();
}

/// What the customer picked, once the server has agreed to it.
class _Selection {
  const _Selection({required this.point, this.address, this.description});

  final Coordinates point;

  /// Null when the pick was "use my current location".
  final Address? address;
  final String? description;

  String get title => address?.label.display ?? 'Current location';
  String get subtitle => address?.oneLine ?? description ?? point.toString();
}

class _ChooseLocationScreenState extends State<ChooseLocationScreen> {
  AsyncController<List<Address>>? _addresses;

  _Selection? _selected;

  /// The address id currently being checked, or `_currentLocationKey`.
  String? _checkingId;
  static const _currentLocationKey = '__current__';

  String? _rejectedId;
  String? _message;
  LocationException? _locationError;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_addresses != null) {
      return;
    }
    final repository = AppServicesScope.of(context).addresses;
    _addresses = AsyncController(repository.getMyAddresses)..load();
  }

  @override
  void dispose() {
    _addresses?.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    final location = AppServicesScope.of(context).location;
    setState(() {
      _checkingId = _currentLocationKey;
      _locationError = null;
      _message = null;
      _rejectedId = null;
    });

    try {
      final point = await location.currentPosition();
      final place = await location.describe(point);
      if (!mounted) {
        return;
      }

      await _confirm(
        _Selection(
          point: point,
          description: [
            place.street,
            place.city,
            place.pincode,
          ].whereType<String>().join(', '),
        ),
        key: _currentLocationKey,
      );
    } on LocationException catch (error) {
      if (mounted) {
        setState(() => _locationError = error);
      }
    } finally {
      if (mounted) {
        setState(() => _checkingId = null);
      }
    }
  }

  Future<void> _useAddress(Address address) async {
    setState(() {
      _checkingId = address.id;
      _locationError = null;
      _message = null;
      _rejectedId = null;
    });

    await _confirm(
      _Selection(
        point: Coordinates(
          latitude: address.latitude,
          longitude: address.longitude,
        ),
        address: address,
      ),
      key: address.id,
    );

    if (mounted) {
      setState(() => _checkingId = null);
    }
  }

  /// Asks the server whether this point is covered, and only then accepts it.
  Future<void> _confirm(_Selection selection, {required String key}) async {
    final repository = AppServicesScope.of(context).addresses;

    try {
      final serviceable = await repository.isServiceable(
        point: selection.point,
        serviceId: widget.service.id,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        if (serviceable) {
          _selected = selection;
          _message = null;
          _rejectedId = null;
        } else {
          _selected = null;
          _rejectedId = key;
          _message =
              'Washbin does not cover this area for ${widget.service.name} '
              'yet. Try another address.';
        }
      });
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _selected = null;
          _message = error.message;
        });
      }
    }
  }

  Future<void> _addAddress({Coordinates? at}) async {
    final saved = await Navigator.of(context)
        .push(AppRouter.addressForm(initialPoint: at));

    if (saved != null && mounted) {
      await _addresses?.refresh();
      await _useAddress(saved);
    }
  }

  Future<void> _continue() async {
    final selection = _selected;
    if (selection == null) {
      return;
    }

    var address = selection.address;

    // A booking is created against a saved address id, not raw coordinates —
    // so a current-location pick has to become an address first. The form
    // opens on the fix that was just confirmed, so nothing is asked twice.
    if (address == null) {
      final saved = await Navigator.of(context)
          .push(AppRouter.addressForm(initialPoint: selection.point));

      if (saved == null || !mounted) {
        return;
      }
      await _addresses?.refresh();
      if (!mounted) {
        return;
      }

      // Re-checked rather than assumed: the form lets the pin be moved before
      // saving, and the new point may sit outside the serviceable area.
      await _useAddress(saved);
      if (!mounted || _selected?.address?.id != saved.id) {
        return;
      }
      address = saved;
    }

    if (!mounted) {
      return;
    }
    await Navigator.of(context).push(
      AppRouter.bookingSetup(
        BookingDraft(service: widget.service, address: address),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _addresses!;

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      appBar: AppBar(
        backgroundColor: AppTheme.red,
        foregroundColor: Colors.white,
        title: const Text(
          'Choose location',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0),
        ),
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) => _body(controller),
        ),
      ),
      bottomNavigationBar: _ContinueBar(
        selection: _selected,
        onContinue: _selected == null || _checkingId != null ? null : _continue,
      ),
    );
  }

  Widget _body(AsyncController<List<Address>> controller) {
    return RefreshIndicator(
      color: AppTheme.red,
      onRefresh: controller.refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _ServiceLine(service: widget.service),
          const SizedBox(height: 18),
          _CurrentLocationTile(
            isBusy: _checkingId == _currentLocationKey,
            isSelected: _selected != null && _selected!.address == null,
            isRejected: _rejectedId == _currentLocationKey,
            onTap: _checkingId != null ? null : _useCurrentLocation,
          ),
          if (_locationError != null) ...[
            const SizedBox(height: 12),
            _LocationErrorNote(error: _locationError!),
          ],
          if (_message != null) ...[
            const SizedBox(height: 12),
            _NoticeBanner(message: _message!),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Saved addresses',
                  style: TextStyle(
                    color: AppTheme.ink,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _checkingId != null ? null : () => _addAddress(),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add new'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ..._addressList(controller),
        ],
      ),
    );
  }

  List<Widget> _addressList(AsyncController<List<Address>> controller) {
    return switch (controller.state) {
      AsyncLoading<List<Address>>() => const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: AppLoadingIndicator(),
        ),
      ],
      AsyncFailure<List<Address>>(:final error) => [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: AppErrorView.fromException(error, onRetry: controller.load),
        ),
      ],
      AsyncData<List<Address>>(:final value) ||
      AsyncRefreshing<List<Address>>(:final value) => _rows(value),
    };
  }

  List<Widget> _rows(List<Address> addresses) {
    if (addresses.isEmpty) {
      return [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.line),
          ),
          child: const Text(
            'No saved addresses yet. Add one, or use your current location.',
            style: TextStyle(
              color: AppTheme.muted,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
        ),
      ];
    }

    return [
      for (final address in addresses) ...[
        AddressCard(
          address: address,
          isBusy: _checkingId == address.id,
          isSelected: _selected?.address?.id == address.id,
          onTap: _checkingId != null ? null : () => _useAddress(address),
          trailing: _rejectedId == address.id
              ? const Icon(Icons.block_rounded, color: AppTheme.muted, size: 20)
              : (_selected?.address?.id == address.id
                    ? const Icon(
                        Icons.check_circle_rounded,
                        color: AppTheme.red,
                        size: 22,
                      )
                    : null),
        ),
        if (address != addresses.last) const SizedBox(height: 12),
      ],
    ];
  }
}

class _ServiceLine extends StatelessWidget {
  const _ServiceLine({required this.service});

  final Service service;

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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  service.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Where should we send your partner?',
                  style: TextStyle(
                    color: AppTheme.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Text(
            service.priceLabel,
            style: const TextStyle(
              color: AppTheme.red,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _CurrentLocationTile extends StatelessWidget {
  const _CurrentLocationTile({
    required this.isBusy,
    required this.isSelected,
    required this.isRejected,
    required this.onTap,
  });

  final bool isBusy;
  final bool isSelected;
  final bool isRejected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? AppTheme.red : AppTheme.line,
              width: isSelected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.my_location_rounded,
                  color: AppTheme.red,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Use my current location',
                      style: TextStyle(
                        color: AppTheme.ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'We will ask for location permission',
                      style: TextStyle(
                        color: AppTheme.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (isBusy)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.red,
                  ),
                )
              else if (isSelected)
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppTheme.red,
                  size: 22,
                )
              else if (isRejected)
                const Icon(
                  Icons.block_rounded,
                  color: AppTheme.muted,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoticeBanner extends StatelessWidget {
  const _NoticeBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.red.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: AppTheme.red, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppTheme.ink,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
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
        _NoticeBanner(message: error.message),
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

class _ContinueBar extends StatelessWidget {
  const _ContinueBar({required this.selection, required this.onContinue});

  final _Selection? selection;
  final VoidCallback? onContinue;

  /// Says what the button will actually do, since a current-location pick
  /// takes a detour through saving it as an address.
  String get _label => switch (selection) {
    null => 'Select a location',
    final selection when selection.address == null => 'Save address & continue',
    _ => 'Continue',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppTheme.line)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (selection != null) ...[
              Row(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: AppTheme.red,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${selection!.title} · we serve this area',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.ink,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
            FilledButton(onPressed: onContinue, child: Text(_label)),
          ],
        ),
      ),
    );
  }
}
