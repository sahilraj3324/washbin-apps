import 'package:flutter/material.dart';
import 'package:washbinapp/app/router/app_router.dart';
import 'package:washbinapp/core/theme/app_theme.dart';
import 'package:washbinapp/features/bookings/domain/booking_draft.dart';
import 'package:washbinapp/features/bookings/domain/booking_status.dart';
import 'package:washbinapp/features/bookings/domain/booking_time.dart';

/// When the customer wants the service, and anything the partner should know.
///
/// Booking type, schedule and notes are one screen rather than three pushes:
/// picking "Book now" answers all three at once, and only "Schedule" adds a
/// second question.
class BookingSetupScreen extends StatefulWidget {
  const BookingSetupScreen({super.key, required this.draft});

  final BookingDraft draft;

  @override
  State<BookingSetupScreen> createState() => _BookingSetupScreenState();
}

class _BookingSetupScreenState extends State<BookingSetupScreen> {
  late BookingDraft _draft = widget.draft;
  final _notes = TextEditingController();
  bool _showScheduleError = false;

  @override
  void initState() {
    super.initState();
    _notes.text = widget.draft.notes ?? '';
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  void _setType(BookingType type) {
    setState(() {
      _showScheduleError = false;
      _draft = _draft.copyWith(
        bookingType: type,
        // An instant booking must carry no time at all — the API rejects one.
        clearSchedule: type == BookingType.instant,
      );
    });
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final current = _draft.scheduledAt ?? BookingTime.suggestion(now: now);

    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: now,
      lastDate: BookingTime.latest(now: now),
    );
    if (date == null || !mounted) {
      return;
    }

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (time == null || !mounted) {
      return;
    }

    setState(() {
      _showScheduleError = false;
      _draft = _draft.copyWith(
        scheduledAt: DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        ),
      );
    });
  }

  void _review() {
    final draft = _draft.copyWith(notes: _notes.text);

    // Checked here so a bad time is corrected on this screen rather than by a
    // rejected request two screens later.
    if (!draft.isValid) {
      setState(() => _showScheduleError = true);
      return;
    }

    Navigator.of(context).push(AppRouter.bookingSummary(draft));
  }

  @override
  Widget build(BuildContext context) {
    final scheduleError = _showScheduleError ? _draft.validationError : null;

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      appBar: AppBar(
        backgroundColor: AppTheme.red,
        foregroundColor: Colors.white,
        title: const Text(
          'When do you need it?',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            _TypeCard(
              type: BookingType.instant,
              title: 'Book now',
              subtitle: 'We start looking for a partner right away',
              icon: Icons.bolt_rounded,
              isSelected: !_draft.isScheduled,
              onTap: () => _setType(BookingType.instant),
            ),
            const SizedBox(height: 12),
            _TypeCard(
              type: BookingType.scheduled,
              title: 'Schedule',
              subtitle: 'Pick a date and time that suits you',
              icon: Icons.event_rounded,
              isSelected: _draft.isScheduled,
              onTap: () => _setType(BookingType.scheduled),
            ),
            if (_draft.isScheduled) ...[
              const SizedBox(height: 16),
              _ScheduleRow(
                scheduledAt: _draft.scheduledAt,
                onPick: _pickDateTime,
              ),
              if (scheduleError != null) ...[
                const SizedBox(height: 10),
                Text(
                  scheduleError,
                  style: const TextStyle(
                    color: AppTheme.red,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
              ],
            ],
            const SizedBox(height: 28),
            const Text(
              'Anything we should know?',
              style: TextStyle(
                color: AppTheme.ink,
                fontSize: 17,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _notes,
              maxLines: 4,
              maxLength: 1000,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText:
                    'Gate code, parking, pets, or anything else that helps.',
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _review,
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('Review booking'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeCard extends StatelessWidget {
  const _TypeCard({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final BookingType type;
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? AppTheme.red.withValues(alpha: 0.08) : Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(16),
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
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.red.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: AppTheme.red, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppTheme.ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                isSelected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: isSelected ? AppTheme.red : AppTheme.line,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScheduleRow extends StatelessWidget {
  const _ScheduleRow({required this.scheduledAt, required this.onPick});

  final DateTime? scheduledAt;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final when = scheduledAt;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onPick,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.line),
          ),
          child: Row(
            children: [
              const Icon(Icons.schedule_rounded, color: AppTheme.red),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      when == null ? 'Pick a date and time' : 'Arriving',
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      when == null
                          ? 'Not chosen yet'
                          : BookingTime.describe(when),
                      style: const TextStyle(
                        color: AppTheme.ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.edit_calendar_rounded, color: AppTheme.muted),
            ],
          ),
        ),
      ),
    );
  }
}
