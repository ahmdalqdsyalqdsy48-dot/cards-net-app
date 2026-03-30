import 'package:flutter/material.dart';
import '../../../core/widgets/custom_header.dart';
// 👇 1. استدعاء القائمة الجانبية
import '../widgets/custom_user_drawer.dart';

// 👇 2. تحويل الكلاس إلى StatefulWidget لكي نتمكن من إضافة نوافذ تفاعلية (مثل إرسال تذكرة)
class UserSupportScreen extends StatefulWidget {
  const UserSupportScreen({super.key});

  @override
  State<UserSupportScreen> createState() => _UserSupportScreenState();
}

class _UserSupportScreenState extends State<UserSupportScreen> {

  // ==========================================
  // دالة لفتح نافذة إرسال تذكرة دعم فني 📝
  // ==========================================
  void _showTicketDialog(BuildContext context) {
    // متحكم (Controller) لقراءة النص الذي سيكتبه المستخدم
    final TextEditingController ticketController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl, // دعم اللغة العربية
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.support_agent, color: Colors.purple),
              SizedBox(width: 10),
              Text('إرسال تذكرة دعم', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('يرجى وصف المشكلة التي تواجهك بدقة، وسنقوم بالرد عليك في أقرب وقت ممكن.', style: TextStyle(fontSize: 13, color: Colors.blueGrey)),
              const SizedBox(height: 15),
              TextField(
                controller: ticketController,
                maxLines: 4, // جعل مربع النص كبيراً ليسمح بكتابة تفاصيل المشكلة
                decoration: InputDecoration(
                  hintText: 'اكتب تفاصيل المشكلة هنا...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
              ),
            ],
          ),
          actions: [
            // زر الإلغاء
            TextButton(
              onPressed: () => Navigator.pop(context), 
              child: const Text('إلغاء', style: TextStyle(color: Colors.grey))
            ),
            // زر الإرسال
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
              ),
              onPressed: () {
                // التحقق من أن المستخدم كتب شيئاً قبل الإرسال
                if (ticketController.text.trim().isNotEmpty) {
                  Navigator.pop(context); // إغلاق النافذة
                  // إظهار رسالة نجاح للمستخدم
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تم إرسال تذكرتك بنجاح! سنتواصل معك قريباً ✅', textDirection: TextDirection.rtl),
                      backgroundColor: Colors.green,
                    )
                  );
                } else {
                  // تنبيه المستخدم إذا ترك الحقل فارغاً
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('يرجى كتابة تفاصيل المشكلة أولاً! ❌', textDirection: TextDirection.rtl),
                      backgroundColor: Colors.red,
                    )
                  );
                }
              },
              icon: const Icon(Icons.send, color: Colors.white, size: 18),
              label: const Text('إرسال التذكرة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomHeader(title: 'الدعم الفني والشكاوى'),
      // 👇 3. تم تنظيف القائمة الجانبية وإزالة سطر الرصيد المتعارض لتعمل بأمان
      drawer: const CustomUserDrawer(
        userName: 'محمد أحمد',
        phoneNumber: '777123456',
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SingleChildScrollView( // لتجنب مشكلة الشاشات الصغيرة
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // صورة أو أيقونة ترحيبية تعطي لمسة جمالية
              Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.headset_mic, size: 80, color: Colors.blue.shade800),
                ),
              ),
              const SizedBox(height: 20),
              const Text('كيف يمكننا مساعدتك اليوم؟ 🤝', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              const Text('اختر الطريقة الأنسب للتواصل معنا، فريقنا متواجد على مدار الساعة لخدمتك وحل أي مشكلة تواجهك.', style: TextStyle(color: Colors.grey, height: 1.5)),
              const SizedBox(height: 40),
              
              // 👇 4. ربط الأزرار بالوظائف (Functions)
              _buildSupportOption(
                context, 
                Icons.chat, 
                'محادثة عبر واتساب', 
                'رد سريع خلال دقائق', 
                Colors.green,
                () {
                  // هنا سيتم إضافة كود فتح واتساب الحقيقي لاحقاً
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('جاري تحويلك إلى تطبيق واتساب... 💬', textDirection: TextDirection.rtl), backgroundColor: Colors.green));
                }
              ),
              
              _buildSupportOption(
                context, 
                Icons.phone, 
                'اتصال هاتفي بالدعم', 
                'للحالات الطارئة والمستعجلة', 
                Colors.blue,
                () {
                  // هنا سيتم إضافة كود فتح تطبيق الاتصال لاحقاً
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('جاري فتح تطبيق الاتصال... 📞', textDirection: TextDirection.rtl), backgroundColor: Colors.blue));
                }
              ),
              
              _buildSupportOption(
                context, 
                Icons.email, 
                'إرسال تذكرة دعم', 
                'للمشاكل التقنية والمالية', 
                Colors.purple,
                () {
                  // استدعاء دالة النافذة المنبثقة التي برمجناها بالأعلى
                  _showTicketDialog(context);
                }
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // تصميم بطاقات خيارات الدعم
  // ==========================================
  Widget _buildSupportOption(BuildContext context, IconData icon, String title, String subtitle, Color color, VoidCallback onTap) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: color.withOpacity(0.2), width: 1.5),
      ),
      child: InkWell( // استخدمنا InkWell لإضافة تأثير النقر الجميل
        onTap: onTap, // تنفيذ الأمر عند النقر
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
