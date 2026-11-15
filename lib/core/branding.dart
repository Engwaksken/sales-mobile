import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';

import 'api_client.dart';
import 'brand_defaults.dart';
import 'config.dart';

/// The system name, logo, favicon and theme colour an admin sets under
/// Settings on the website. Cached on the phone (including the image bytes)
/// so the sign-in screen shows the right brand instantly and offline.
class BrandingStore extends ChangeNotifier {
  BrandingStore(this.api, this.storage);

  final ApiClient api;
  final FlutterSecureStorage storage;

  static const _key = 'branding_v1';

  /// Keep cached images small enough for secure storage.
  static const _maxImageBytes = 600 * 1024;

  // Built-in defaults come from the website Settings at build time (tool/sync_branding.ps1).
  String siteName = kBrandName;
  String? logoUrl;
  String? faviconUrl;
  Color primary = kBrandPrimary;
  Uint8List? logoBytes;
  Uint8List? faviconBytes;

  /// Reads the last known branding; call before runApp.
  Future<void> loadCached() async {
    try {
      final raw = await storage.read(key: _key);
      if (raw == null) return;
      final data = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      _apply(data);
      logoBytes = _bytes(data['logo_bytes']);
      faviconBytes = _bytes(data['favicon_bytes']);
    } catch (_) {
      // A bad cache only means the defaults show until the next refresh.
    }
  }

  /// Fetches the current branding from the server and caches it.
  Future<void> refresh() async {
    try {
      final response = await api.get('/branding');
      final data = Map<String, dynamic>.from(response.data as Map);
      final oldLogo = logoUrl;
      final oldFavicon = faviconUrl;
      _apply(data);

      if (logoUrl != oldLogo || (logoUrl != null && logoBytes == null)) {
        logoBytes = await _download(logoUrl);
      }
      if (faviconUrl != oldFavicon || (faviconUrl != null && faviconBytes == null)) {
        faviconBytes = await _download(faviconUrl);
      }
      notifyListeners();

      await storage.write(
        key: _key,
        value: jsonEncode({
          ...data,
          if (logoBytes != null) 'logo_bytes': base64Encode(logoBytes!),
          if (faviconBytes != null) 'favicon_bytes': base64Encode(faviconBytes!),
        }),
      );
    } catch (_) {
      // Offline or an older server: keep what we have.
    }
  }

  void _apply(Map<String, dynamic> data) {
    final name = '${data['site_name'] ?? ''}'.trim();
    siteName = name.isEmpty ? kBrandName : name;
    logoUrl = _url(data['logo_url']);
    faviconUrl = _url(data['favicon_url']);
    primary = _color(data['theme_primary']) ?? primary;
    if (logoUrl == null) logoBytes = null;
    if (faviconUrl == null) faviconBytes = null;
  }

  Future<Uint8List?> _download(String? url) async {
    if (url == null) return null;
    try {
      final response = await api.dio.get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes, receiveTimeout: const Duration(seconds: 20)),
      );
      final bytes = response.data;
      if (response.statusCode != 200 || bytes == null || bytes.isEmpty || bytes.length > _maxImageBytes) return null;
      return Uint8List.fromList(bytes);
    } catch (_) {
      return null;
    }
  }

  static String? _url(dynamic value) {
    final text = '${value ?? ''}'.trim();
    return text.startsWith('http') ? text : null;
  }

  static Uint8List? _bytes(dynamic value) {
    if (value is! String || value.isEmpty) return null;
    try {
      return base64Decode(value);
    } catch (_) {
      return null;
    }
  }

  static Color? _color(dynamic value) {
    final hex = '${value ?? ''}'.replaceFirst('#', '');
    if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(hex)) return null;
    return Color(int.parse('FF$hex', radix: 16));
  }
}

/// The admin's logo (or favicon when [favicon] is true), falling back to the
/// bundled app logo when none is set or it cannot be loaded.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 36, this.favicon = false});

  final double size;
  final bool favicon;

  @override
  Widget build(BuildContext context) {
    final brand = context.watch<BrandingStore>();
    // The favicon is meant for small spots; use the logo when there is no favicon.
    final bytes = favicon ? (brand.faviconBytes ?? brand.logoBytes) : brand.logoBytes;
    final url = favicon ? (brand.faviconUrl ?? brand.logoUrl) : brand.logoUrl;
    final fallback = Image.asset(AppConfig.logoAsset, width: size, height: size, fit: BoxFit.contain);

    Widget image;
    if (bytes != null) {
      image = Image.memory(bytes, width: size, height: size, fit: BoxFit.contain, gaplessPlayback: true, errorBuilder: (_, _, _) => fallback);
    } else if (url != null) {
      image = Image.network(url, width: size, height: size, fit: BoxFit.contain, errorBuilder: (_, _, _) => fallback);
    } else {
      image = fallback;
    }

    return SizedBox(width: size, height: size, child: image);
  }
}

extension BrandingContext on BuildContext {
  /// The system name set by the admin, e.g. "Bweyamo Hardware".
  String get brandName => watch<BrandingStore>().siteName;
}
