import 'package:flutter/material.dart';

/// Animate the paint offset after a gap moves, keeping layout geometry at
/// its authoritative destination so the animation cannot change drop decisions.
class BlockGapAnimation extends StatefulWidget {
  const BlockGapAnimation({
    super.key,
    required this.shift,
    required this.enabled,
    required this.child,
  });

  final double shift;
  final bool enabled;
  final Widget child;

  @override
  State<BlockGapAnimation> createState() => _BlockGapAnimationState();
}

class _BlockGapAnimationState extends State<BlockGapAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
    value: 1,
  );
  double _from = 0;

  double get _offset =>
      _from * (1 - Curves.easeInOut.transform(_controller.value));

  @override
  void didUpdateWidget(BlockGapAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Finishing a drop keeps the same layout destination: let an in-flight
    // neighbour animation finish rather than snapping it on pointer release.
    if (widget.enabled &&
        oldWidget.enabled &&
        widget.shift != oldWidget.shift) {
      // Preserve the current painted position even if the gap reverses before
      // the previous animation finishes.
      _from = _offset + oldWidget.shift - widget.shift;
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, _offset),
          child: child,
        ),
        child: widget.child,
      );
}
