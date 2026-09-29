import 'package:flutter/material.dart';
import 'package:washbinpartner/features/common/widgets/coming_soon_view.dart';

/// Everything this partner has been assigned, past and upcoming. Built in a
/// later phase.
class BookingsScreen extends StatelessWidget {
  const BookingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ComingSoonView(
      title: 'Bookings',
      icon: Icons.receipt_long_outlined,
      message: 'The jobs you have taken, upcoming and finished, will be here.',
      upcoming: [
        'Scheduled bookings assigned to you',
        'What you have completed, and when',
        'Customer details for a job you are on',
      ],
    );
  }
}
