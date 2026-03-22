import 'package:flutter/material.dart';
import '../../../core/widgets/custom_header.dart';
import '../../../core/widgets/custom_drawer.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomHeader(
        title: 'التقارير الشاملة',
        isOnline: true,
      ),
      drawer: const CustomDrawer(
        userName: 'مالك النظام',
        phoneNumber: '774578241',
        role: 'مالك النظام (Super Admin)',
        balanceOrPoints: 'أرباح النظام: 5,430,000 ريال',
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // === 1. شريط الفلترة الذكي ===
              const Text('تخصيص التقرير', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 10),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      _buildFilterRow(Icons.person, 'تحديد الوكيل', 'كل الوكلاء'),
                      const Divider(),
                      _buildFilterRow(Icons.date_range, 'المدة الزمنية', 'مارس 2026'),
                      const SizedBox(height: 15),
                      Row(
                        children: [
                          Expanded(child: _buildExportBtn(Icons.picture_as_pdf, 'تصدير PDF', Colors.red)),
                          const SizedBox(width: 10),
                          Expanded(child: _buildExportBtn(Icons.table_view, 'تصدير Excel', Colors.green)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 25),

              // === 2. ملخص الإجماليات الآلية ===
              const Text('الخلاصة المالية', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 10),
              _buildSummaryCard(context),

              const SizedBox(height: 25),

              // === 3. منطقة الرسوم البيانية (Placeholder) ===
              const Text('أداء المبيعات', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 10),
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.blue.withOpacity(0.2)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.bar_chart, size: 80, color: Colors.blueAccent),
                    Text('رسم بياني تفاعلي يظهر هنا', style: TextStyle(color: Colors.blueGrey)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // دالة لبناء صفوف الفلترة
  Widget _buildFilterRow(IconData icon, String title, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.blueAccent, size: 20),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
        TextButton(onPressed: () {}, child: Text(value)),
      ],
    );
  }

  // دالة لبناء أزرار التصدير
  Widget _buildExportBtn(IconData icon, String label, Color color) {
    return ElevatedButton.icon(
      onPressed: () {},
      icon: Icon(icon, size: 18, color: Colors.white),
      label: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      style: ElevatedButton.styleFrom(backgroundColor: color, elevation: 0),
    );
  }

  // بطاقة ملخص البيانات
  Widget _buildSummaryCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.blue.shade700, Colors.blue.shade900]),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          _buildSummaryItem('إجمالي الإيداعات', '12,500,000 ريال'),
          const Divider(color: Colors.white24),
          _buildSummaryItem('صافي أرباحك', '850,000 ريال'),
          const Divider(color: Colors.white24),
          _buildSummaryItem('عدد الكروت المباعة', '4,320 كرت'),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14)),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }
}
