// lib/core/widgets/custom_app_bar.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:marquee/marquee.dart';

import '../providers/theme_provider.dart';
import '../providers/system_provider.dart';
import '../providers/ui_provider.dart';

class CustomAppBar extends StatefulWidget implements PreferredSizeWidget {
  final String? title;
  const CustomAppBar({super.key, this.title});

  @override
  Size get preferredSize => const Size.fromHeight(125.0);

  @override
  State<CustomAppBar> createState() => _CustomAppBarState();
}

class _CustomAppBarState extends State<CustomAppBar>
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

  void _showNotifications(BuildContext context, UiProvider uiProvider) {
    uiProvider.playSound('click');
    final List<Map<String, dynamic>> currentNotifications =
        List.from(uiProvider.unreadNotifications);

    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Row(children: [
            Icon(Icons.notifications_active, color: Colors.orange),
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
                      if (notif['type'] == 'warning') {
                        icon = Icons.warning;
                        iconColor = Colors.red;
                      }
                      if (notif['type'] == 'success') {
                        icon = Icons.check_circle;
                        iconColor = Colors.green;
                      }
                      return ListTile(
                        leading: CircleAvatar(
                            backgroundColor: iconColor.withOpacity(0.1),
                            child: Icon(icon, color: iconColor, size: 20)),
                        title: Text(notif['title'] ?? 'إشعار',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: Text(notif['body'] ?? '',
                            style: const TextStyle(fontSize: 12)),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                uiProvider.playSound('click');
                uiProvider.markNotificationsAsRead();
                Navigator.pop(context);
              },
              child: const Text('مقروء وإغلاق',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    ).then((_) => uiProvider.markNotificationsAsRead());
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final systemProvider = Provider.of<SystemProvider>(context);
    final uiProvider = Provider.of<UiProvider>(context);
    final ColorScheme colors = Theme.of(context).colorScheme;

    final bool isDark = themeProvider.isDarkMode;
    final bool isOnline = uiProvider.isOnline;
    final int notificationCount = uiProvider.unreadNotifications.length;
    final String liveNews = systemProvider.announcements.isNotEmpty
        ? systemProvider.announcements.join('   🔴   ')
        : 'مرحباً بك في نظام كروت نت...';

    // استخدام ألوان متكيفة من الثيم
    final Color headerColor = colors.primaryContainer;
    final Color onHeaderColor = colors.onPrimaryContainer;

    final Color marqueeBg = Color(systemProvider.marqueeBgColor);
    final Color marqueeTextCol = Color(systemProvider.marqueeTextColor);

    return AppBar(
      elevation: 2,
      backgroundColor: headerColor,
      iconTheme: IconThemeData(color: onHeaderColor),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.title ?? 'كروت نت',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: onHeaderColor,
                  fontSize: 18)),
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
                    spreadRadius: 1),
              ],
            ),
          ),
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
          },
        ),
        Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_active),
                tooltip: 'الإشعارات',
                color: onHeaderColor,
                onPressed: () => _showNotifications(context, uiProvider),
              ),
              if (notificationCount > 0)
                Positioned(
                  right: 8,
                  top: 10,
                  child: ScaleTransition(
                    scale: _pulseAnimation,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                          border: Border.all(color: headerColor, width: 1.5)),
                      child: Text('$notificationCount',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold)),
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
                    Icon(Icons.campaign, color: marqueeTextCol, size: 16),
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
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
              child: InkWell(
                onTap: () {
                  uiProvider.playSound('click');
                  showSearch(
                      context: context,
                      delegate: _AppSearchDelegate(uiProvider));
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  height: 35,
                  decoration: BoxDecoration(
                      color: colors.surfaceContainerHighest.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: colors.outlineVariant)),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  alignment: Alignment.centerRight,
                  child: Row(
                    children: [
                      Icon(Icons.search, size: 18, color: colors.primary),
                      const SizedBox(width: 10),
                      Text('ابحث في هذا القسم...',
                          style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant)),
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
// 🚀 محرك بحث محلي لتغطية زر البحث
// ==========================================
class _AppSearchDelegate extends SearchDelegate<String> {
  final UiProvider uiProvider;
  _AppSearchDelegate(this.uiProvider);

  final List<String> _suggestions = [
    'إعدادات الحساب',
    'الرصيد والمحفظة',
    'الدعم الفني',
    'سجل العمليات',
    'تغيير كلمة المرور'
  ];

  @override
  String get searchFieldLabel => 'اكتب للبحث...';

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
  Widget buildResults(BuildContext context) => _buildList();

  @override
  Widget buildSuggestions(BuildContext context) => _buildList();

  Widget _buildList() {
    final results =
        _suggestions.where((element) => element.contains(query)).toList();
    if (results.isEmpty)
      return const Center(
          child: Text('لا توجد نتائج مطابقة 🔍',
              style: TextStyle(color: Colors.grey)));

    return Directionality(
      textDirection: TextDirection.rtl,
      child: ListView.builder(
        itemCount: results.length,
        itemBuilder: (context, index) {
          return ListTile(
            leading: const Icon(Icons.search, color: Colors.blueGrey),
            title: Text(results[index],
                style: const TextStyle(fontWeight: FontWeight.bold)),
            onTap: () {
              uiProvider.playSound('click');
              close(context, results[index]);
            },
          );
        },
      ),
    );
  }
}
