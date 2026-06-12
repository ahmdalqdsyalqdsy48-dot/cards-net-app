import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:marquee/marquee.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../providers/theme_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/ui_provider.dart';

class CustomHeader extends StatefulWidget implements PreferredSizeWidget {
  final String title;
  const CustomHeader({super.key, required this.title});

  @override
  Size get preferredSize => const Size.fromHeight(125.0);

  @override
  State<CustomHeader> createState() => _CustomHeaderState();
}

class _CustomHeaderState extends State<CustomHeader>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2)
        .animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _showNotifications(BuildContext context, UiProvider uiProvider,
      NotificationProvider notificationProvider) {
    uiProvider.playSound('click');
    final List<Map<String, dynamic>> currentNotifications =
        List.from(notificationProvider.notifications);
    final ColorScheme colors = Theme.of(context).colorScheme;
    final Color onSurface = colors.onSurface;

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Row(children: [
            const Icon(Icons.notifications_active, color: Colors.amber),
            const SizedBox(width: 10),
            Text('الإشعارات الحديثة',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: onSurface))
          ]),
          content: SizedBox(
            width: double.maxFinite,
            child: currentNotifications.isEmpty
                ? Center(
                    heightFactor: 3,
                    child: Text('لا توجد إشعارات جديدة 📭',
                        style: TextStyle(color: colors.onSurfaceVariant)))
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: currentNotifications.length,
                    separatorBuilder: (_, __) =>
                        Divider(color: colors.outlineVariant),
                    itemBuilder: (context, index) {
                      final notif = currentNotifications[index];
                      IconData icon = Icons.notifications;
                      Color iconColor = colors.primary;
                      if (notif['title'].toString().contains('رفض') ||
                          notif['title'].toString().contains('طوارئ') ||
                          notif['title'].toString().contains('تحذير')) {
                        icon = Icons.warning;
                        iconColor = colors.error;
                      }
                      if (notif['title'].toString().contains('نجاح') ||
                          notif['title'].toString().contains('موافقة') ||
                          notif['title'].toString().contains('تأكيد')) {
                        icon = Icons.check_circle;
                        iconColor = Colors.green;
                      }

                      String timeStr = 'الآن';
                      if (notif['timestamp'] != null) {
                        timeStr = DateFormat('yyyy-MM-dd hh:mm a').format(
                            (notif['timestamp'] as Timestamp).toDate());
                      }

                      return ListTile(
                        leading: CircleAvatar(
                            backgroundColor: iconColor.withOpacity(0.1),
                            child: Icon(icon, color: iconColor, size: 20)),
                        title: Text(notif['title'] ?? 'إشعار',
                            style: TextStyle(
                                fontWeight: notif['isReadLocal']
                                    ? FontWeight.normal
                                    : FontWeight.bold,
                                fontSize: 14,
                                color: onSurface)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(notif['body'] ?? '',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: colors.onSurfaceVariant)),
                            const SizedBox(height: 4),
                            Text(timeStr,
                                style: TextStyle(
                                    fontSize: 10,
                                    color: colors.onSurfaceVariant)),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                uiProvider.playSound('click');
                notificationProvider.markNotificationsAsRead();
                Navigator.pop(ctx);
              },
              child: Text('مقروء وإغلاق',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: colors.primary)),
            )
          ],
        ),
      ),
    ).then((_) => notificationProvider.markNotificationsAsRead());
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final authProvider = context.watch<AuthProvider>();
    final settingsProvider = context.watch<SettingsProvider>();
    final notificationProvider = context.watch<NotificationProvider>();
    final uiProvider = context.read<UiProvider>();
    final ColorScheme colors = Theme.of(context).colorScheme;

    final bool isDark = themeProvider.isDarkMode;
    final bool isOnline =
        uiProvider.isOnline && !settingsProvider.isMaintenanceMode;

    final int unreadCount = notificationProvider.unreadNotificationsCount;
    final bool hasNotifications = unreadCount > 0;

    final String liveNews = settingsProvider.announcements.isNotEmpty
        ? settingsProvider.announcements.join('   🔴   ')
        : 'مرحباً بك في نظام كروت نت...';

    final Color headerColor = colors.primaryContainer;
    final Color onHeaderColor = colors.onPrimaryContainer;

    final Color marqueeBg = Color(settingsProvider.marqueeBgColor);
    final Color marqueeTextCol = Color(settingsProvider.marqueeTextColor);

    return AppBar(
      elevation: 0,
      backgroundColor: headerColor,
      iconTheme: IconThemeData(color: onHeaderColor),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.title,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: onHeaderColor,
                  fontSize: 16)),
          const SizedBox(width: 8),
          Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isOnline ? Colors.greenAccent.shade400 : Colors.redAccent,
                  boxShadow: [
                    BoxShadow(
                        color: isOnline
                            ? Colors.green.withOpacity(0.5)
                            : Colors.red.withOpacity(0.5),
                        blurRadius: 6,
                        spreadRadius: 1)
                  ])),
        ],
      ),
      centerTitle: true,
      actions: [
        IconButton(
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            tooltip: 'تبديل السمة',
            onPressed: () {
              uiProvider.playSound('click');
              themeProvider.toggleTheme(!isDark);
            }),
        Padding(
          padding: const EdgeInsets.only(left: 8.0, right: 8.0),
          child: Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                  icon: const Icon(Icons.notifications_active,
                      color: Colors.amber),
                  tooltip: 'الإشعارات',
                  onPressed: () =>
                      _showNotifications(context, uiProvider, notificationProvider)),
              if (hasNotifications)
                Positioned(
                  right: 8,
                  top: 10,
                  child: ScaleTransition(
                    scale: _pulseAnimation,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5)),
                      constraints:
                          const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        '$unreadCount',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: Column(
          children: [
            if (settingsProvider.showNewsBar)
              Container(
                width: double.infinity,
                height: 25,
                color: marqueeBg,
                padding:
                    const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
                child: Row(
                  children: [
                    Icon(Icons.campaign, color: marqueeTextCol, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Marquee(
                        text: liveNews,
                        style: TextStyle(
                            color: marqueeTextCol,
                            fontSize: settingsProvider.marqueeFontSize,
                            fontWeight: FontWeight.bold),
                        scrollAxis: Axis.horizontal,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        blankSpace: 50.0,
                        velocity: settingsProvider.newsScrollSpeed,
                        pauseAfterRound: const Duration(milliseconds: 500),
                        startPadding: 10.0,
                        textDirection:
                            settingsProvider.marqueeDirection == 'rtl'
                                ? TextDirection.rtl
                                : TextDirection.ltr,
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16.0, vertical: 8.0),
              child: InkWell(
                onTap: () {
                  uiProvider.playSound('click');
                  showSearch(
                      context: context,
                      delegate: SystemSearchDelegate(
                        uiProvider,
                        userRole: authProvider.currentUserRole,
                        authProvider: authProvider,
                      ));
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  height: 35,
                  decoration: BoxDecoration(
                      color: colors.surfaceContainerHighest.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  alignment: Alignment.centerRight,
                  child: Row(
                    children: [
                      Icon(Icons.search,
                          color: colors.onSurfaceVariant, size: 20),
                      const SizedBox(width: 10),
                      Text('ابحث في النظام...',
                          style: TextStyle(
                              color: colors.onSurfaceVariant, fontSize: 13)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 🚀 محرك البحث الذكي – يدعم الموظفين مع فلترة الصلاحيات
// ==========================================
class SystemSearchDelegate extends SearchDelegate<String> {
  final UiProvider uiProvider;
  final String userRole;
  final AuthProvider authProvider;

  SystemSearchDelegate(this.uiProvider, {required this.userRole, required this.authProvider});

  // 🆕 خريطة الصلاحيات (نفسها المستخدمة في CustomDrawer و SuperAdminDashboard)
  static const Map<String, List<String>> _sectionPermissions = {
    'الرئيسية (غرفة العمليات)': ['الرئيسية (غرفة العمليات)'],
    'إدارة الوكلاء': ['إدارة الوكلاء الشاملة', 'عرض الوكلاء', 'إضافة وكيل', 'تعديل وكيل', 'حذف وكيل', 'تجميد/تنشيط وكيل'],
    'إدارة الاشتراكات': ['إدارة الاشتراكات والباقات', 'عرض الاشتراكات', 'تعديل الاشتراكات'],
    'المركز المالي والمحافظ': ['المركز المالي والمحافظ', 'عرض الأرصدة', 'تسوية رصيد', 'عرض المعاملات'],
    'الحسابات البنكية': ['الحسابات البنكية', 'عرض الحسابات', 'إضافة حساب', 'تعديل حساب', 'حذف حساب'],
    'إدارة أرقام الحسابات والحظر': ['إدارة أرقام الحسابات والحظر', 'عرض الحسابات', 'تعديل رقم حساب', 'حظر/فك حظر', 'إعادة تعيين PIN'],
    'التقارير الشاملة': ['التقارير الشاملة', 'عرض التقارير'],
    'إدارة بوابات النظام': ['إدارة بوابات النظام', 'عرض البوابات', 'تعديل البوابات'],
    'إدارة الموظفين والدعم': ['إدارة الموظفين والدعم', 'عرض الموظفين', 'إضافة موظف', 'تعديل موظف', 'حذف موظف', 'تجميد/تنشيط موظف', 'عرض الرواتب', 'تعديل الرواتب', 'تسليم راتب', 'عرض التذاكر', 'الرد على التذاكر', 'إحالة التذاكر', 'إغلاق التذاكر'],
    'الإعلانات والبنرات': ['الإعلانات التسويقية', 'عرض الإعلانات', 'إضافة إعلان', 'تعديل إعلان', 'حذف إعلان'],
    'بوابة رسائل SMS': ['بوابة رسائل الـ SMS', 'عرض SMS', 'إرسال SMS'],
    'السجل الأسود للنشاط': ['السجل الأسود للنشاط (للقراءة)', 'عرض السجل'],
    'التحكم الشامل (إعادة التهيئة)': ['التحكم الشامل (إعادة التهيئة)'],
    'الإعدادات العامة': ['الإعدادات العامة', 'عرض الإعدادات', 'تعديل الإعدادات'],
    'النسخ الاحتياطي': ['النسخ الاحتياطي', 'عرض النسخ', 'أخذ نسخة', 'حذف نسخة'],
  };

  // 🆕 دالة ذكية للتحقق من صلاحية قسم (عامة أو دقيقة)
  bool _canAccessSection(String sectionName) {
    // المدير العام يرى كل شيء
    if (userRole == 'super_admin') return true;
    
    // الموظف: التحقق من الصلاحيات
    final permissions = _sectionPermissions[sectionName];
    if (permissions == null) return false;
    
    for (var perm in permissions) {
      if (authProvider.hasPermission(perm)) return true;
    }
    return false;
  }

  Map<String, Map<String, String>> _buildSearchMap() {
    // 🆕 إذا كان المستخدم مدير عام أو موظف، استخدم قائمة المدير العام مع فلترة
    if (userRole == 'super_admin' || userRole == 'staff') {
      final Map<String, Map<String, String>> adminMap = {
        'الرئيسية (غرفة العمليات)': {
          'desc': 'لوحة التحكم الرئيسية',
          'route': '/super_admin_dashboard'
        },
        'إدارة الوكلاء': {
          'desc': 'إضافة وتعديل وحذف الوكلاء',
          'route': '/agent_management'
        },
        'إدارة الاشتراكات': {
          'desc': 'باقات وصلاحيات الوكلاء',
          'route': '/subscriptions'
        },
        'المركز المالي والمحافظ': {
          'desc': 'إدارة الأرصدة والتسويات',
          'route': '/financial_center'
        },
        'الحسابات البنكية': {
          'desc': 'حسابات التحويل للنظام',
          'route': '/bank_accounts'
        },
        'إدارة أرقام الحسابات والحظر': {
          'desc': 'أرقام الحسابات والحظر',
          'route': '/admin_user_accounts'
        },
        'التقارير الشاملة': {
          'desc': 'تقارير المبيعات والأرباح',
          'route': '/reports'
        },
        'إدارة بوابات النظام': {
          'desc': 'تخصيص مظهر التطبيق',
          'route': '/portals_management'
        },
        'إدارة الموظفين والدعم': {
          'desc': 'تذاكر الدعم والصلاحيات',
          'route': '/staff_support'
        },
        'الإعلانات والبنرات': {
          'desc': 'الحملات التسويقية',
          'route': '/banners'
        },
        'بوابة رسائل SMS': {
          'desc': 'إرسال الرسائل النصية',
          'route': '/sms_gateway'
        },
        'السجل الأسود للنشاط': {
          'desc': 'سجل تدقيق العمليات',
          'route': '/audit_log'
        },
        'التحكم الشامل (إعادة التهيئة)': {
          'desc': 'فرمتة أي جزء من النظام',
          'route': '/advanced_reset'
        },
        'الإعدادات العامة': {
          'desc': 'سياسات النظام والصيانة',
          'route': '/settings'
        },
        'النسخ الاحتياطي': {
          'desc': 'حفظ واستعادة البيانات',
          'route': '/backup'
        },
      };
      
      // 🆕 فلترة النتائج حسب صلاحيات الموظف
      if (userRole == 'staff') {
        adminMap.removeWhere((sectionName, _) => !_canAccessSection(sectionName));
      }
      
      return adminMap;
    }
    
    // بقية الأدوار كما هي
    switch (userRole) {
      case 'agent':
        return {
          'الرئيسية (غرفة القيادة)': {
            'desc': 'لوحة التحكم',
            'route': '/agent_dashboard'
          },
          'المتجر السريع (الكاشير)': {
            'desc': 'نقطة البيع السريعة',
            'route': '/quick_pos'
          },
          'إدارة الفئات والميكروتك': {
            'desc': 'فئات وباقات الشبكات',
            'route': '/mikrotik_categories'
          },
          'إدارة نقاط البيع (البقالات)': {
            'desc': 'إدارة البقالات التابعة',
            'route': '/sub_agents'
          },
          'التسويق والعروض': {
            'desc': 'العروض والكوبونات',
            'route': '/marketing_offers'
          },
          'محفظة الوكيل': {
            'desc': 'إدارة الحصة والتحويلات',
            'route': '/agent_wallet'
          },
          'كشف الحساب المتقدم': {
            'desc': 'البيانات المالية',
            'route': '/advanced_statement'
          },
          'التقارير التحليلية': {
            'desc': 'تحليلات المبيعات',
            'route': '/analytics_reports'
          },
          'الدعم الفني الموحد': {
            'desc': 'تذاكر الدعم',
            'route': '/agent_support'
          },
          'إعدادات النظام الموسعة': {
            'desc': 'إعدادات الحساب',
            'route': '/agent_settings'
          },
        };
      case 'user':
      default:
        return {
          'الرئيسية': {
            'desc': 'لوحة المستخدم',
            'route': '/user_dashboard'
          },
          'المحفظة الذكية والتحويلات': {
            'desc': 'إدارة المحفظة والتحويلات',
            'route': '/user_wallet'
          },
          'سوق الشبكات ونقاط البيع': {
            'desc': 'شراء كروت الشحن',
            'route': '/network_store'
          },
          'كروتي ومشترياتي': {
            'desc': 'سجل الكروت المشتراة',
            'route': '/my_cards'
          },
          'برنامج الولاء والمكافآت': {
            'desc': 'المكافآت والنقاط',
            'route': '/rewards'
          },
          'سجل العمليات المالية': {
            'desc': 'سجل الحركات المالية',
            'route': '/user_transactions'
          },
          'الدعم الفني والشكاوى': {
            'desc': 'تذاكر الدعم',
            'route': '/user_support'
          },
          'الملف الشخصي والإعدادات': {
            'desc': 'الإعدادات والمظهر',
            'route': '/user_settings'
          },
        };
    }
  }

  @override
  String get searchFieldLabel => 'ابحث عن قسم...';

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () {
              uiProvider.playSound('click');
              query = '';
            })
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () {
          uiProvider.playSound('click');
          close(context, '');
        });
  }

  @override
  Widget buildResults(BuildContext context) => _buildSearchResults();

  @override
  Widget buildSuggestions(BuildContext context) => _buildSearchResults();

  Widget _buildSearchResults() {
    final searchMap = _buildSearchMap();
    final List<String> results = searchMap.keys
        .where((element) =>
            element.contains(query) ||
            searchMap[element]!['desc']!.contains(query))
        .toList();

    if (results.isEmpty) {
      return const Center(
          child: Text('لا توجد نتائج مطابقة لبحثك 🔍',
              style: TextStyle(fontSize: 16, color: Colors.grey)));
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: ListView.builder(
        itemCount: results.length,
        itemBuilder: (context, index) {
          String key = results[index];
          final item = searchMap[key]!;
          return ListTile(
            leading: const Icon(Icons.screen_search_desktop,
                color: Colors.blueAccent),
            title: Text(key, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(item['desc']!),
            onTap: () {
              uiProvider.playSound('click');
              close(context, key);
              _navigateToRoute(context, item['route']!);
            },
          );
        },
      ),
    );
  }

  void _navigateToRoute(BuildContext context, String route) {
    try {
      Navigator.pushNamed(context, route);
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('هذا القسم غير متاح حالياً.')),
      );
    }
  }
}
