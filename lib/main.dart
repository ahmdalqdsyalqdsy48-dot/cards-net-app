import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/providers/theme_provider.dart';
import 'core/providers/system_provider.dart';
import 'core/providers/auth_provider.dart';
import 'core/providers/settings_provider.dart';
import 'core/providers/wallet_provider.dart';
import 'core/providers/notification_provider.dart';
import 'core/providers/backup_provider.dart';
import 'core/providers/coupon_provider.dart';
import 'core/providers/audit_provider.dart';
import 'core/providers/agent_admin_provider.dart';
import 'core/providers/ui_provider.dart';

import 'features/auth/screens/sso_login_screen.dart';

// استيراد الشاشات الأساسية لتعريف المسارات
import 'features/super_admin/screens/super_admin_dashboard.dart';
import 'features/super_admin/screens/agent_management_screen.dart';
import 'features/super_admin/screens/subscriptions_screen.dart';
import 'features/super_admin/screens/financial_center_screen.dart';
import 'features/super_admin/screens/bank_accounts_screen.dart';
import 'features/super_admin/screens/reports_screen.dart';
import 'features/super_admin/screens/portals_management_screen.dart';
import 'features/super_admin/screens/staff_support_screen.dart';
import 'features/super_admin/screens/banners_screen.dart';
import 'features/super_admin/screens/sms_gateway_screen.dart';
import 'features/super_admin/screens/audit_log_screen.dart';
import 'features/super_admin/screens/settings_screen.dart';
import 'features/super_admin/screens/backup_screen.dart';
import 'features/super_admin/screens/admin_user_accounts_screen.dart';

import 'features/agent_panel/screens/agent_dashboard_screen.dart';
import 'features/agent_panel/screens/quick_pos_screen.dart';
import 'features/agent_panel/screens/mikrotik_categories_screen.dart';
import 'features/agent_panel/screens/sub_agents_screen.dart';
import 'features/agent_panel/screens/marketing_offers_screen.dart';
import 'features/agent_panel/screens/agent_wallet_screen.dart';
import 'features/agent_panel/screens/advanced_statement_screen.dart';
import 'features/agent_panel/screens/analytics_reports_screen.dart';
import 'features/agent_panel/screens/agent_support_screen.dart';
import 'features/agent_panel/screens/agent_settings_screen.dart';

import 'features/user_panel/screens/user_dashboard_screen.dart';
import 'features/user_panel/screens/user_wallet_screen.dart';
import 'features/user_panel/screens/network_store_screen.dart';
import 'features/user_panel/screens/my_cards_screen.dart';
import 'features/user_panel/screens/rewards_screen.dart';
import 'features/user_panel/screens/user_transactions_screen.dart';
import 'features/user_panel/screens/user_support_screen.dart';
import 'features/user_panel/screens/user_settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyDdZzU6VXrmmk9Ul99GTN5RLtza95tLkVE",
      authDomain: "netcardsapp.firebaseapp.com",
      projectId: "netcardsapp",
      storageBucket: "netcardsapp.firebasestorage.app",
      messagingSenderId: "100057914511",
      appId: "1:100057914511:web:75b015601ca5cb836724fa",
      measurementId: "G-4MDY84TCRQ",
    ),
  );

  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  final prefs = await SharedPreferences.getInstance();
  final String savedLang = prefs.getString('language') ?? 'en';

  runApp(
    MultiProvider(
      providers: [
        // --- المزودات المستقلة ---
        ChangeNotifierProvider(create: (context) => ThemeProvider()),
        ChangeNotifierProvider(create: (context) => AuthProvider()),
        ChangeNotifierProvider(create: (context) => SettingsProvider()),

        // --- المزودات التي تعتمد على غيرها ---
        ChangeNotifierProvider<WalletProvider>(
          create: (context) {
            final auth = context.read<AuthProvider>();
            final settings = context.read<SettingsProvider>();
            return WalletProvider(auth, settings: settings);
          },
        ),
        ChangeNotifierProvider<NotificationProvider>(
          create: (context) => NotificationProvider(context.read<AuthProvider>()),
        ),
        ChangeNotifierProvider<AgentAdminProvider>(
          create: (context) {
            final auth = context.read<AuthProvider>();
            final wallet = context.read<WalletProvider>();
            return AgentAdminProvider(auth, wallet);
          },
        ),

        // --- المزودات المستقلة المتبقية ---
        ChangeNotifierProvider(create: (context) => BackupProvider()),
        ChangeNotifierProvider(create: (context) => CouponProvider()),
        ChangeNotifierProvider(create: (context) => AuditProvider()),

        // --- القديم (مؤقت) ---
        ChangeNotifierProvider(create: (context) => SystemProvider()),
        ChangeNotifierProxyProvider<SystemProvider, UiProvider>(
          create: (context) => UiProvider(null),
          update: (context, systemProvider, previous) => UiProvider(
            systemProvider.currentUserPhone == 'لا يوجد رقم'
                ? null
                : systemProvider.currentUserPhone,
          ),
        ),
      ],
      child: MyApp(initialLang: savedLang),
    ),
  );
}

