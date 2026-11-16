import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/app_theme.dart';

class ApiStatusBanner extends StatefulWidget {
  const ApiStatusBanner({super.key});

  @override
  State<ApiStatusBanner> createState() => _ApiStatusBannerState();
}

class _ApiStatusBannerState extends State<ApiStatusBanner> {
  bool checking = true;
  bool available = true;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final ok = await context.read<ApiClient>().authApiAvailable();

    if (!mounted) return;

    setState(() {
      checking = false;
      available = ok;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (checking || available) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.warningSoft,
        border: Border.all(color: context.warningBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: context.warningInk,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              "We can't reach the server right now. Check your internet "
              'connection. Signing in may not work until it is back.',
              style: TextStyle(
                color: context.warningInk,
                fontSize: 12,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
