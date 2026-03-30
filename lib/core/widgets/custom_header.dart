import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // 👈 1. استدعاء مكتبة العقل المدبر
import '../providers/theme_provider.dart'; // 👈 2. استدعاء الذاكرة التي تحفظ الألوان

class CustomHeader extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool isOnline;
  final int notificationCount;

  const CustomHeader({
    super.key,
    required this.title,
    this.isOnline = true,
    this.notificationCount = 3,
  });

  // تحديد ارتفاع الهيدر بدقة (شريط علوي + شريط إخباري + بحث)
  @override
  Size get preferredSize => const Size.fromHeight(125.0); 

  @override
  Widget build(BuildContext context) {
    // 👇 3. السطر السحري الجديد: قراءة الوضع الليلي من العقل المدبر الخاص بنا
    final themeProvider = Provider.of<ThemeProvider>(context);
    final bool isDark = themeProvider.isDarkMode;

    return AppBar(
      elevation: 2,
      // توحيد لون الخلفية
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
          // مؤشر الاتصال (النقطة الملونة)
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
        // 👇 4. زر الوضع الليلي المحدّث (يعمل الآن بشكل حقيقي!)
        IconButton(
          icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
          tooltip: 'تبديل السمة',
          onPressed: () {
            // نأمر العقل المدبر بعكس الحالة الحالية (إذا كان ليلي يجعله نهاري والعكس)
            themeProvider.toggleTheme(!isDark);
          },
        ),
        // جرس الإشعارات مع النقطة الحمراء (Badge)
        Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: Icon(Icons.notifications_active, color: isDark ? Colors.grey.shade300 : themeProvider.primaryColor),
                tooltip: 'الإشعارات',
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('لديك إشعارات جديدة غير مقروءة!')),
                  );
                },
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
      // الجزء السفلي المفقود: الشريط الإخباري وشريط البحث
      // ==========================================
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: Column(
          children: [
            // الشريط الإخباري (الأصفر)
            Container(
              width: double.infinity,
              color: Colors.orange.shade700, 
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              child: const Row(
                children: [
                  Icon(Icons.campaign, color: Colors.white, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'تم إضافة باقات يمن موبايل. | انتبه لوجود صيانة في نظام الكريمي الليلة',
                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            // شريط البحث
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Container(
                height: 35,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TextField(
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
