import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';

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
        color: const Color(0xFFFFF7ED),
        border: Border.all(color: const Color(0xFFFED7AA)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: Color(0xFFC2410C),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'The NSales mobile API is not fully available on the server. '
              'Login, signup or OTP may fail until the Laravel mobile API '
              'routes are installed and route cache is cleared.',
              style: TextStyle(
                color: Color(0xFF9A3412),
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
