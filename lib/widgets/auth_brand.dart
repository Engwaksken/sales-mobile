import 'package:flutter/material.dart';

import '../core/branding.dart';

/// The admin's logo on a white tile, used in the branded header of the
/// sign-in, sign-up and recovery screens. Logos are usually drawn for a
/// white background, so the tile stays white in both themes.
class AuthBrand extends StatelessWidget {
  const AuthBrand({
    super.key,
    this.size = 64,
  });

  final double size;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        image: true,
        label: '${context.brandName} logo',
        child: Container(
          width: size,
          height: size,
          padding: EdgeInsets.all(size * .12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(size * .26),
            boxShadow: const [
              BoxShadow(
                color: Color(0x290F172A),
                blurRadius: 18,
                offset: Offset(0, 6),
              ),
            ],
          ),
          // The logo uploaded by the admin, or the bundled one until it loads.
          child: ExcludeSemantics(child: BrandLogo(size: size * .76)),
        ),
      ),
    );
  }
}
