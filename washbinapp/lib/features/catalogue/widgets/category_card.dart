import 'package:flutter/material.dart';
import 'package:washbinapp/core/theme/app_theme.dart';
import 'package:washbinapp/core/widgets/remote_image.dart';
import 'package:washbinapp/features/catalogue/domain/category.dart';

/// One tile in the "What do you need?" grid.
class CategoryCard extends StatelessWidget {
  const CategoryCard({super.key, required this.category, required this.onTap});

  final Category category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      elevation: 3,
      shadowColor: AppTheme.black.withValues(alpha: 0.16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.lightGrey),
          ),
          child: Stack(
            children: [
              Positioned(
                right: 0,
                bottom: 0,
                child: RemoteImage(
                  url: category.iconUrl ?? category.imageUrl,
                  fallbackIcon: _fallbackIcon(category.name),
                  width: 68,
                  height: 68,
                  iconSize: 36,
                ),
              ),
              Positioned.fill(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.ink,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _bookingCount(category.sortOrder),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF777A81),
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _bookingCount(int sortOrder) {
    const counts = [
      '26k+',
      '14k+',
      '16k+',
      '22k+',
      '12k+',
      '13k+',
      '8k+',
      '9k+',
    ];
    return '${counts[sortOrder.abs() % counts.length]} Bookings';
  }

  static IconData _fallbackIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('wash') || lower.contains('laundry')) {
      return Icons.local_laundry_service_rounded;
    }
    if (lower.contains('clean')) {
      return Icons.cleaning_services_rounded;
    }
    if (lower.contains('cook')) {
      return Icons.restaurant_rounded;
    }
    if (lower.contains('iron')) {
      return Icons.iron_rounded;
    }
    return Icons.home_repair_service_rounded;
  }
}
