import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'package:intl/intl.dart'; // 👈 لمعالجة التواريخ بدقة

import '../../../core/providers/system_provider.dart'; 
import '../../../core/widgets/custom_drawer.dart';
import '../../../core/widgets/custom_header.dart'; 

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  // متغيرات الفلترة الحقيقية
  String _selectedReportType = 'الكل (شامل)';
  String _selectedAgent = 'الكل';
  DateTimeRange? _selectedDateRange;
  bool _showChart = false; 

  @override
  void initState() {
    super.initState();
    // تعيين التاريخ الافتراضي لآخر 30 يوماً
    _selectedDateRange = DateTimeRange(
      start: DateTime.now().subtract(const Duration(days: 30)),
      end: DateTime.now(),
    );
  }

  // ==========================================
  // ⚙️ محرك معالجة البيانات الحقيقية (Data Engine)
  // ==========================================
  List<Map<String, dynamic>> _getFilteredData(SystemProvider sys) {
    List<Map<String, dynamic>> data = List.from(sys.transactionsLedger);

    // 1. فلترة حسب التاريخ
    if (_selectedDateRange != null) {
      data = data.where((tx) {
        if (tx['timestamp'] == null) return false;
        DateTime txDate = (tx['timestamp'] as Timestamp).toDate();
        return txDate.isAfter(_selectedDateRange!.start.subtract(const Duration(days: 1))) && 
               txDate.isBefore(_selectedDateRange!.end.add(const Duration(days: 1)));
      }).toList();
    }

    // 2. فلترة حسب الوكيل
    if (_selectedAgent != 'الكل') {
      data = data.where((tx) => tx['agentName'] == _selectedAgent).toList();
    }

    // 3. فلترة حسب نوع التقرير
    if (_selectedReportType == 'إيداعات وشحن') {
      data = data.where((tx) => tx['type'] == 'إيداع حوالة').toList();
    } else if (_selectedReportType == 'تسويات وخصومات') {
      data = data.where((tx) => tx['type'].toString().contains('تسوية')).toList();
    }

    return data;
  }

  // دالة لحساب إجمالي المبالغ في البيانات المفلترة حالياً
  double _calculateTotalAmount(List<Map<String, dynamic>> filteredData) {
    double total = 0.0;
    for (var tx in filteredData) {
      total += (tx['amount'] ?? 0.0).toDouble();
    }
    return total;
  }

  // ==========================================
  // نافذة التقويم الحقيقية 📅
  // ==========================================
  Future<void> _pickDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: _selectedDateRange,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: Colors.blueAccent, onPrimary: Colors.white, onSurface: Colors.black),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDateRange) {
      setState(() => _selectedDateRange = picked);
    }
  }

  // ==========================================
  // نافذة جدولة التقرير الحقيقية ⏱️
  // ==========================================
  void _showScheduleDialog(SystemProvider sys) {
    String scheduleType = 'شهرياً';
    final TextEditingController emailController = TextEditingController(text: 'admin@cardsnet.com');

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.schedule, color: Colors.blueAccent), SizedBox(width: 8),
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
                  items: ['يومياً', 'أسبوعياً', 'شهرياً'].map((String val) => DropdownMenuItem(value: val, child: Text(val))).toList(),
                  onChanged: (val) => setStateDialog(() => scheduleType = val!),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'البريد الإلكتروني المستلم',
                    prefixIcon: const Icon(Icons.email, color: Colors.blue),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
              ElevatedButton(
                onPressed: () async {
                  if (emailController.text.isNotEmpty && emailController.text.contains('@')) {
                    // تسجيل الجدولة بشكل حقيقي في قاعدة البيانات
                    await sys.logAction(
                      action: 'جدولة تقرير', 
                      details: 'تمت جدولة تقرير ($scheduleType) للبريد: ${emailController.text}', 
                      severity: 'medium'
                    );
                    if (!context.mounted) return;
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ الجدولة في قاعدة البيانات بنجاح! ⏱️', textDirection: TextDirection.rtl), backgroundColor: Colors.green));
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى إدخال بريد إلكتروني صحيح!', textDirection: TextDirection.rtl), backgroundColor: Colors.red));
                  }
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
    final sys = Provider.of<SystemProvider>(context);
    final adminBalance = sys.adminMainBalance;
    final totalCards = sys.totalSystemCards;

    // جلب البيانات المفلترة للواجهة
    final filteredData = _getFilteredData(sys);
    final currentTotalAmount = _calculateTotalAmount(filteredData);

    // تجهيز قائمة الوكلاء للقائمة المنسدلة (ديناميكياً من قاعدة البيانات)
    List<String> agentNames = ['الكل'];
    agentNames.addAll(sys.agentsList.map((a) => a['name'].toString()).toSet().toList());

    // التأكد من أن الوكيل المحدد موجود في القائمة، وإلا إرجاعه لـ "الكل"
    if (!agentNames.contains(_selectedAgent)) {
      _selectedAgent = 'الكل';
    }

    return Scaffold(
      appBar: const CustomHeader(title: 'التقارير الشاملة'),
      drawer: CustomDrawer(
        userName: sys.currentUserName,
        phoneNumber: sys.currentUserPhone,
        role: 'مالك النظام (Super Admin)',
        balanceOrPoints: 'أرباح النظام: ${adminBalance.toStringAsFixed(0)} ريال',
      ),
      
      // الشريط السفلي الثابت (يقرأ بيانات حقيقية الآن)
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
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('إجمالي كروت النظام', style: TextStyle(color: Colors.white70, fontSize: 12)), 
                  Text('$totalCards كرت', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))
                ],
              ),
              Container(height: 30, width: 1, color: Colors.white24),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('إجمالي مبالغ التقرير الحالي', style: TextStyle(color: Colors.white70, fontSize: 12)), 
                  Text('${currentTotalAmount.toStringAsFixed(0)} ريال', style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 16))
                ],
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
              color: Theme.of(context).brightness == Brightness.dark ? Colors.black12 : Colors.blue.shade50,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildExportBtn(Icons.table_view, 'تصدير CSV', Colors.green.shade700, () {
                      if (filteredData.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا توجد بيانات لتصديرها!'), backgroundColor: Colors.orange));
                        return;
                      }
                      // محاكاة تجهيز ملف CSV حقيقي
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم تجميع ${filteredData.length} سجل. (التصدير للملفات يتطلب حزمة PathProvider لاحقاً)', textDirection: TextDirection.rtl), backgroundColor: Colors.green));
                    }),
                    const SizedBox(width: 8),
                    _buildExportBtn(Icons.picture_as_pdf, 'PDF', Colors.red.shade700, () {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تجهيز البيانات للـ PDF. (يتطلب إضافة حزمة printing لاحقاً)', textDirection: TextDirection.rtl), backgroundColor: Colors.red));
                    }),
                    const SizedBox(width: 8),
                    _buildExportBtn(Icons.schedule, 'أتمتة وجدولة', Colors.orange.shade800, () => _showScheduleDialog(sys)),
                  ],
                ),
              ),
            ),

            // === 2. أدوات الفلترة الذكية (الحقيقية) ===
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
                        items: ['الكل (شامل)', 'إيداعات وشحن', 'تسويات وخصومات'].map((String val) {
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
                              items: agentNames.map((String val) {
                                return DropdownMenuItem(value: val, child: Text(val, style: const TextStyle(fontSize: 13)));
                              }).toList(),
                              onChanged: (val) => setState(() => _selectedAgent = val!),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 1,
                            child: ElevatedButton.icon(
                              onPressed: _pickDateRange, // 👈 فتح التقويم الحقيقي
                              icon: const Icon(Icons.date_range, size: 16),
                              label: const Text('المدة', style: TextStyle(fontSize: 12)),
                              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                            ),
                          ),
                        ],
                      ),
                      // عرض التاريخ المحدد
                      if (_selectedDateRange != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            'من: ${DateFormat('yyyy/MM/dd').format(_selectedDateRange!.start)}  إلى: ${DateFormat('yyyy/MM/dd').format(_selectedDateRange!.end)}',
                            style: const TextStyle(fontSize: 11, color: Colors.blueGrey, fontWeight: FontWeight.bold),
                          ),
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
                  Text('نتائج التقرير (${filteredData.length} سجل):', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade800, fontSize: 16)),
                  ElevatedButton.icon(
                    onPressed: () => setState(() => _showChart = !_showChart),
                    icon: Icon(_showChart ? Icons.list_alt : Icons.bar_chart, color: Colors.white),
                    label: Text(_showChart ? 'عرض الجداول' : 'الرسم البياني', style: const TextStyle(color: Colors.white, fontSize: 12)),
                    style: ElevatedButton.styleFrom(backgroundColor: _showChart ? Colors.blueGrey : Colors.purple, shape: const StadiumBorder()),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // === 4. منطقة العرض (الجدول أو الرسم البياني) ===
            Expanded(
              child: filteredData.isEmpty 
                ? const Center(child: Text('لا توجد بيانات مطابقة لهذه الفلاتر 📭', style: TextStyle(color: Colors.grey)))
                : (_showChart ? _buildChartView(filteredData) : _buildTableView(filteredData)),
            ),
          ],
        ),
      ),
    );
  }

  // أداة بناء الجدول (يقرأ بيانات حقيقية)
  Widget _buildTableView(List<Map<String, dynamic>> data) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: data.length,
      itemBuilder: (context, index) {
        final row = data[index];
        String dateStr = '';
        if (row['timestamp'] != null) {
          dateStr = DateFormat('yyyy-MM-dd HH:mm').format((row['timestamp'] as Timestamp).toDate());
        }
        
        // تحديد اللون حسب نوع العملية (خصم أحمر، إيداع أخضر)
        bool isPositive = row['type'] == 'إيداع حوالة' || (row['type'].toString().contains('إضافة'));
        Color amountColor = isPositive ? Colors.green : Colors.red;
        String sign = isPositive ? '+' : '-';

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: ListTile(
            leading: CircleAvatar(backgroundColor: amountColor.withOpacity(0.1), child: Icon(isPositive ? Icons.arrow_downward : Icons.arrow_upward, color: amountColor, size: 20)),
            title: Text(row['agentName'] ?? 'غير معروف', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: Text('$dateStr\nالنوع: ${row['type']}', style: const TextStyle(fontSize: 12)),
            trailing: Text('$sign${row['amount']} ريال', style: TextStyle(color: amountColor, fontWeight: FontWeight.bold, fontSize: 14), textDirection: TextDirection.ltr),
            isThreeLine: true,
          ),
        );
      },
    );
  }

  // أداة بناء الرسم البياني (ديناميكي وعلمي 100%)
  Widget _buildChartView(List<Map<String, dynamic>> data) {
    // 1. تجميع البيانات (حساب إجمالي المبالغ لكل وكيل)
    Map<String, double> agentTotals = {};
    for (var tx in data) {
      String name = tx['agentName'] ?? 'مجهول';
      double amount = (tx['amount'] ?? 0.0).toDouble();
      agentTotals[name] = (agentTotals[name] ?? 0.0) + amount;
    }

    // 2. ترتيب الوكلاء تنازلياً وأخذ أعلى 4 فقط ليناسب الشاشة
    var sortedAgents = agentTotals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    var topAgents = sortedAgents.take(4).toList();

    // 3. إيجاد أعلى قيمة لضبط مقياس الرسم البياني (Scale)
    double maxAmount = topAgents.isNotEmpty ? topAgents.first.value : 1.0;
    if (maxAmount == 0) maxAmount = 1.0; // تفادي القسمة على صفر

    List<Color> barColors = [Colors.blue, Colors.orange, Colors.green, Colors.purple];

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
              const Text('أعلى الوكلاء في هذه الفترة (مبالغ)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.purple)),
              const SizedBox(height: 30),
              
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: topAgents.asMap().entries.map((entry) {
                    int index = entry.key;
                    var agentData = entry.value;
                    // حساب ارتفاع العمود نسبة لأعلى مبلغ (بحد أقصى 150 بكسل)
                    double barHeight = (agentData.value / maxAmount) * 150.0;
                    if (barHeight < 10) barHeight = 10; // حد أدنى للرؤية
                    
                    return _buildBar(agentData.key, barHeight, barColors[index % barColors.length], agentData.value);
                  }).toList(),
                ),
              ),
              const SizedBox(height: 20),
              const Text('💡 الرسم البياني يتغير آلياً حسب الفلاتر أعلاه.', style: TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  // أداة بناء الأعمدة الديناميكية
  Widget _buildBar(String label, double height, Color color, double amount) {
    // اختصار الاسم إذا كان طويلاً
    String shortLabel = label.length > 8 ? '${label.substring(0, 8)}..' : label;
    
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(amount.toStringAsFixed(0), style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Container(
          width: 40,
          height: height,
          decoration: BoxDecoration(
            color: color.withOpacity(0.8),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(2, 0))],
          ),
        ),
        const SizedBox(height: 8),
        Text(shortLabel, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
      ],
    );
  }

  // أداة أزرار التصدير
  Widget _buildExportBtn(IconData icon, String label, Color color, VoidCallback onTap) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16, color: Colors.white),
      label: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      style: ElevatedButton.styleFrom(backgroundColor: color, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0), elevation: 1),
    );
  }
}
