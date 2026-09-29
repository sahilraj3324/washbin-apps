import 'package:flutter/material.dart';

/// Makes a centred message fill — and scroll within — the space it is given.
///
/// Empty and error states are short, so on their own they do not scroll, and a
/// `RefreshIndicator` above a non-scrolling child never fires. Wrapping them
/// keeps pull-to-refresh working on exactly the screens where the partner is
/// most likely to reach for it.
class ScrollableMessage extends StatelessWidget {
  const ScrollableMessage({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: child,
          ),
        );
      },
    );
  }
}
