import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/reminder_detail_screen.dart';
import 'services/notification_service.dart';
import 'services/reminder_service.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const AlertaPlusApp());
}

class AlertaPlusApp extends StatefulWidget {
  const AlertaPlusApp({
    super.key,
  });

  @override
  State<AlertaPlusApp> createState() => _AlertaPlusAppState();
}

class _AlertaPlusAppState extends State<AlertaPlusApp> with WidgetsBindingObserver {
  final _navigator = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    NotificationService.instance.selectedReminder.addListener(_openFromNotification);
    WidgetsBinding.instance.addPostFrameCallback((_) => _startNotifications());
  }

  Future<void> _startNotifications() async {
    try {
      await NotificationService.instance.initialize();
      await NotificationService.instance.refreshTimezone();
      await ReminderService.instance.restoreNotifications(force: true);
    } catch (error) {
      debugPrint('Falha ao preparar notificações: $error');
    }
  }

  Future<void> _openFromNotification() async {
    final id = NotificationService.instance.selectedReminder.value;
    if (id == null) return;
    NotificationService.instance.selectedReminder.value = null;
    final reminders = await ReminderService.instance.getReminders();
    if (!mounted) return;
    final matches = reminders.where((reminder) => reminder.id == id);
    if (matches.isNotEmpty) {
      await _navigator.currentState?.push(MaterialPageRoute<void>(
        builder: (_) => ReminderDetailScreen(reminder: matches.first),
      ));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _startNotifications();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    NotificationService.instance.selectedReminder.removeListener(_openFromNotification);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ALERTA+',
      navigatorKey: _navigator,
      theme: AppTheme.light(),
      home: kIsWeb ? const HomeScreen() : const _AppEntry(),
    );
  }
}

class _AppEntry extends StatefulWidget {
  const _AppEntry();

  @override
  State<_AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<_AppEntry> {
  static const _onboardingKey = 'alerta_plus_onboarding_complete';
  bool? _hasCompletedOnboarding;

  @override
  void initState() {
    super.initState();
    _restoreOnboardingState();
  }

  Future<void> _restoreOnboardingState() async {
    var isComplete = false;

    try {
      final preferences = await SharedPreferences.getInstance();
      isComplete = preferences.getBool(_onboardingKey) ?? false;
    } catch (_) {
      // The app still opens normally if local preferences are unavailable.
    }

    if (!mounted) return;
    setState(() => _hasCompletedOnboarding = isComplete);
  }

  Future<void> _finishOnboarding() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(_onboardingKey, true);
    } catch (_) {
      // Continue to the dashboard even if the preference cannot be persisted.
    }

    if (!mounted) return;
    setState(() => _hasCompletedOnboarding = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_hasCompletedOnboarding == null) {
      return const _LaunchScreen();
    }

    if (!_hasCompletedOnboarding!) {
      return OnboardingScreen(onFinished: _finishOnboarding);
    }

    return const HomeScreen();
  }
}

class _LaunchScreen extends StatelessWidget {
  const _LaunchScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF37358B), AppColors.primary, AppColors.primaryDark],
          ),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.alarm_rounded, color: Colors.white, size: 68),
            SizedBox(height: 22),
            Text('Alerta+', style: TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w800)),
            SizedBox(height: 10),
            Text('Mais foco. Mais leveza.', style: TextStyle(color: Color(0xFFE7E6FF), fontSize: 16)),
            SizedBox(height: 36),
            SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
          ],
        ),
      ),
    );
  }
}
