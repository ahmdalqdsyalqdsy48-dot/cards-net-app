import 'package:flutter/material.dart';

class CustomHeader extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool isOnline;

  const CustomHeader({
    super.key,
    required this.title,
    this.isOnline = true,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      elevation: 2,
      backgroundColor: Colors.white,
      iconTheme: const IconThemeData(color: Colors.blueAccent),
      centerTitle: true,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isOnline)
            const Padding(
              padding: EdgeInsets.only(left: 8.0),
              child: CircleAvatar(radius: 4, backgroundColor: Colors.green),
            ),
          Text(
            title,
            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ],
      ),
      actions: [
        // أيقونة الجرس مع النقطة الحمراء
        Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_active, color: Colors.blueAccent),
              onPressed: () {
                // سيتم استدعاء نافذة التنبيهات المنبثقة هنا
              },
            ),
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                constraints: const BoxConstraints(minWidth: 8, minHeight: 8),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
