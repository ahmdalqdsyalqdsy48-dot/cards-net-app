import 'package:flutter/material.dart';
import '../../../core/widgets/custom_header.dart'; // 👈 استدعاء الترويسة المخصصة
import '../widgets/custom_agent_drawer.dart';

class AdvancedStatementScreen extends StatefulWidget {
  const AdvancedStatementScreen({super.key});

  @override
  State<AdvancedStatementScreen> createState() => _AdvancedStatementScreenState();
}

class _AdvancedStatementScreenState extends State<AdvancedStatementScreen> {
  DateTimeRange? _selectedDateRange;
  String _selectedType = 'الكل';

  // قاعدة البيانات (تم تعديل تنسيق التاريخ ليسهل فلترته برمجياً YYYY-MM-DD)
  final List<Map<String, dynamic>> _ledgerData = [
    {'id': '101', 'date': '2026-03-25', 'time': '10:30 ص', 'desc': 'مبيعات كاشير (5 كروت)', 'credit': 2500.0, 'debit': 0.0, 'balance': 125000.0, 'type': 'مبيعات'},
    {'id': '102', 'date': '2026-03-25', 'time': '09:15 ص', 'desc': 'تغذية بقالة النور', 'credit': 0.0, 'debit': 20000.0, 'balance': 122500.0, 'type': 'تحويلات'},
    {'id': '103', 'date': '2026-03-24', 'time': '08:00 م', 'desc': 'استلام رصيد من الإدارة', 'credit': 50000.0, 'debit': 0.0, 'balance': 142500.0, 'type': 'تحويلات'},
    {'id': '104', 'date': '2026-03-24', 'time': '04:20 م', 'desc': 'تسديد دفعة للإدارة', 'credit': 0.0, 'debit': 10000.0, 'balance': 92500.0, 'type': 'أخرى'},
    {'id': '105', 'date': '2026-03-23', 'time': '02:10 م', 'desc': 'مبيعات كاشير (1 كرت)', 'credit': 1000.0, 'debit': 0.0, 'balance': 102500.0, 'type': 'مبيعات'},
  ];

  // ==========================================
  // نافذة اختيار التاريخ
  // ==========================================
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

  // ==========================================
  // دالة الفلترة (تعيد البيانات المصفاة بناءً على التاريخ والنوع)
  // ==========================================
  List<Map<String, dynamic>> get _filteredData {
    return _ledgerData.where((row) {
      // 1. فلترة بالنوع
      if (_selectedType != 'الكل' && row['type'] != _selectedType) return false;

      // 2. فلترة بالتاريخ
      if (_selectedDateRange != null) {
        DateTime rowDate = DateTime.parse(row['date']);
        // تجاهل الساعات والدقائق للمقارنة الدقيقة
        DateTime start = DateTime(_selectedDateRange!.start.year, _selectedDateRange!.start.month, _selectedDateRange!.start.day);
        DateTime end = DateTime(_selectedDateRange!.end.year, _selectedDateRange!.end.month, _selectedDateRange!.end.day, 23, 59, 59);
        
        if (rowDate.isBefore(start) || rowDate.isAfter(end)) return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // جلب البيانات المفلترة لحساب الإجماليات وعرضها
    final filteredList = _filteredData;
    final double totalCredit = filteredList.fold(0.0, (sum, item) => sum + item['credit']);
    final double totalDebit = filteredList.fold(0.0, (sum, item) => sum + item['debit']);

    // 👇 التعديل الجذري: Scaffold في الخارج للحفاظ على اتجاه الـ Drawer
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: const CustomHeader(title: 'كشف الحساب المتقدم'),
      drawer: const CustomAgentDrawer(
        agentName: 'شبكة الصقر للواي فاي',
        phoneNumber: '777777777',
        role: 'وكيل معتمد (Agent)',
        currentBalance: 125000.0,
      ),
      // 👇 الأمر يحيط بالـ body فقط
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            // 1. الحاوية العلوية المنحنية مع أدوات التصدير
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade900 : Colors.cyan.shade800,
                borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
                boxShadow: [BoxShadow(color: Colors.cyan.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 5))],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('تصدير التقرير المحاسبي:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
                        tooltip: 'تصدير PDF',
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('جاري تجهيز وتنزيل ملف PDF 📄...'), backgroundColor: Colors.green));
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.table_view, color: Colors.white),
                        tooltip: 'تصدير Excel',
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('جاري تجهيز وتنزيل ملف Excel 📊...'), backgroundColor: Colors.green));
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // 2. بطاقة الملخص المالي السريع (تتحدث مع الفلترة)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(child: _buildSummaryCard('إجمالي دائن (+)', totalCredit, Colors.green)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildSummaryCard('إجمالي مدين (-)', totalDebit, Colors.red)),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // 3. أدوات الفلترة (التقويم ونوع العملية)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 5, offset: const Offset(0, 3))],
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: OutlinedButton.icon(
                      onPressed: _selectDateRange,
                      icon: const Icon(Icons.date_range, size: 18),
                      label: Text(
                        _selectedDateRange == null ? 'تحديد الفترة الزمنية' : '${_selectedDateRange!.start.day}/${_selectedDateRange!.start.month} - ${_selectedDateRange!.end.day}/${_selectedDateRange!.end.month}',
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
                      style: TextStyle(fontSize: 12, color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontFamily: 'Tajawal'),
                      items: ['الكل', 'مبيعات', 'تحويلات', 'أخرى'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                      onChanged: (val) => setState(() => _selectedType = val!),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 15),

            // 4. ترويسة الجدول المحاسبي
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                decoration: BoxDecoration(color: Colors.cyan.shade800, borderRadius: BorderRadius.circular(8)),
                child: const Row(
                  children: [
                    Expanded(flex: 3, child: Text('البيان / التاريخ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                    Expanded(flex: 2, child: Text('دائن (+)', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                    Expanded(flex: 2, child: Text('مدين (-)', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                    Expanded(flex: 2, child: Text('الرصيد', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                  ],
                ),
              ),
            ),

            // 5. محتوى الجدول (قائمة العمليات المفلترة)
            Expanded(
              child: filteredList.isEmpty
                  ? const Center(child: Text('لا توجد عمليات مسجلة في هذه الفترة.', style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: filteredList.length,
                      itemBuilder: (context, index) {
                        final row = filteredList[index];
                        Color creditColor = row['credit'] > 0 ? Colors.green.shade700 : Colors.grey.shade400;
                        Color debitColor = row['debit'] > 0 ? Colors.red.shade700 : Colors.grey.shade400;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade200),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))],
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(row['desc'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 4),
                                    Text('${row['date']} • ${row['time']}', style: const TextStyle(color: Colors.grey, fontSize: 10), textDirection: TextDirection.ltr),
                                  ],
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(row['credit'] > 0 ? '+${row['credit']}' : '-', textAlign: TextAlign.center, style: TextStyle(color: creditColor, fontWeight: FontWeight.bold, fontSize: 12)),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(row['debit'] > 0 ? '-${row['debit']}' : '-', textAlign: TextAlign.center, style: TextStyle(color: debitColor, fontWeight: FontWeight.bold, fontSize: 12)),
                              ),
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

  // أداة بناء بطاقات الملخص
  Widget _buildSummaryCard(String title, double amount, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          Text(
            '${amount.toStringAsFixed(0)} ريال', 
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}
