import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:marquee/marquee.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../providers/theme_provider.dart';
import '../providers/system_provider.dart';
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
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
        CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _showNotifications(BuildContext context, UiProvider uiProvider,
      SystemProvider systemProvider) {
    uiProvider.playSound('click');
    final List<Map<String, dynamic>> currentNotifications =
        List.from(systemProvider.notifications);
    final adaptiveTextColor =
        Provider.of<ThemeProvider>(context, listen: false).adaptiveTextColor;

    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Row(children: [
            Icon(Icons.notifications_active, color: Colors.amber),
            SizedBox(width: 10),
            Text('الإشعارات الحديثة',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))
          ]),
          content: SizedBox(
            width: double.maxFinite,
            child: currentNotifications.isEmpty
                ? const Center(
                    heightFactor: 3,
                    child: Text('لا توجد إشعارات جديدة 📭',
                        style: TextStyle(color: Colors.grey)))
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: currentNotifications.length,
                    separatorBuilder: (_, __) =>
                        Divider(color: Colors.grey.shade300),
                    itemBuilder: (context, index) {
                      final notif = currentNotifications[index];
                      IconData icon = Icons.notifications;
                      Color iconColor = Colors.blue;
                      if (notif['title'].toString().contains('رفض') ||
                          notif['title'].toString().contains('طوارئ') ||
                          notif['title'].toString().contains('تحذير')) {
                        icon = Icons.warning;
                        iconColor = Colors.red;
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
                                color: adaptiveTextColor)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(notif['body'] ?? '',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: adaptiveTextColor.withOpacity(0.8))),
                            const SizedBox(height: 4),
                            Text(timeStr,
                                style: const TextStyle(
                                    fontSize: 10, color: Colors.grey)),
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
                systemProvider.markNotificationsAsRead();
                Navigator.pop(context);
              },
              child: const Text('مقروء وإغلاق',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    ).then((_) => systemProvider.markNotificationsAsRead());
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final systemProvider = Provider.of<SystemProvider>(context);
    final uiProvider = Provider.of<UiProvider>(context);

    final bool isDark = themeProvider.isDarkMode;
    final bool isOnline = uiProvider.isOnline && !systemProvider.isMaintenanceMode;

    final int unreadCount = systemProvider.unreadNotificationsCount;
    final bool hasNotifications = unreadCount > 0;

    final String liveNews = systemProvider.announcements.isNotEmpty
        ? systemProvider.announcements.join('   🔴   ')
        : 'مرحباً بك في نظام كروت نت...';

    final Color headerColor =
        Theme.of(context).appBarTheme.backgroundColor ??
            themeProvider.primaryColor;
    // ✅ لون الأيقونات ثابت وواضح في جميع الأوضاع
    final Color iconTextColor = isDark ? Colors.white : Colors.black87;
    final Color marqueeBg = Color(systemProvider.marqueeBgColor);
    final Color marqueeTextCol = Color(systemProvider.marqueeTextColor);

    return AppBar(
      elevation: 0,
      backgroundColor: headerColor,
      iconTheme: IconThemeData(color: iconTextColor),

      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.title,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: iconTextColor,
                  fontSize: 16)),
          const SizedBox(width: 8),
          Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isOnline
                      ? Colors.greenAccent.shade400
                      : Colors.redAccent,
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
                  icon: const Icon(Icons.notifications_active, color: Colors.amber),
                  tooltip: 'الإشعارات',
                  onPressed: () => _showNotifications(
                      context, uiProvider, systemProvider)),
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
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
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
            if (systemProvider.showNewsBar)
              Container(
                width: double.infinity,
                height: 25,
                color: marqueeBg,
                padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
                child: Row(
                  children: [
                    Icon(Icons.campaign, color: marqueeTextCol, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Marquee(
                        text: liveNews,
                        style: TextStyle(
                            color: marqueeTextCol,
                            fontSize: systemProvider.marqueeFontSize,
                            fontWeight: FontWeight.bold),
                        scrollAxis: Axis.horizontal,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        blankSpace: 50.0,
                        velocity: systemProvider.newsScrollSpeed,
                        pauseAfterRound: const Duration(milliseconds: 500),
                        startPadding: 10.0,
                        textDirection: systemProvider.marqueeDirection == 'rtl'
                            ? TextDirection.rtl
                            : TextDirection.ltr,
                      ),
                    ),
                  ],
                ),
              ),

            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: InkWell(
                onTap: () {
                  uiProvider.playSound('click');
                  showSearch(
                      context: context,
                      delegate: SystemSearchDelegate(uiProvider,
                          userRole: systemProvider.currentUserRole));
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  height: 35,
                  decoration: BoxDecoration(
                      color: isDark
                          ? Colors.grey.shade800
                          : Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  alignment: Alignment.centerRight,
                  child: Row(
                    children: [
                      const Icon(Icons.search, color: Colors.grey, size: 20),
                      const SizedBox(width: 10),
                      Text('ابحث في النظام...',
                          style: TextStyle(
                              color: Colors.grey.shade600, fontSize: 13)),
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
// 🚀 محرك البحث الذكي – شامل لكل الأقسام حسب الدور
// ==========================================
class SystemSearchDelegate extends SearchDelegate<String> {
  final UiProvider uiProvider;
  final String userRole;

  SystemSearchDelegate(this.uiProvider, {required this.userRole});

  Map<String, Map<String, String>> _buildSearchMap() {
    switch (userRole) {
      case 'super_admin':
        return {
          'الرئيسية (غرفة العمليات)': {'desc': 'لوحة التحكم الرئيسية', 'route': '/super_admin_dashboard'},
          'إدارة الوكلاء': {'desc': 'إضافة وتعديل وحذف الوكلاء', 'route': '/agent_management'},
          'إدارة الاشتراكات': {'desc': 'باقات وصلاحيات الوكلاء', 'route': '/subscriptions'},
          'المركز المالي والمحافظ': {'desc': 'إدارة الأرصدة والتسويات', 'route': '/financial_center'},
          'الحسابات البنكية': {'desc': 'حسابات التحويل للنظام', 'route': '/bank_accounts'},
          'التقارير الشاملة': {'desc': 'تقارير المبيعات والأرباح', 'route': '/reports'},
          'إدارة بوابات النظام': {'desc': 'تخصيص مظهر التطبيق', 'route': '/portals_management'},
          'إدارة الموظفين والدعم': {'desc': 'تذاكر الدعم والصلاحيات', 'route': '/staff_support'},
          'الإعلانات والبنرات': {'desc': 'الحملات التسويقية', 'route': '/banners'},
          'بوابة رسائل SMS': {'desc': 'إرسال الرسائل النصية', 'route': '/sms_gateway'},
          'السجل الأسود للنشاط': {'desc': 'سجل تدقيق العمليات', 'route': '/audit_log'},
          'الإعدادات العامة': {'desc': 'سياسات النظام والصيانة', 'route': '/settings'},
          'النسخ الاحتياطي': {'desc': 'حفظ واستعادة البيانات', 'route': '/backup'},
        };
      case 'agent':
        return {
          'الرئيسية (غرفة القيادة)': {'desc': 'لوحة التحكم', 'route': '/agent_dashboard'},
          'المتجر السريع (الكاشير)': {'desc': 'نقطة البيع السريعة', 'route': '/quick_pos'},
          'إدارة الفئات والميكروتك': {'desc': 'فئات وباقات الشبكات', 'route': '/mikrotik_categories'},
          'إدارة نقاط البيع (البقالات)': {'desc': 'إدارة البقالات التابعة', 'route': '/sub_agents'},
          'التسويق والعروض': {'desc': 'العروض والكوبونات', 'route': '/marketing_offers'},
          'محفظة الوكيل': {'desc': 'إدارة الحصة والتحويلات', 'route': '/agent_wallet'},
          'كشف الحساب المتقدم': {'desc': 'البيانات المالية', 'route': '/advanced_statement'},
          'التقارير التحليلية': {'desc': 'تحليلات المبيعات', 'route': '/analytics_reports'},
          'الدعم الفني الموحد': {'desc': 'تذاكر الدعم', 'route': '/agent_support'},
          'إعدادات النظام الموسعة': {'desc': 'إعدادات الحساب', 'route': '/agent_settings'},
        };
      case 'user':
      default:
        return {
          'الرئيسية': {'desc': 'لوحة المستخدم', 'route': '/user_dashboard'},
          'المحفظة الذكية والتحويلات': {'desc': 'إدارة المحفظة والتحويلات', 'route': '/user_wallet'},
          'سوق الشبكات ونقاط البيع': {'desc': 'شراء كروت الشحن', 'route': '/network_store'},
          'كروتي ومشترياتي': {'desc': 'سجل الكروت المشتراة', 'route': '/my_cards'},
          'برنامج الولاء والمكافآت': {'desc': 'المكافآت والنقاط', 'route': '/rewards'},
          'سجل العمليات المالية': {'desc': 'سجل الحركات المالية', 'route': '/user_transactions'},
          'الدعم الفني والشكاوى': {'desc': 'تذاكر الدعم', 'route': '/user_support'},
          'الملف الشخصي والإعدادات': {'desc': 'الإعدادات والمظهر', 'route': '/user_settings'},
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
            leading: const Icon(Icons.screen_search_desktop, color: Colors.blueAccent),
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
