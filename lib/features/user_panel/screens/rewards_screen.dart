import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // نحتاجها لميزة نسخ رقم الكرت المجاني
import '../../../core/widgets/custom_header.dart';
import '../widgets/custom_user_drawer.dart';

// 👇 1. تم تحويل الشاشة إلى StatefulWidget لكي نتمكن من تغيير النقاط عند الاستبدال
class RewardsScreen extends StatefulWidget {
  const RewardsScreen({super.key});

  @override
  State<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends State<RewardsScreen> {
  // متغير يحفظ نقاط الزبون الحالية (جعلناها 1250 كتجربة)
  int _currentPoints = 1250;

  // ==========================================
  // دالة استبدال النقاط بكرت مجاني 🎁
  // ==========================================
  void _redeemPoints(BuildContext context, String cardTitle, int requiredPoints) {
    // 1. التحقق: هل الزبون يملك نقاطاً كافية؟
    if (_currentPoints >= requiredPoints) {
      // 2. إذا كانت تكفي، نقوم بخصم النقاط وتحديث الواجهة
      setState(() {
        _currentPoints -= requiredPoints;
      });
      
      // 3. توليد رقم كرت مجاني (وهمي للتجربة)
      String freePin = 'FREE-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';

      // 4. إظهار نافذة الاحتفال بالكرت المجاني
      _showSuccessDialog(context, cardTitle, freePin);

    } else {
      // 5. إذا كانت النقاط لا تكفي، نظهر رسالة خطأ
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('عفواً، نقاطك غير كافية لاستبدال $cardTitle ❌', textDirection: TextDirection.rtl),
          backgroundColor: Colors.red,
        )
      );
    }
  }

  // ==========================================
  // نافذة الاحتفال وعرض الكرت المجاني 🎉
  // ==========================================
  void _showSuccessDialog(BuildContext context, String cardTitle, String pin) {
    showDialog(
      context: context,
      barrierDismissible: false, // يمنع إغلاق النافذة بالنقر خارجها
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.card_giftcard, color: Colors.green, size: 60),
              const SizedBox(height: 15),
              const Text('مبروك! كرتك المجاني جاهز 🎉', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green)),
              const SizedBox(height: 10),
              Text('لقد قمت باستبدال نقاطك بـ $cardTitle', textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: Colors.blueGrey)),
              const SizedBox(height: 20),
              // عرض رقم الكرت
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  children: [
                    const Text('رقم الكرت (PIN)', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    Text(pin, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 2)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // أزرار النسخ والإغلاق
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // نسخ الكرت للحافظة
                        Clipboard.setData(ClipboardData(text: pin));
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم نسخ الكرت المجاني! ✅'), backgroundColor: Colors.green));
                      },
                      icon: const Icon(Icons.copy, color: Colors.white, size: 18),
                      label: const Text('نسخ الكرت', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                    ),
                  ),
                  const SizedBox(width: 10),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('إغلاق', style: TextStyle(color: Colors.grey)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomHeader(title: 'المكافآت والولاء'),
      // 👇 تم تنظيف القائمة الجانبية من المتغير المتعارض
      drawer: const CustomUserDrawer(
        userName: 'محمد أحمد',
        phoneNumber: '777123456',
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // ==========================================
              // 1. بطاقة عرض النقاط الحالية
              // ==========================================
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.amber.shade700, Colors.orange.shade500],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 5))],
                ),
                child: Column(
                  children: [
                    const Icon(Icons.stars, size: 60, color: Colors.white),
                    const SizedBox(height: 10),
                    const Text('نقاطك الحالية', style: TextStyle(color: Colors.white70, fontSize: 16)),
                    // 👈 قراءة النقاط من المتغير الديناميكي
                    Text('$_currentPoints نقطة', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              
              const SizedBox(height: 30),
              const Align(
                alignment: Alignment.centerRight,
                child: Text('استبدل نقاطك بكروت مجانية 🎁', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
              ),
              const SizedBox(height: 15),
              
              // ==========================================
              // 2. قائمة خيارات الاستبدال المتاحة
              // ==========================================
              Expanded(
                child: ListView(
                  children: [
                    _buildRewardItem(context, 'كرت أبو 250 ريال', 250, Colors.teal),
                    _buildRewardItem(context, 'كرت أبو 500 ريال', 500, Colors.green),
                    _buildRewardItem(context, 'كرت أبو 1000 ريال', 1000, Colors.blue),
                    _buildRewardItem(context, 'باقة أسبوعية VIP', 2500, Colors.purple),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // تصميم بطاقة الاستبدال
  // ==========================================
  Widget _buildRewardItem(BuildContext context, String title, int points, Color color) {
    // التحقق الشكلي: هل يملك المستخدم نقاطاً تكفي لهذا العنصر تحديداً؟
    bool canRedeem = _currentPoints >= points;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: canRedeem ? color.withOpacity(0.5) : Colors.transparent),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1), 
          child: Icon(Icons.card_giftcard, color: color)
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('يتطلب $points نقطة', style: TextStyle(color: canRedeem ? Colors.green : Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
        trailing: ElevatedButton(
          // ربط الزر بدالة الاستبدال التي برمجناها
          onPressed: () => _redeemPoints(context, title, points),
          style: ElevatedButton.styleFrom(
            backgroundColor: canRedeem ? color : Colors.grey.shade400,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
          ),
          child: const Text('استبدال', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}
