import 'package:flutter/material.dart';
import 'package:washbinapp/core/theme/app_theme.dart';

/// An image from the API, with somewhere to stand while it loads and something
/// to show when it never arrives.
///
/// `imageUrl` is optional on both categories and services, and a catalogue
/// that is still being filled in will have plenty of gaps — so a missing image
/// is the normal case here, not an error worth shouting about.
class RemoteImage extends StatelessWidget {
  const RemoteImage({
    super.key,
    required this.url,
    required this.fallbackIcon,
    this.height,
    this.width,
    this.borderRadius = 8,
    this.fit = BoxFit.cover,
    this.iconSize = 28,
  });

  final String? url;
  final IconData fallbackIcon;
  final double? height;
  final double? width;
  final double borderRadius;
  final BoxFit fit;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final address = url;

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(
        height: height,
        width: width,
        child: address == null
            ? _placeholder()
            : Image.network(
                address,
                fit: fit,
                // A broken or unreachable image must not break the row it sits
                // in, so it degrades to the same placeholder as a missing one.
                errorBuilder: (_, _, _) => _placeholder(),
                loadingBuilder: (context, child, progress) =>
                    progress == null ? child : _placeholder(shimmer: true),
              ),
      ),
    );
  }

  Widget _placeholder({bool shimmer = false}) {
    return ColoredBox(
      color: shimmer
          ? AppTheme.line.withValues(alpha: 0.5)
          : AppTheme.red.withValues(alpha: 0.08),
      child: Center(
        child: Icon(
          fallbackIcon,
          color: shimmer ? AppTheme.muted : AppTheme.red,
          size: iconSize,
        ),
      ),
    );
  }
}
