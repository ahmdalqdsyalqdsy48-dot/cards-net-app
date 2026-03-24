import 'package:flutter/material.dart';

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
    // 💡 السطر السحري: قراءة وضع هاتف المستخدم (نهاري أم ليلي) تلقائياً 🌙☀️
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return AppBar(
      elevation: 2,
      // توحيد لون الخلفية مع لون النظام تماماً
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
      // السطر الأول (يسار): أدوات التحكم (الجرس والوضع الليلي)
      // ==========================================
      actions: [
        // زر الوضع الليلي (يتغير شكله حسب وضع الهاتف حالياً)
        IconButton(
          icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
          tooltip: 'تبديل السمة',
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('سيتم ربط هذا الزر بمحرك الثيمات لتغيير الوضع يدوياً من داخل التطبيق! 🎨')),
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
                icon: Icon(Icons.notifications_active, color: isDark ? Colors.grey.shade300 : Colors.blueAccent),
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
            // السطر الثاني: الشريط الإخباري (يتأقلم لونه مع الظلام)
            Container(
              width: double.infinity,
              color: isDark ? Colors.orange.withOpacity(0.15) : Colors.amber.shade50,
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    const Icon(Icons.campaign, size: 16, color: Colors.orange),
                    const SizedBox(width: 8),
                    Text(
                      'مرحباً بك في كروت نت! 🌟 | تحديث جديد: تم إضافة باقات يمن موبايل. | انتبه لوجود صيانة في نظام الكريمي الليلة.',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.orange.shade200 : Colors.brown),
                    ),
                  ],
                ),
              ),
            ),
            
            // السطر الثالث: حقل البحث السريع (يتأقلم لونه مع الظلام)
            Container(
              height: 38,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
              ),
              child: TextField(
                textAlignVertical: TextAlignVertical.center,
                style: TextStyle(color: isDark ? Colors.white : Colors.black), // لون النص المكتوب
                decoration: InputDecoration(
                  hintText: 'ابحث في هذا القسم...',
                  hintStyle: TextStyle(fontSize: 13, color: isDark ? Colors.grey.shade400 : Colors.grey),
                  prefixIcon: Icon(Icons.search, size: 18, color: isDark ? Colors.blue.shade300 : Colors.blueAccent),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.only(bottom: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
