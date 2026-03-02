import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:safety_check_list/l10n/app_localizations.dart';

import 'screens/home_screen.dart';
import 'screens/auth/login_screen.dart';
import 'widgets/splash_screen.dart';
import 'theme/app_theme.dart';
import 'providers/settings_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ FIX LocaleDataException
  await initializeDateFormatting();

  runApp(const SafetyCheckApp());
}

class SafetyCheckApp extends StatelessWidget {
  const SafetyCheckApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settingsProvider, child) {
          return MaterialApp(
            title: 'Safety Check Lists',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,

            // ✅ Dynamic Locale
            locale: settingsProvider.instanceCurrentLocale.languageCode == 'km'
                ? const Locale('km', 'KH')
                : const Locale('en', 'US'),

            supportedLocales: const [
              Locale('en', 'US'),
              Locale('km', 'KH'),
            ],

            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],

            initialRoute: '/',
            routes: {
              '/': (context) => const SplashScreen(),
              '/login': (context) => const LoginScreen(),
              '/home': (context) => const HomeScreen(),
            },
          );
        },
      ),
    );
  }
}
