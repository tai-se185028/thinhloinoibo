import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'auth/auth_service.dart';
import 'core/supabase_config.dart';
import 'data/app_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  final config = SupabaseConfig.fromEnvironment();
  if (config.isValid) {
    await Supabase.initialize(
      url: config.url,
      publishableKey: config.publishableKey,
      debug: false,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
  }
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) =>
              config.isValid ? AppStore.supabase() : AppStore.seeded(),
        ),
        if (config.isValid)
          ChangeNotifierProvider(
            create: (context) => AuthController(
              AuthService(Supabase.instance.client),
              clearData: context.read<AppStore>().clearEmployeeData,
              onAuthorized: context.read<AppStore>().loadRemoteData,
            )..initialize(),
          ),
      ],
      child: PackFlowApp(configurationError: config.error),
    ),
  );
}
