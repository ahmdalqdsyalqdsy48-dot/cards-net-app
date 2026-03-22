import 'package:flutter/material.dart';

class CustomDrawer extends StatelessWidget {
  // هذه المتغيرات تسمح لنا بتغيير بيانات القائمة الجانبية بناءً على الشخص الذي سجل دخوله
  final String userName;
  final String phoneNumber;
  final String role;
  final String balanceOrPoints;
  final String? profileImageUrl;

  const CustomDrawer({
    super.key,
    required this.userName,
    required this.phoneNumber,
    required this.role,
    required this.balanceOrPoints,
    this.profileImageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // === 1. بطاقة الملف الشخصي (في أعلى القائمة الجانبية) ===
          DrawerHeader(
            decoration: BoxDecoration(
              // لون خلفية خفيف يتناسب مع الوضع الليلي والنهاري
              color: Theme.of(context).primaryColor.withOpacity(0.1),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // الصورة الشخصية أو الأيقونة الافتراضية
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Theme.of(context).primaryColor,
                  backgroundImage: profileImageUrl != null ? NetworkImage(profileImageUrl!) : null,
                  child: profileImageUrl == null 
                      ? const Icon(Icons.person, size: 35, color: Colors.white) 
                      : null,
                ),
                const SizedBox(height: 10),
                // الاسم الرباعي
                Text(
                  userName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  overflow: TextOverflow.ellipsis, // لقص النص الطويل
                ),
                const SizedBox(height: 4),
                // رقم الهاتف والدور
                Text(
                  '$phoneNumber  |  $role',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 4),
                // الرصيد / النقاط (بلون بارز)
                Text(
                  balanceOrPoints,
                  style: TextStyle(
                    fontSize: 14, 
                    fontWeight: FontWeight.bold, 
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
              ],
            ),
          ),

          // === 2. عناصر القائمة (سيتم برمجتها لاحقاً لتتغير حسب الدور) ===
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildMenuItem(context, icon: Icons.home, title: 'الرئيسية'),
                _buildMenuItem(context, icon: Icons.group, title: 'إدارة الوكلاء'),
                _buildMenuItem(context, icon: Icons.account_balance_wallet, title: 'المركز المالي'),
                _buildMenuItem(context, icon: Icons.settings, title: 'الإعدادات العامة'),
                
                const Divider(), // خط فاصل أنيق
                
                // زر تسجيل الخروج (بلون أحمر للتمييز)
                _buildMenuItem(
                  context, 
                  icon: Icons.logout, 
                  title: 'تسجيل الخروج',
                  textColor: Colors.red,
                  iconColor: Colors.red,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // دالة مساعدة لإنشاء أزرار القائمة بشكل مرتب وربطها بوظيفة الإغلاق التلقائي
  Widget _buildMenuItem(BuildContext context, {
    required IconData icon, 
    required String title,
    Color? textColor,
    Color? iconColor,
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor ?? Theme.of(context).iconTheme.color),
      title: Text(
        title, 
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: textColor ?? Theme.of(context).textTheme.bodyLarge?.color,
        ),
      ),
      onTap: () {
        // إغلاق القائمة الجانبية تلقائياً عند النقر على أي عنصر (Drawer)
        Navigator.pop(context);
        
        // ملاحظة للمبرمج: هنا سيتم إضافة كود الانتقال للقسم المختار لاحقاً
      },
    );
  }
}

