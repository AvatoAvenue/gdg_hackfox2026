import 'package:flutter/material.dart';

class AppLogo2 extends StatelessWidget {
  final double size;

  /// When set, a white-to-tint color filter is applied so the logo reads
  /// cleanly on coloured surfaces (e.g. the dark navy nav bar).
  final Color? tint;

  const AppLogo2({super.key, this.size = 48, this.tint});

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      'assets/images/senda_logo_dos.png',
      fit: BoxFit.contain,
    );

    final constrained = SizedBox(width: size, height: size, child: image);

    if (tint != null) {
      return ColorFiltered(
        colorFilter: ColorFilter.mode(tint!, BlendMode.srcIn),
        child: constrained,
      );
    }

    return constrained;
  }
}
