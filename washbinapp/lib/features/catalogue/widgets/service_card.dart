import 'package:flutter/material.dart';
import 'package:washbinapp/core/theme/app_theme.dart';
import 'package:washbinapp/core/widgets/remote_image.dart';
import 'package:washbinapp/features/catalogue/domain/service.dart';

/// One row in a service list: picture, name, price, and how long it takes.
class ServiceCard extends StatelessWidget {
  const ServiceCard({super.key, required this.service, required this.onTap});

  final Service service;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final duration = service.durationLabel;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      elevation: 2,
      shadowColor: AppTheme.black.withValues(alpha: 0.14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          constraints: const BoxConstraints(minHeight: 132),
          padding: const EdgeInsets.all(14),
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
                  url: service.imageUrl ?? service.iconUrl,
                  fallbackIcon: _fallbackIcon(service.name),
                  width: 92,
                  height: 92,
                  iconSize: 42,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 92),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      service.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.ink,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                        height: 1.08,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      service.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF777A81),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          service.priceLabel,
                          style: const TextStyle(
                            color: AppTheme.washbinYellow,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0,
                          ),
                        ),
                        if (duration != null) ...[
                          const SizedBox(width: 10),
                          const Icon(
                            Icons.schedule_rounded,
                            size: 13,
                            color: AppTheme.muted,
                          ),
                          const SizedBox(width: 3),
                          // Flexible so a long duration truncates rather than
                          // overflowing the card it sits in.
                          Flexible(
                            child: Text(
                              duration,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppTheme.muted,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
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
