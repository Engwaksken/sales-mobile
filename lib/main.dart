import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';

import 'core/api_client.dart';
import 'core/app_theme.dart';
import 'core/auth_store.dart';
import 'core/branding.dart';
import 'core/staff_lookups.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const storage = FlutterSecureStorage();
  final api = ApiClient(storage);
  final auth = AuthStore(api, storage);
  final branding = BrandingStore(api, storage);
  final themeMode = ThemeModeStore(storage);

  await Future.wait([auth.bootstrap(), branding.loadCached(), themeMode.load()]);
  // Fresh name/logo from the server; the cached copy shows until it arrives.
  branding.refresh();

  runApp(
    MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: api),
        ChangeNotifierProvider<AuthStore>.value(value: auth),
        ChangeNotifierProvider<BrandingStore>.value(value: branding),
        ChangeNotifierProvider<ThemeModeStore>.value(value: themeMode),
        // Staff pick-lists; reloaded each time the staff workspace opens.
        ChangeNotifierProvider<StaffLookups>(create: (_) => StaffLookups(api)),
      ],
      child: const NSalesApp(),
    ),
  );
}

class NSalesApp extends StatelessWidget {
  const NSalesApp({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthStore>();
    final brand = context.watch<BrandingStore>();

    return MaterialApp(
      title: brand.siteName,
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(brand.primary, Brightness.light),
      darkTheme: buildAppTheme(brand.primary, Brightness.dark),
      themeMode: context.watch<ThemeModeStore>().mode,
      // bootstrap() finishes before runApp, so auth.loading is only true while
      // a sign-in/sign-up request runs. Swapping in a spinner then would
      // dispose the sign-in screen and lose its error or verification step.
      home: auth.authenticated ? const HomeScreen() : const LoginScreen(),
    );
  }
}
