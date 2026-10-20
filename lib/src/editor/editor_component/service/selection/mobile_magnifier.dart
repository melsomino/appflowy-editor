import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'mobile_magnifier_layout.dart';

class MobileMagnifier extends StatefulWidget {
  const MobileMagnifier({
    super.key,
    required this.size,
    required this.offset,
  });

  final Size size;

  /// Focal point in global coordinates, independent of the editor's clipping.
  final Offset offset;

  @override
  State<MobileMagnifier> createState() => _MobileMagnifierState();
}

class _MobileMagnifierState extends State<MobileMagnifier> {
  final _portal = OverlayPortalController()..show();

  @override
  Widget build(BuildContext context) => OverlayPortal(
        controller: _portal,
        overlayLocation: OverlayChildLocation.rootOverlay,
        overlayChildBuilder: _buildLens,
        child: const SizedBox.shrink(),
      );

  Widget _buildLens(BuildContext context) {
    final overlay = Overlay.of(context, rootOverlay: true);
    final box = overlay.context.findRenderObject()! as RenderBox;
    final media = MediaQuery.of(overlay.context);
    final padding = media.viewPadding;
    final focalPoint = box.globalToLocal(widget.offset);
    final rect = mobileMagnifierRect(
      size: widget.size,
      focalPoint: focalPoint,
      bounds: Rect.fromLTRB(
        padding.left + 8,
        padding.top + 8,
        box.size.width - padding.right - 8,
        box.size.height - math.max(padding.bottom, media.viewInsets.bottom) - 8,
      ),
    );
    return Positioned.fromRect(
      rect: rect,
      child: IgnorePointer(
        child: _CustomMagnifier(
          size: widget.size,
          additionalFocalPointOffset: focalPoint - rect.center,
        ),
      ),
    );
  }
}

class _CustomMagnifier extends StatelessWidget {
  const _CustomMagnifier({
    this.additionalFocalPointOffset = Offset.zero,
    required this.size,
  });

  final Size size;
  final Offset additionalFocalPointOffset;

  @override
  Widget build(BuildContext context) {
    return RawMagnifier(
      decoration: const MagnifierDecoration(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(40)),
        ),
        shadows: <BoxShadow>[
          BoxShadow(
            blurRadius: 1.5,
            offset: Offset(0, 2),
            spreadRadius: 0.75,
            color: Color.fromARGB(25, 0, 0, 0),
          ),
        ],
      ),
      magnificationScale: 1.25,
      focalPointOffset: additionalFocalPointOffset,
      size: size,
      child: const ColoredBox(
        color: Color.fromARGB(8, 158, 158, 158),
      ),
    );
  }
}
