import 'package:flutter/material.dart';
import '../../../core/widgets/custom_drawer.dart';
import '../../../core/widgets/custom_header.dart'; // 👈 استدعاء الهيدر الجديد

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  // متغيرات الفلترة والتحكم بالواجهة
  String _selectedReportType = 'تقرير الأرباح والخصم الآلي';
  String _selectedAgent = 'الكل';
  bool _showChart = false; // للتبديل بين الجدول والرسم البياني

  // قاعدة بيانات وهمية لنتائج التقرير
  final List<Map<String, dynamic>> _reportData = [
    {'date': '2026-03-23', 'agent': 'شبكة الصقر', 'sales': '450 كرت', 'profit': '+2,250 ريال'},
    {'date': '2026-03-22', 'agent': 'وكالة النور', 'sales': '120 كرت', 'profit': '+600 ريال'},
    {'date': '2026-03-21', 'agent': 'شبكة العالمية', 'sales': '300 كرت', 'profit': '+1,500 ريال'},
  ];

  // ==========================================
  // نافذة جدولة التقرير ⏱️
  // ==========================================
  void _showScheduleDialog() {
    String scheduleType = 'شهرياً';
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.schedule, color: Colors.blueAccent),
                SizedBox(width: 8),
                Text('أتمتة وجدولة التقرير', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('سيقوم النظام بتوليد هذا التقرير وإرساله إلى بريدك الإلكتروني آلياً:', style: TextStyle(fontSize: 13, color: Colors.grey)),
                const SizedBox(height: 15),
                DropdownButtonFormField<String>(
                  value: scheduleType,
                  decoration: InputDecoration(labelText: 'تكرار الإرسال', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                  items: ['يومياً', 'أسبوعياً', 'شهرياً'].map((String val) {
                    return DropdownMenuItem(value: val, child: Text(val));
                  }).toList(),
                  onChanged: (val) => setStateDialog(() => scheduleType = val!),
                ),
                const SizedBox(height: 10),
                TextField(
                  decoration: InputDecoration(
                    labelText: 'البريد الإلكتروني المستلم',
                    prefixIcon: const Icon(Icons.email, color: Colors.blue),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  controller: TextEditingController(text: 'admin@cardsnet.com'),
                ),
                const SizedBox(height: 10),
                const Text('💡 سيتم الإرسال الساعة 12:00 منتصف الليل.', style: TextStyle(fontSize: 12, color: Colors.orange)),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت جدولة التقرير بنجاح! ⏱️'), backgroundColor: Colors.green));
                },
                child: const Text('حفظ الجدولة'),
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
      // 👈 تم تركيب الهيدر الشامل هنا بنجاح!
      appBar: const CustomHeader(title: 'التقارير الشاملة'),
      
      drawer: const CustomDrawer(
        userName: 'مالك النظام',
        phoneNumber: '774578241',
        role: 'مالك النظام (Super Admin)',
        balanceOrPoints: 'أرباح النظام: 5,430,000 ريال',
      ),
      // الشريط السفلي الثابت
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.blue.shade900,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, -3))],
        ),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              const Column(
                mainAxisSize: MainAxisSize.min,
                children: [Text('إجمالي الكروت', style: TextStyle(color: Colors.white70, fontSize: 12)), Text('870 كرت', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))],
              ),
              Container(height: 30, width: 1, color: Colors.white24),
              const Column(
                mainAxisSize: MainAxisSize.min,
                children: [Text('صافي أرباحك', style: TextStyle(color: Colors.white70, fontSize: 12)), Text('4,350 ريال', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 16))],
              ),
            ],
          ),
        ),
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            // === 1. أزرار التصدير والأتمتة العلوية ===
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.blue.shade50,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildExportBtn(Icons.table_view, 'Excel', Colors.green.shade700, () {}),
                    const SizedBox(width: 8),
                    _buildExportBtn(Icons.picture_as_pdf, 'PDF', Colors.red.shade700, () {}),
                    const SizedBox(width: 8),
                    _buildExportBtn(Icons.print, 'طباعة', Colors.blueGrey, () {}),
                    const SizedBox(width: 8),
                    _buildExportBtn(Icons.schedule, 'جدولة', Colors.orange.shade800, _showScheduleDialog),
                  ],
                ),
              ),
            ),

            // === 2. أدوات الفلترة الذكية ===
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      DropdownButtonFormField<String>(
                        value: _selectedReportType,
                        decoration: const InputDecoration(labelText: 'نوع التقرير', prefixIcon: Icon(Icons.analytics, color: Colors.blue)),
                        items: ['تقرير الأرباح والخصم الآلي', 'تقرير شحن المحافظ', 'تقرير نشاط ومبيعات الوكلاء'].map((String val) {
                          return DropdownMenuItem(value: val, child: Text(val, style: const TextStyle(fontSize: 13)));
                        }).toList(),
                        onChanged: (val) => setState(() => _selectedReportType = val!),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: DropdownButtonFormField<String>(
                              value: _selectedAgent,
                              decoration: const InputDecoration(labelText: 'تحديد الوكيل', prefixIcon: Icon(Icons.people)),
                              items: ['الكل', 'شبكة الصقر', 'وكالة النور', 'شبكة العالمية'].map((String val) {
                                return DropdownMenuItem(value: val, child: Text(val, style: const TextStyle(fontSize: 13)));
                              }).toList(),
                              onChanged: (val) => setState(() => _selectedAgent = val!),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 1,
                            child: ElevatedButton.icon(
                              onPressed: () {},
                              icon: const Icon(Icons.date_range, size: 16),
                              label: const Text('المدة'),
                              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // === 3. زر التبديل (بيانات / رسوم بيانية) ===
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('نتائج التقرير:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade800, fontSize: 16)),
                  ElevatedButton.icon(
                    onPressed: () => setState(() => _showChart = !_showChart),
                    icon: Icon(_showChart ? Icons.list_alt : Icons.bar_chart, color: Colors.white),
                    label: Text(_showChart ? 'عرض الجداول' : 'عرض كرسوم بيانية', style: const TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(backgroundColor: _showChart ? Colors.blueGrey : Colors.purple, shape: const StadiumBorder()),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // === 4. منطقة العرض (الجدول أو الرسم البياني) ===
            Expanded(
              child: _showChart ? _buildChartView() : _buildTableView(),
            ),
          ],
        ),
      ),
    );
  }

  // أداة بناء الجدول العادي
  Widget _buildTableView() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _reportData.length,
      itemBuilder: (context, index) {
        final row = _reportData[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: const CircleAvatar(backgroundColor: Colors.blue, child: Icon(Icons.monetization_on, color: Colors.white, size: 20)),
            title: Text(row['agent'], style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('التاريخ: ${row['date']} | المبيعات: ${row['sales']}'),
            trailing: Text(row['profit'], style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 15), textDirection: TextDirection.ltr),
          ),
        );
      },
    );
  }

  // أداة بناء الرسم البياني
  Widget _buildChartView() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('حصة الوكلاء من الأرباح (رسم بياني)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.purple)),
              const SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildBar('الصقر', 120, Colors.blue),
                  _buildBar('النور', 60, Colors.orange),
                  _buildBar('العالمية', 90, Colors.green),
                ],
              ),
              const SizedBox(height: 20),
              const Text('💡 يظهر التصاعد في الأرباح لكل وكيل خلال المدة المحددة.', style: TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  // أداة مساعدة لبناء أعمدة الرسم البياني
  Widget _buildBar(String label, double height, Color color) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          width: 40,
          height: height,
          decoration: BoxDecoration(
            color: color.withOpacity(0.8),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
          ),
        ),
      ],
    );
  }

  // أداة مساعدة لبناء أزرار التصدير العلوية
  Widget _buildExportBtn(IconData icon, String label, Color color, VoidCallback onTap) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16, color: Colors.white),
      label: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      style: ElevatedButton.styleFrom(backgroundColor: color, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0), elevation: 1),
    );
  }
}
