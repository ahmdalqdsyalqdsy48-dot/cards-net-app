import 'package:flutter/material.dart';

class AdvancedStatementScreen extends StatefulWidget {
  const AdvancedStatementScreen({super.key});

  @override
  State<AdvancedStatementScreen> createState() => _AdvancedStatementScreenState();
}

class _AdvancedStatementScreenState extends State<AdvancedStatementScreen> {
  // متغيرات الفلترة
  DateTimeRange? _selectedDateRange;
  String _selectedType = 'الكل';

  // قاعدة بيانات وهمية للعمليات المحاسبية (دفتر الأستاذ / Ledger)
  final List<Map<String, dynamic>> _ledgerData = [
    {'id': '101', 'date': '2023/10/25', 'time': '10:30 ص', 'desc': 'مبيعات كاشير (5 كروت)', 'credit': 2500.0, 'debit': 0.0, 'balance': 125000.0},
    {'id': '102', 'date': '2023/10/25', 'time': '09:15 ص', 'desc': 'تغذية بقالة النور', 'credit': 0.0, 'debit': 20000.0, 'balance': 122500.0},
    {'id': '103', 'date': '2023/10/24', 'time': '08:00 م', 'desc': 'استلام رصيد من الإدارة', 'credit': 50000.0, 'debit': 0.0, 'balance': 142500.0},
    {'id': '104', 'date': '2023/10/24', 'time': '04:20 م', 'desc': 'تسديد دفعة للإدارة', 'credit': 0.0, 'debit': 10000.0, 'balance': 92500.0},
    {'id': '105', 'date': '2023/10/23', 'time': '02:10 م', 'desc': 'مبيعات كاشير (1 كرت)', 'credit': 1000.0, 'debit': 0.0, 'balance': 102500.0},
  ];

  // دالة اختيار التاريخ
  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: _selectedDateRange ?? DateTimeRange(start: DateTime.now().subtract(const Duration(days: 7)), end: DateTime.now()),
      firstDate: DateTime(2023),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Directionality(textDirection: TextDirection.rtl, child: child!);
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.grey.shade100,
        appBar: AppBar(
          title: const Text('كشف الحساب المتقدم', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
          backgroundColor: Colors.cyan.shade800,
          foregroundColor: Colors.white,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              tooltip: 'تصدير PDF',
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('جاري تجهيز وتنزيل ملف PDF 📄...'), backgroundColor: Colors.green));
              },
            ),
            IconButton(
              icon: const Icon(Icons.table_view),
              tooltip: 'تصدير Excel',
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('جاري تجهيز وتنزيل ملف Excel 📊...'), backgroundColor: Colors.green));
              },
            ),
          ],
        ),
        body: Column(
          children: [
            // ==========================================
            // 1. شريط الفلاتر العلوي
            // ==========================================
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 5, offset: const Offset(0, 3))],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: OutlinedButton.icon(
                          onPressed: _selectDateRange,
                          icon: const Icon(Icons.date_range, size: 18),
                          label: Text(
                            _selectedDateRange == null ? 'تحديد الفترة' : '${_selectedDateRange!.start.day}/${_selectedDateRange!.start.month} - ${_selectedDateRange!.end.day}/${_selectedDateRange!.end.month}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          style: OutlinedButton.styleFrom(foregroundColor: Colors.cyan.shade800),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 1,
                        child: DropdownButtonFormField<String>(
                          value: _selectedType,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          style: const TextStyle(fontSize: 12, color: Colors.black, fontWeight: FontWeight.bold, fontFamily: 'Tajawal'),
                          items: ['الكل', 'مبيعات', 'تحويلات'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                          onChanged: (val) => setState(() => _selectedType = val!),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // ==========================================
            // 2. ترويسة الجدول
            // ==========================================
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                decoration: BoxDecoration(color: Colors.cyan.shade800, borderRadius: BorderRadius.circular(8)),
                child: const Row(
                  children: [
                    Expanded(flex: 3, child: Text('البيان / التاريخ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13))),
                    Expanded(flex: 2, child: Text('دائن (+)', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13))),
                    Expanded(flex: 2, child: Text('مدين (-)', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13))),
                    Expanded(flex: 2, child: Text('الرصيد', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13))),
                  ],
                ),
              ),
            ),

            // ==========================================
            // 3. بيانات الكشف المحاسبي
            // ==========================================
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _ledgerData.length,
                itemBuilder: (context, index) {
                  final row = _ledgerData[index];
                  // تنسيق الألوان
                  Color creditColor = row['credit'] > 0 ? Colors.green.shade700 : Colors.grey.shade400;
                  Color debitColor = row['debit'] > 0 ? Colors.red.shade700 : Colors.grey.shade400;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // البيان والتاريخ
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(row['desc'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 4),
                              Text('${row['date']} • ${row['time']}', style: const TextStyle(color: Colors.grey, fontSize: 10)),
                            ],
                          ),
                        ),
                        // دائن
                        Expanded(
                          flex: 2,
                          child: Text(row['credit'] > 0 ? '+${row['credit']}' : '-', textAlign: TextAlign.center, style: TextStyle(color: creditColor, fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                        // مدين
                        Expanded(
                          flex: 2,
                          child: Text(row['debit'] > 0 ? '-${row['debit']}' : '-', textAlign: TextAlign.center, style: TextStyle(color: debitColor, fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                        // الرصيد
                        Expanded(
                          flex: 2,
                          child: Text('${row['balance']}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
