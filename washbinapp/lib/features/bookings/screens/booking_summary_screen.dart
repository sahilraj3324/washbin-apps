import 'package:flutter/material.dart';
import 'package:washbinapp/app/app_services_scope.dart';
import 'package:washbinapp/app/router/app_router.dart';
import 'package:washbinapp/core/api/api_exception.dart';
import 'package:washbinapp/core/session/session_scope.dart';
import 'package:washbinapp/core/theme/app_theme.dart';
import 'package:washbinapp/features/bookings/domain/booking_draft.dart';
import 'package:washbinapp/features/bookings/domain/booking_time.dart';
import 'package:washbinapp/features/bookings/widgets/summary_row.dart';
import 'package:washbinapp/features/catalogue/domain/service.dart';

/// The last look before anything is created, and the only screen that calls
/// `POST /bookings`.
class BookingSummaryScreen extends StatefulWidget {
  const BookingSummaryScreen({super.key, required this.draft});

  final BookingDraft draft;

  @override
  State<BookingSummaryScreen> createState() => _BookingSummaryScreenState();
}

class _BookingSummaryScreenState extends State<BookingSummaryScreen> {
  /// Guards the request itself.
  ///
  /// A plain field rather than only widget state: two taps can land in the
  /// same frame, before any rebuild has had a chance to disable the button,
  /// and this is read and set synchronously before the first `await`.
  bool _isSubmitting = false;

  String? _errorMessage;

  Future<void> _confirm() async {
    if (_isSubmitting) {
      return;
    }
    _isSubmitting = true;
    setState(() => _errorMessage = null);

    final draft = widget.draft;

    // Re-checked at the point of no return: the customer may have sat on this
    // screen long enough for a valid time to fall inside the lead window.
    final invalid = draft.validationError;
    if (invalid != null) {
      _isSubmitting = false;
      setState(() => _errorMessage = invalid);
      return;
    }

    final bookings = AppServicesScope.of(context).bookings;
    final navigator = Navigator.of(context);

    try {
      final booking = await bookings.create(draft);
      if (!mounted) {
        return;
      }

      // Replaces rather than pushes: going back from the confirmation must
      // not land on a Confirm button that would create a second booking.
      navigator.pushReplacement(
        AppRouter.bookingCreated(booking: booking, service: draft.service),
      );
    } on ApiException catch (error) {
      // A 401 is handled by the session, which signs out and rebuilds the app
      // from the gate — there is nothing useful to show here.
      if (mounted) {
        _isSubmitting = false;
        setState(() => _errorMessage = error.message);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = widget.draft;
    final service = draft.service;
    final address = draft.address;
    final customer = SessionScope.of(context).customer;

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      appBar: AppBar(
        backgroundColor: AppTheme.red,
        foregroundColor: Colors.white,
        title: const Text(
          'Booking summary',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.line),
              ),
              child: Column(
                children: [
                  SummaryRow(
                    label: 'SERVICE',
                    value: service.name,
                    detail: service.durationLabel == null
                        ? null
                        : 'About ${service.durationLabel}',
                    icon: Icons.home_repair_service_rounded,
                  ),
                  const Divider(height: 1, color: AppTheme.line),
                  SummaryRow(
                    label: 'LOCATION',
                    value: address.label.display,
                    detail: address.oneLine,
                    icon: Icons.location_on_outlined,
                    onEdit: _isSubmitting
                        ? null
                        : () => Navigator.of(context).pop(),
                  ),
                  const Divider(height: 1, color: AppTheme.line),
                  SummaryRow(
                    label: 'BOOKING',
                    value: draft.isScheduled
                        ? BookingTime.describe(draft.scheduledAt!)
                        : 'Now',
                    detail: draft.isScheduled
                        ? null
                        : 'We will start looking for a partner right away.',
                    icon: Icons.schedule_rounded,
                  ),
                  const Divider(height: 1, color: AppTheme.line),
                  SummaryRow(
                    label: service.pricingType == PricingType.fixed
                        ? 'PRICE'
                        : 'ESTIMATED PRICE',
                    value: service.priceLabel,
                    detail: service.pricingNote,
                    icon: Icons.currency_rupee_rounded,
                    emphasise: true,
                  ),
                  if (draft.notes?.trim().isNotEmpty ?? false) ...[
                    const Divider(height: 1, color: AppTheme.line),
                    SummaryRow(
                      label: 'NOTES',
                      value: draft.notes!.trim(),
                      icon: Icons.sticky_note_2_outlined,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),
            if (customer != null)
              Text(
                'Booking as ${customer.name} · ${customer.phone}',
                style: const TextStyle(
                  color: AppTheme.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              _FailureNote(message: _errorMessage!),
            ],
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppTheme.line)),
        ),
        child: SafeArea(
          top: false,
          child: FilledButton.icon(
            onPressed: _isSubmitting ? null : _confirm,
            icon: _isSubmitting
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
              _isSubmitting ? 'Creating booking...' : 'Confirm booking',
            ),
          ),
        ),
      ),
    );
  }
}

class _FailureNote extends StatelessWidget {
  const _FailureNote({required this.message});

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
          const Icon(
            Icons.error_outline_rounded,
            color: AppTheme.red,
            size: 20,
          ),
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
