import 'package:flutter/material.dart';

// نستخدم PreferredSizeWidget لأننا نصمم شريط علوي (AppBar) مخصص
class CustomHeader extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool isOnline;

  const CustomHeader({
    super.key,
    required this.title,
    this.isOnline = true, // افتراضياً يكون متصلاً (نقطة خضراء)
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      // === السطر الأول: شريط الأدوات ===
      centerTitle: true,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(width: 8),
          // النقطة الملونة لحالة الاتصال
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isOnline ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
      actions: [
        // زر تبديل الوضع الليلي
        IconButton(
          icon: const Icon(Icons.dark_mode),
          onPressed: () {
            // سيتم برمجة التبديل لاحقاً
          },
        ),
        // زر الإشعارات مع النقطة الحمراء
        Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.notifications),
              onPressed: () {
                // سيتم برمجة فتح الإشعارات لاحقاً
              },
            ),
            Positioned(
              right: 12,
              top: 12,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(6),
                ),
                constraints: const BoxConstraints(minWidth: 10, minHeight: 10),
              ),
            ),
          ],
        ),
      ],
      // زر القائمة الجانبية (يظهر تلقائياً في اليمين لأن التطبيق RTL)
      
      // === السطر الثاني والثالث ===
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(90), // ارتفاع السطرين
        child: Column(
          children: [
            // السطر الثاني: الشريط المتحرك (Marquee Placeholder)
            Container(
              width: double.infinity,
              color: Colors.amber.withOpacity(0.3),
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: const Text(
                'شريط الأخبار العاجلة أو الترحيب يمر من هنا...',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
            // السطر الثالث: حقل البحث الشامل
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              child: SizedBox(
                height: 40,
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'ابحث في هذا القسم...',
                    prefixIcon: const Icon(Icons.search),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none, // إخفاء الحدود العادية
                    ),
                    filled: true,
                    fillColor: Theme.of(context).scaffoldBackgroundColor, // لون يتناسب مع الوضع الليلي/النهاري
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // تحديد الارتفاع الكلي للهيدر (شريط الأدوات + السطرين الإضافيين)
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 90);
}
