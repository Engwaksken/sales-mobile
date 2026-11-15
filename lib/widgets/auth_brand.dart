import 'package:flutter/material.dart';

import '../core/config.dart';

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
        child: Image.asset(
          AppConfig.logoAsset,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => Icon(
            Icons.point_of_sale,
            size: size * .55,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }
}
