import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; 
import 'package:marquee/marquee.dart'; 

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

class _CustomHeaderState extends State<CustomHeader> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _showNotifications(BuildContext context, UiProvider uiProvider) {
    final List<Map<String, dynamic>> currentNotifications = List.from(uiProvider.unreadNotifications);

    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Row(children: [Icon(Icons.notifications_active, color: Colors.orange), SizedBox(width: 10), Text('الإشعارات الحديثة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))]),
          content: SizedBox(
            width: double.maxFinite,
            child: currentNotifications.isEmpty
                ? const Center(heightFactor: 3, child: Text('لا توجد إشعارات جديدة 📭', style: TextStyle(color: Colors.grey)))
                : ListView.separated(
                    shrinkWrap: true, itemCount: currentNotifications.length, separatorBuilder: (_, __) => Divider(color: Colors.grey.shade300),
                    itemBuilder: (context, index) {
                      final notif = currentNotifications[index];
                      IconData icon = Icons.notifications; Color iconColor = Colors.blue;
                      if (notif['type'] == 'warning') { icon = Icons.warning; iconColor = Colors.red; }
                      if (notif['type'] == 'success') { icon = Icons.check_circle; iconColor = Colors.green; }
                      return ListTile(leading: Icon(icon, color: iconColor), title: Text(notif['title'] ?? 'إشعار', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)), subtitle: Text(notif['body'] ?? ''));
                    },
                  ),
          ),
          actions: [TextButton(onPressed: () { uiProvider.markNotificationsAsRead(); Navigator.pop(context); }, child: const Text('إغلاق'))],
        ),
      ),
    ).then((_) => uiProvider.markNotificationsAsRead());
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final systemProvider = Provider.of<SystemProvider>(context); 
    final uiProvider = Provider.of<UiProvider>(context); 
    
    final bool isDark = themeProvider.isDarkMode;
    final bool isOnline = uiProvider.isOnline; 
    final bool hasNotifications = uiProvider.hasNewNotifications; 
    final String liveNews = systemProvider.announcements.isNotEmpty ? systemProvider.announcements.join('   🔴   ') : 'مرحباً بك في نظام كروت نت...';

    // 👈 اللون الذكي: الهيدر يأخذ لون الواجهة، والأيقونات والنصوص تأخذ لوناً معاكساً لضمان الوضوح
    final Color headerColor = isDark ? const Color(0xFF121212) : themeProvider.primaryColor;
    final Color iconTextColor = isDark ? Colors.white : themeProvider.adaptiveTextColor;

    // قراءة ألوان الشريط المتحرك من الإعدادات (لتتحكم بها لاحقاً من قسم البنرات)
    final Color marqueeBg = Color(systemProvider.marqueeBgColor);
    final Color marqueeTextCol = Color(systemProvider.marqueeTextColor);

    return AppBar(
      elevation: 0, // إزالة الظل ليندمج الهيدر
      backgroundColor: headerColor, 
      iconTheme: IconThemeData(color: iconTextColor), // الأيقونات تتكيف ذكياً
      
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.title, style: TextStyle(fontWeight: FontWeight.bold, color: iconTextColor, fontSize: 16)),
          const SizedBox(width: 8),
          Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: isOnline ? Colors.greenAccent.shade400 : Colors.redAccent, boxShadow: [BoxShadow(color: isOnline ? Colors.green.withOpacity(0.5) : Colors.red.withOpacity(0.5), blurRadius: 6, spreadRadius: 1)])),
        ],
      ),
      centerTitle: true,
      actions: [
        IconButton(icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode), tooltip: 'تبديل السمة', onPressed: () => themeProvider.toggleTheme(!isDark)),
        Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: Stack(
            alignment: Alignment.center,
            children: [
              IconButton(icon: const Icon(Icons.notifications_active), color: iconTextColor, tooltip: 'الإشعارات', onPressed: () => _showNotifications(context, uiProvider)),
              if (hasNotifications)
                Positioned(right: 8, top: 10, child: ScaleTransition(scale: _pulseAnimation, child: Container(width: 10, height: 10, decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5))))),
            ],
          ),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: Column(
          children: [
            // 👈 الشريط المتحرك (يقرأ إعداداته من النظام ليتوافق مع شاشة الإعلانات لاحقاً)
            if (systemProvider.showNewsBar)
              Container(
                width: double.infinity, height: 25, color: marqueeBg, padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
                child: Row(
                  children: [
                    Icon(Icons.campaign, color: marqueeTextCol, size: 18), const SizedBox(width: 8),
                    Expanded(
                      child: Marquee(
                        text: liveNews, 
                        style: TextStyle(color: marqueeTextCol, fontSize: systemProvider.marqueeFontSize, fontWeight: FontWeight.bold), 
                        scrollAxis: Axis.horizontal, 
                        crossAxisAlignment: CrossAxisAlignment.center, 
                        blankSpace: 50.0, 
                        velocity: systemProvider.newsScrollSpeed, 
                        pauseAfterRound: const Duration(milliseconds: 500), 
                        startPadding: 10.0, 
                        textDirection: systemProvider.marqueeDirection == 'rtl' ? TextDirection.rtl : TextDirection.ltr
                      )
                    ),
                  ],
                ),
              ),
            
            // 👈 زر البحث (يفتح نافذة البحث الذكية)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: InkWell(
                onTap: () {
                  showSearch(context: context, delegate: SystemSearchDelegate());
                },
                child: Container(
                  height: 35, 
                  decoration: BoxDecoration(color: isDark ? Colors.grey.shade800 : Colors.white.withOpacity(0.9), borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  alignment: Alignment.centerRight,
                  child: Row(
                    children: [
                      const Icon(Icons.search, color: Colors.grey, size: 20),
                      const SizedBox(width: 10),
                      Text('ابحث في النظام...', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
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
// 🚀 محرك البحث الذكي للنظام (Search Delegate)
// ==========================================
class SystemSearchDelegate extends SearchDelegate<String> {
  // خريطة للأقسام والكلمات الدلالية لسهولة التوجيه لاحقاً
  final Map<String, String> searchMap = {
    'المركز المالي': 'إدارة الأموال والأرباح',
    'التقارير': 'التقارير الشاملة والتحليلات',
    'الوكلاء': 'إدارة الوكلاء والمستخدمين',
    'ميكروتيك': 'فئات وباقات شبكات الميكروتيك',
    'المبيعات': 'نقطة البيع السريعة',
    'رسائل': 'بوابة الـ SMS والإشعارات',
    'إعدادات': 'الإعدادات العامة للمظهر والسياسات',
    'إعلانات': 'إدارة الإعلانات والبنرات التسويقية',
    'النسخ الاحتياطي': 'حفظ واستعادة البيانات',
  };

  @override
  String get searchFieldLabel => 'اكتب للبحث...';

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(icon: const Icon(Icons.clear), onPressed: () => query = '')
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => close(context, ''));
  }

  @override
  Widget buildResults(BuildContext context) => _buildSearchResults();

  @override
  Widget buildSuggestions(BuildContext context) => _buildSearchResults();

  Widget _buildSearchResults() {
    final List<String> results = searchMap.keys.where((element) => element.contains(query) || searchMap[element]!.contains(query)).toList();

    if (results.isEmpty) {
      return const Center(child: Text('لا توجد نتائج مطابقة لبحثك 🔍', style: TextStyle(fontSize: 16, color: Colors.grey)));
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: ListView.builder(
        itemCount: results.length,
        itemBuilder: (context, index) {
          String key = results[index];
          return ListTile(
            leading: const Icon(Icons.screen_search_desktop, color: Colors.blueAccent),
            title: Text(key, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(searchMap[key]!),
            onTap: () {
              close(context, key);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('سيتم نقلك إلى قسم: $key', textDirection: TextDirection.rtl), backgroundColor: Colors.green));
              // يمكننا لاحقاً برمجة عملية النقل (Navigator) بناءً على الـ key المختار
            },
          );
        },
      ),
    );
  }
}
