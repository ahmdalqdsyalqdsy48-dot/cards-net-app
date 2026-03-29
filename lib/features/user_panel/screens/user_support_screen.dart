import 'package:flutter/material.dart';
import '../../../core/widgets/custom_header.dart';
// 👇 1. استدعاء القائمة الجانبية
import '../widgets/custom_user_drawer.dart';

class UserSupportScreen extends StatelessWidget {
  const UserSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomHeader(title: 'الدعم الفني'),
      // 👇 2. إرفاق القائمة بالشاشة
      drawer: const CustomUserDrawer(
        userName: 'محمد أحمد',
        phoneNumber: '777123456',
        walletBalance: 2500.0,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('كيف يمكننا مساعدتك اليوم؟ 🤝', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              const Text('اختر الطريقة الأنسب للتواصل معنا، فريقنا متواجد على مدار الساعة لخدمتك.', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 40),
              _buildSupportOption(context, Icons.chat, 'محادثة عبر واتساب', 'رد سريع خلال دقائق', Colors.green),
              _buildSupportOption(context, Icons.phone, 'اتصال هاتفي', 'للحالات الطارئة', Colors.blue),
              _buildSupportOption(context, Icons.email, 'إرسال تذكرة دعم', 'للمشاكل التقنية والمالية', Colors.purple),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSupportOption(BuildContext context, IconData icon, String title, String subtitle, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: 15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(15),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 30),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.grey)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('سيتم فتح $title... 🚀')));
        },
      ),
    );
  }
}
