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

    // 👈 الألوان الذكية (إذا كان الهيدر أبيض، فالأيقونات والنصوص سوداء والعكس صحيح)
    final Color headerColor = isDark ? const Color(0xFF121212) : themeProvider.primaryColor;
    final Color iconTextColor = isDark ? Colors.white : themeProvider.adaptiveTextColor;

    return AppBar(
      elevation: 2, 
      shadowColor: Colors.black12,
      backgroundColor: headerColor, 
      iconTheme: IconThemeData(color: iconTextColor), 
      
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
            // 👈 شريط الأخبار العلوي المتحرك
            Container(
              width: double.infinity, height: 25, color: Colors.orange.shade700, padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
              child: Row(
                children: [
                  const Icon(Icons.campaign, color: Colors.white, size: 18), const SizedBox(width: 8),
                  Expanded(child: Marquee(text: liveNews, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold), scrollAxis: Axis.horizontal, crossAxisAlignment: CrossAxisAlignment.center, blankSpace: 50.0, velocity: systemProvider.newsScrollSpeed, pauseAfterRound: const Duration(milliseconds: 500), startPadding: 10.0, textDirection: TextDirection.rtl)),
                ],
              ),
            ),
            // 👈 مربع البحث الذكي
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Container(
                height: 35, 
                decoration: BoxDecoration(color: isDark ? Colors.grey.shade800 : Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
                child: TextField(
                  readOnly: true, // نجعله للقراءة فقط ليفتح نافذة البحث عند النقر
                  onTap: () {
                     showSearch(context: context, delegate: SystemSearchDelegate());
                  },
                  style: const TextStyle(color: Colors.black87), 
                  decoration: const InputDecoration(
                    hintText: 'ابحث في أقسام النظام...', 
                    hintStyle: TextStyle(color: Colors.grey, fontSize: 13), 
                    prefixIcon: Icon(Icons.search, color: Colors.blueAccent, size: 20), 
                    border: InputBorder.none, 
                    contentPadding: EdgeInsets.symmetric(vertical: 8)
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
  // خريطة لأهم الأقسام والكلمات الدلالية
  final Map<String, String> searchMap = {
    'المركز المالي': 'إدارة الأموال والأرباح',
    'التقارير': 'التقارير الشاملة والتحليلات',
    'الوكلاء': 'إدارة الوكلاء',
    'ميكروتيك': 'فئات كروت ميكروتيك',
    'المبيعات': 'نقطة البيع السريعة',
    'رسائل': 'بوابة الـ SMS',
    'إعدادات': 'الإعدادات العامة والمظهر',
    'إعلانات': 'إدارة الإعلانات والبنرات',
    'النسخ الاحتياطي': 'حفظ البيانات',
  };

  @override
  String get searchFieldLabel => 'اكتب اسم القسم للبحث...';

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
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
    final List<String> results = searchMap.keys.where((element) => element.contains(query)).toList();

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
            leading: const Icon(Icons.location_on, color: Colors.blueAccent),
            title: Text(key, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(searchMap[key]!),
            onTap: () {
              // هنا يتم التوجيه بناءً على القسم المختار
              close(context, key);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('سيتم نقلك إلى قسم: $key', textDirection: TextDirection.rtl), backgroundColor: Colors.green));
              // ملاحظة: يمكنك لاحقاً ربط كل ضغطة بـ Navigator.push للشاشة المعنية
            },
          );
        },
      ),
    );
  }
}
