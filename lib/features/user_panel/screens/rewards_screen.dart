import 'package:flutter/material.dart';
import '../../../core/widgets/custom_header.dart';

class RewardsScreen extends StatelessWidget {
  const RewardsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomHeader(title: 'المكافآت والولاء'),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // بطاقة عرض النقاط الحالية
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [Colors.amber.shade700, Colors.orange.shade500]),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.stars, size: 60, color: Colors.white),
                    SizedBox(height: 10),
                    Text('نقاطك الحالية', style: TextStyle(color: Colors.white70, fontSize: 16)),
                    Text('1,250 نقطة', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              // قسم استبدال النقاط بجوائز
              const Align(
                alignment: Alignment.centerRight,
                child: Text('استبدل نقاطك بكروت مجانية 🎁', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 15),
              Expanded(
                child: ListView(
                  children: [
                    _buildRewardItem(context, 'كرت أبو 500 ريال', 'يتطلب 500 نقطة', Colors.green),
                    _buildRewardItem(context, 'كرت أبو 1000 ريال', 'يتطلب 1000 نقطة', Colors.blue),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // دالة مساعدة لبناء شكل الجائزة
  Widget _buildRewardItem(BuildContext context, String title, String points, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: color.withOpacity(0.2), child: Icon(Icons.card_giftcard, color: color)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(points),
        trailing: ElevatedButton(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إرسال طلب الاستبدال للإدارة ⏳')));
          },
          child: const Text('استبدال'),
        ),
      ),
    );
  }
}
