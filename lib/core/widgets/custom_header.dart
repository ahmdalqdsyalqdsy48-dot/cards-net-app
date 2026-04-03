import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; 
import 'package:marquee/marquee.dart'; // 👈 استدعاء مكتبة الحركة

import '../providers/theme_provider.dart'; 
import '../providers/system_provider.dart'; 

class CustomHeader extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool isOnline;
  final int notificationCount;
  final Function(String)? onSearch; 

  const CustomHeader({
    super.key,
    required this.title,
    this.isOnline = true,
    this.notificationCount = 3, 
    this.onSearch,
  });

  @override
  Size get preferredSize => const Size.fromHeight(125.0); 

  void _showNotifications(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.notifications_active, color: Colors.orange),
              SizedBox(width: 10),
              Text('الإشعارات الحديثة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                leading: Icon(Icons.download, color: Colors.blue),
                title: Text('طلب شحن جديد من "شبكة الصقر"'),
                subtitle: Text('منذ 5 دقائق'),
              ),
              Divider(color: Colors.grey.shade300),
              const ListTile(
                leading: Icon(Icons.warning, color: Colors.red),
                title: Text('رصيد "وكالة النور" وصل لحد الخطر!'),
                subtitle: Text('منذ ساعة'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق')),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final systemProvider = Provider.of<SystemProvider>(context); 
    final bool isDark = themeProvider.isDarkMode;

    // تجهيز الشريط الإخباري (دمج الأخبار مع مسافة فاصلة)
    final String liveNews = systemProvider.announcements.isNotEmpty 
        ? systemProvider.announcements.join('   🔴   ') 
        : 'مرحباً بك في نظام كروت نت...';

    return AppBar(
      elevation: 2,
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
      iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.blueAccent),
      
      // ==========================================
      // السطر الأول: العنوان ومؤشر الاتصال
      // ==========================================
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.blue.shade900,
              fontSize: 16,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isOnline ? Colors.greenAccent.shade400 : Colors.redAccent,
              boxShadow: [
                BoxShadow(
                  color: isOnline ? Colors.green.withOpacity(0.5) : Colors.red.withOpacity(0.5),
                  blurRadius: 6,
                  spreadRadius: 1,
                )
              ],
            ),
          ),
        ],
      ),
      centerTitle: true,

      // ==========================================
      // السطر الأول (يسار): أدوات التحكم
      // ==========================================
      actions: [
        IconButton(
          icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
          tooltip: 'تبديل السمة',
          onPressed: () {
            themeProvider.toggleTheme(!isDark);
          },
        ),
        Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: Icon(Icons.notifications_active, color: isDark ? Colors.grey.shade300 : themeProvider.primaryColor),
                tooltip: 'الإشعارات',
                onPressed: () => _showNotifications(context), 
              ),
              if (notificationCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$notificationCount',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],

      // ==========================================
      // الجزء السفلي: الشريط الإخباري وشريط البحث
      // ==========================================
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: Column(
          children: [
            // 👈 الشريط الإخباري المتحرك الجديد
            Container(
              width: double.infinity,
              height: 25, // تحديد ارتفاع ثابت ضروري لحركة الـ Marquee
              color: Colors.orange.shade700, 
              padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
              child: Row(
                children: [
                  const Icon(Icons.campaign, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Marquee(
                      text: liveNews,
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      scrollAxis: Axis.horizontal,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      blankSpace: 50.0, // المسافة بين نهاية الخبر وبدايته عند التكرار
                      velocity: systemProvider.newsScrollSpeed, // 👈 السرعة المرتبطة بالعقل المدبر
                      pauseAfterRound: const Duration(milliseconds: 500), // توقف بسيط قبل إعادة الشريط
                      startPadding: 10.0,
                      textDirection: TextDirection.rtl, // 👈 يظهر من اليسار ويختفي في اليمين كما طلبت
                    ),
                  ),
                ],
              ),
            ),
            
            // شريط البحث الديناميكي
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Container(
                height: 35,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TextField(
                  onChanged: onSearch, 
                  decoration: InputDecoration(
                    hintText: 'ابحث في هذا القسم...',
                    hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                    prefixIcon: Icon(Icons.search, color: themeProvider.primaryColor, size: 20),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
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