class MyApp extends StatefulWidget {
  final String initialLang;
  const MyApp({super.key, required this.initialLang});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late String _currentLang;

  @override
  void initState() {
    super.initState();
    _currentLang = widget.initialLang;
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    // ما زلنا نقرأ اللغة من SystemProvider مؤقتاً
    final systemProvider = Provider.of<SystemProvider>(context);
    final settingsProvider = Provider.of<SettingsProvider>(context);

    // محاولة قراءة اللغة من SettingsProvider أولاً
    final newLang = settingsProvider.getLanguageSync();
    if (newLang != _currentLang) {
      _currentLang = newLang;
    }

    return MaterialApp(
      title: settingsProvider.appName,
      debugShowCheckedModeBanner: false,
      locale: Locale(_currentLang),
      supportedLocales: const [Locale('en'), Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      localeResolutionCallback: (locale, supportedLocales) {
        if (locale == null) return const Locale('en');
        for (var supportedLocale in supportedLocales) {
          if (supportedLocale.languageCode == locale.languageCode) {
            return supportedLocale;
          }
        }
        return const Locale('en');
      },
      themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      theme: themeProvider.lightTheme,
      darkTheme: themeProvider.darkTheme,

      routes: {
        '/super_admin_dashboard': (context) => const SuperAdminDashboard(),
        '/agent_management': (context) => const AgentManagementScreen(),
        '/subscriptions': (context) => const SubscriptionsScreen(),
        '/financial_center': (context) => const FinancialCenterScreen(),
        '/bank_accounts': (context) => const BankAccountsScreen(),
        '/reports': (context) => const ReportsScreen(),
        '/portals_management': (context) => const PortalsManagementScreen(),
        '/staff_support': (context) => const StaffSupportScreen(),
        '/banners': (context) => const BannersScreen(),
        '/sms_gateway': (context) => const SmsGatewayScreen(),
        '/audit_log': (context) => const AuditLogScreen(),
        '/settings': (context) => const GlobalSettingsScreen(),
        '/backup': (context) => const BackupScreen(),
        '/admin_user_accounts': (context) => const AdminUserAccountsScreen(),

        '/agent_dashboard': (context) => const AgentDashboardScreen(),
        '/quick_pos': (context) => const QuickPosScreen(),
        '/mikrotik_categories': (context) => const MikrotikCategoriesScreen(),
        '/sub_agents': (context) => const SubAgentsScreen(),
        '/marketing_offers': (context) => const MarketingOffersScreen(),
        '/agent_wallet': (context) => const AgentWalletScreen(),
        '/advanced_statement': (context) => const AdvancedStatementScreen(),
        '/analytics_reports': (context) => const AnalyticsReportsScreen(),
        '/agent_support': (context) => const AgentSupportScreen(),
        '/agent_settings': (context) => const AgentSettingsScreen(),

        '/user_dashboard': (context) => const UserDashboardScreen(),
        '/user_wallet': (context) => const UserWalletScreen(),
        '/network_store': (context) => const NetworkStoreScreen(),
        '/my_cards': (context) => const MyCardsScreen(),
        '/rewards': (context) => const RewardsScreen(),
        '/user_transactions': (context) => const UserTransactionsScreen(),
        '/user_support': (context) => const UserSupportScreen(),
        '/user_settings': (context) => const UserSettingsScreen(),
      },

      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(themeProvider.fontSizeScale),
          ),
          child: child!,
        );
      },
      home: const SSOLoginScreen(),
    );
  }
}
