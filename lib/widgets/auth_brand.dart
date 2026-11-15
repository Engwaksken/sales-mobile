import 'package:flutter/material.dart';

import '../core/branding.dart';

class AuthBrand extends StatelessWidget {
  const AuthBrand({
    super.key,
    this.size = 92,
  });

  final double size;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(size * .08),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(size * .22),
          boxShadow: const [
            BoxShadow(
              color: Color(0x160F172A),
              blurRadius: 24,
              offset: Offset(0, 10),
            ),
          ],
        ),
        // The logo uploaded by the admin, or the bundled one until it loads.
        child: BrandLogo(size: size * .84),
      ),
    );
  }
}
