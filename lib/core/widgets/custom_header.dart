import 'package:flutter/material.dart';

class CustomHeader extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool isOnline;
  final int notificationCount;
  final bool isDarkMode;

  const CustomHeader({
    super.key,
    required this.title, // هنا نطلب العنوان ليتغير في كل شاشة
    this.isOnline = true,
    this.notificationCount = 3,
    this.isDarkMode = false,
  });

  // تحديد ارتفاع الهيدر بدقة (شريط علوي + شريط إخباري + بحث)
  @override
  Size get preferredSize => const Size.fromHeight(125.0); 

  @override
  Widget build(BuildContext context) {
    return AppBar(
      elevation: 2,
      backgroundColor: isDarkMode ? Colors.grey.shade900 : Colors.white,
      iconTheme: IconThemeData(color: isDarkMode ? Colors.white : Colors.blueAccent),
      
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
              color: isDarkMode ? Colors.white : Colors.blue.shade900,
              fontSize: 16, // تصغير الخط قليلاً للأناقة
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
      // السطر الأول (يسار): أدوات التحكم (الجرس والوضع الليلي)
      // ==========================================
      actions: [
        // زر الوضع الليلي
        IconButton(
          icon: Icon(isDarkMode ? Icons.light_mode : Icons.dark_mode),
          tooltip: 'تبديل السمة',
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('سيتم تفعيل الوضع الليلي قريباً.')),
            );
          },
        ),
        // جرس الإشعارات مع النقطة الحمراء (Badge)
        Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_active),
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
      // السطر الثاني والثالث: الشريط الإخباري وحقل البحث
      // ==========================================
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: Column(
          children: [
            // السطر الثاني: الشريط الإخباري (Marquee)
            Container(
              width: double.infinity,
              color: Colors.amber.shade50,
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: const [
                    Icon(Icons.campaign, size: 16, color: Colors.orange),
                    SizedBox(width: 8),
                    Text(
                      'مرحباً بك في كروت نت! 🌟 | تحديث جديد: تم إضافة باقات يمن موبايل. | انتبه لوجود صيانة في نظام الكريمي الليلة.',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.brown),
                    ),
                  ],
                ),
              ),
            ),
            
            // السطر الثالث: حقل البحث السريع
            Container(
              height: 38,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: const TextField(
                textAlignVertical: TextAlignVertical.center,
                decoration: InputDecoration(
                  hintText: 'ابحث في هذا القسم...',
                  hintStyle: TextStyle(fontSize: 13, color: Colors.grey),
                  prefixIcon: Icon(Icons.search, size: 18, color: Colors.blueAccent),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.only(bottom: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
