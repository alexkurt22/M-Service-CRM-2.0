import 'dart:io' show Platform, File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart'; 
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'package:firebase_messaging/firebase_messaging.dart';

import 'firebase_options.dart';
import 'screens/dashboard_screen.dart'; 
import 'screens/login_screen.dart'; 
import 'screens/settings_screen.dart'; 
import 'screens/orders_screen.dart';
import 'screens/chat_lists_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    
    await Firebase.initializeApp(
      options: (kIsWeb || Platform.isWindows) 
          ? DefaultFirebaseOptions.web 
          : DefaultFirebaseOptions.currentPlatform,
    );

    final prefs = await SharedPreferences.getInstance();
    final savedPhone = prefs.getString('employee_phone');
    final bool isDarkSaved = prefs.getBool('is_dark_mode') ?? false;

    Widget startScreen = const LoginScreen();

    // Защита от вечного зависания: даем базе ровно 5 секунд на ответ
    if (savedPhone != null && savedPhone.isNotEmpty) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('employees')
            .doc(savedPhone)
            .get()
            .timeout(const Duration(seconds: 5));
            
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>? ?? {};
          if (data['is_approved'] == true) {
            startScreen = const DashboardScreen();
          }
        }
      } catch (e) {
        debugPrint('Ошибка сессии при запуске: $e');
        // Если нет интернета, просто выкинет на LoginScreen
      }
    }

    runApp(MyApp(startScreen: startScreen, initialDarkMode: isDarkSaved));

  } catch (e, stackTrace) {
    if (!kIsWeb && Platform.isWindows) {
      File('crash_log.txt').writeAsStringSync('CRASH: $e\n\n$stackTrace');
    }
    
    runApp(MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.red[900],
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Text(
            'КРИТИЧЕСКАЯ ОШИБКА ЗАПУСКА:\n\n$e\n\n$stackTrace',
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
        ),
      ),
    ));
  }
}

class MyApp extends StatefulWidget {
  final Widget startScreen;
  final bool initialDarkMode;

  const MyApp({super.key, required this.startScreen, required this.initialDarkMode});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late bool _isDarkMode;

  @override
  void initState() {
    super.initState();
    _isDarkMode = widget.initialDarkMode;
    _setupPushRouting(); 
  }

  Future<void> _setupPushRouting() async {
    if (!kIsWeb && Platform.isWindows) return;

    try {
      RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        _handlePushMessage(initialMessage);
      }
      FirebaseMessaging.onMessageOpenedApp.listen(_handlePushMessage);
    } catch (e) {
      debugPrint('Ошибка Push: $e');
    }
  }

  void _handlePushMessage(RemoteMessage message) {
    final type = message.data['type'];
    if (type == 'chat') {
      navigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => const TeamChatsListScreen()));
    } else if (type == 'negotiation') {
      navigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => const OrdersScreen(status: 'awaiting_approval', title: 'Ожидают ответа')));
    } else if (type == 'new_order') {
      navigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => const OrdersScreen(status: 'new', title: 'Новые заказы')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false, 
      title: 'M-Service CRM',
      theme: ThemeData(brightness: Brightness.light, useMaterial3: true),
      darkTheme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: widget.startScreen,
    );
  }
}
