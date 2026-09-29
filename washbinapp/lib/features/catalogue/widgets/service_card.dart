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
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.line),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RemoteImage(
                url: service.imageUrl ?? service.iconUrl,
                fallbackIcon: Icons.cleaning_services_rounded,
                width: 76,
                height: 76,
              ),
              const SizedBox(width: 14),
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
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      service.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontSize: 12,
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
                            color: AppTheme.red,
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
}
