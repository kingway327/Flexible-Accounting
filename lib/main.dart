import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/app_settings_dao.dart';
import 'data/database_helper.dart';
import 'pages/splash_screen.dart';
import 'providers/finance_provider.dart';
import 'widgets/home/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final startupConfig = await _loadStartupConfig();
  runApp(FinanceApp(startupConfig: startupConfig));
}

Future<StartupConfig> _loadStartupConfig() async {
  final hour = DateTime.now().hour;
  final isDaytime = hour >= 6 && hour < 18;

  await DatabaseHelper.instance.database;
  final settingsDao = AppSettingsDao.instance;
  final animationEnabled = await settingsDao.getStartupAnimationEnabled();
  final shownOnce = await settingsDao.hasShownStartupAnimationOnce();
  final shouldShowSplash = animationEnabled || !shownOnce;

  return StartupConfig(
    isDaytime: isDaytime,
    shouldShowSplash: shouldShowSplash,
    markShownOnFinish: !shownOnce,
  );
}

class StartupConfig {
  const StartupConfig({
    required this.isDaytime,
    required this.shouldShowSplash,
    required this.markShownOnFinish,
  });

  final bool isDaytime;
  final bool shouldShowSplash;
  final bool markShownOnFinish;
}

/// 本地优先记账应用
class FinanceApp extends StatelessWidget {
  const FinanceApp({super.key, required this.startupConfig});

  final StartupConfig startupConfig;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => FinanceProvider()..loadInitial(),
      child: MaterialApp(
        title: '自由记账',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        home: _StartupHost(startupConfig: startupConfig),
      ),
    );
  }
}

class _StartupHost extends StatefulWidget {
  const _StartupHost({required this.startupConfig});

  final StartupConfig startupConfig;

  @override
  State<_StartupHost> createState() => _StartupHostState();
}

class _StartupHostState extends State<_StartupHost> {
  late bool _showSplash;

  @override
  void initState() {
    super.initState();
    _showSplash = widget.startupConfig.shouldShowSplash;
  }

  void _onSplashFinished() {
    if (!mounted) return;
    setState(() => _showSplash = false);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        return FadeTransition(opacity: animation, child: child);
      },
      child: _showSplash
          ? SplashScreen(
              key: const ValueKey('startup_splash'),
              isDaytime: widget.startupConfig.isDaytime,
              markShownOnFinish: widget.startupConfig.markShownOnFinish,
              onFinished: _onSplashFinished,
            )
          : const HomeScreen(key: ValueKey('home_screen')),
    );
  }
}
