import 'package:flutter/material.dart';
import '../../../core/widgets/custom_drawer.dart';
import '../../../core/widgets/custom_header.dart'; // 👈 استدعاء الهيدر الجديد

class FinancialCenterScreen extends StatefulWidget {
  const FinancialCenterScreen({super.key});

  @override
  State<FinancialCenterScreen> createState() => _FinancialCenterScreenState();
}

class _FinancialCenterScreenState extends State<FinancialCenterScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // 1. بيانات طلبات الشحن الوهمية
  final List<Map<String, dynamic>> _rechargeRequests = [
    {'id': 1, 'agent': 'شبكة الصقر', 'depositor': 'أحمد القدسي', 'amount': '50,000', 'bank': 'بنك الكريمي', 'ref': '987654321', 'beneficiary': 'مالك النظام (حساب 1)', 'date': 'اليوم 10:30 ص'},
    {'id': 2, 'agent': 'وكالة النور', 'depositor': 'محمد علي', 'amount': '15,000', 'bank': 'جوالي', 'ref': '112233445', 'beneficiary': 'مالك النظام (حساب 2)', 'date': 'أمس 04:15 م'},
  ];

  // 2. بيانات أرصدة المحافظ
  final List<Map<String, dynamic>> _wallets = [
    {'agent': 'شبكة الصقر', 'balance': 150000, 'dangerLimit': 20000},
    {'agent': 'وكالة النور', 'balance': 5000, 'dangerLimit': 10000}, // هذا الوكيل في حالة خطر 🔴
  ];

  // 3. السجل المالي الشامل
  final List<Map<String, dynamic>> _ledger = [
    {'date': '2026-03-23 10:30', 'agent': 'شبكة الصقر', 'type': 'إيداع حوالة', 'amount': '+50,000', 'remaining': '150,000', 'color': Colors.green},
    {'date': '2026-03-22 14:15', 'agent': 'شبكة الصقر', 'type': 'خصم آلي (عمولة)', 'amount': '-2,500', 'remaining': '100,000', 'color': Colors.red},
    {'date': '2026-03-21 09:00', 'agent': 'وكالة النور', 'type': 'تسوية يدوية (مكافأة)', 'amount': '+5,000', 'remaining': '5,000', 'color': Colors.blue},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ==========================================
  // النوافذ المنبثقة للتبويب الأول (طلبات الشحن)
  // ==========================================
  void _acceptRequest(int index) {
    setState(() {
      _rechargeRequests.removeAt(index);
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تأكيد الشحن وإيداع المبلغ في محفظة الوكيل بنجاح ✅'), backgroundColor: Colors.green));
  }

  void _showRejectDialog(int index) {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('رفض طلب الشحن ❌', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('يرجى كتابة سبب الرفض (سيصل للوكيل كإشعار):'),
              const SizedBox(height: 10),
              TextField(
                decoration: InputDecoration(
                  hintText: 'مثال: رقم المرجع خاطئ، أو الحوالة لم تصل بعد...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                setState(() {
                  _rechargeRequests.removeAt(index);
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم رفض الطلب وإشعار الوكيل بالسبب.'), backgroundColor: Colors.red));
              },
              child: const Text('تأكيد الرفض', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // النوافذ المنبثقة للتبويب الثاني (أرصدة المحافظ)
  // ==========================================
  void _showManualSettlementDialog(String agentName) {
    int settlementType = 1; // 1: إضافة, 2: خصم
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: Text('تسوية يدوية لمحفظة: $agentName', style: const TextStyle(fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: RadioListTile(
                          title: const Text('إضافة 🟢', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                          value: 1,
                          groupValue: settlementType,
                          onChanged: (val) => setStateDialog(() => settlementType = val as int),
                        ),
                      ),
                      Expanded(
                        child: RadioListTile(
                          title: const Text('خصم 🔴', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                          value: 2,
                          groupValue: settlementType,
                          onChanged: (val) => setStateDialog(() => settlementType = val as int),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _buildTextField('المبلغ (بالريال)', Icons.money),
                  const SizedBox(height: 10),
                  _buildTextField('السبب (إجباري للتسجيل بالسجل)', Icons.edit_note),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت التسوية بنجاح وتحديث السجل الشامل.')));
                },
                child: const Text('تنفيذ التسوية'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDangerLimitDialog(String agentName, int currentLimit) {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('ضبط حد الخطر المخصص 🎛️', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('الوكيل: $agentName', style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 10),
              TextFormField(
                initialValue: currentLimit.toString(),
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'رصيد التنبيه (بالريال)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('حفظ الحد')),
          ],
        ),
      ),
    );
  }

  void _showPdfStatementDialog(String agentName) {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text('توليد كشف حساب: $agentName', style: const TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTextField('من تاريخ (YYYY-MM-DD)', Icons.date_range),
              _buildTextField('إلى تاريخ (YYYY-MM-DD)', Icons.date_range),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('جاري توليد ملف الـ PDF الرسمي...'), backgroundColor: Colors.red));
              },
              icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
              label: const Text('تصدير الكشف (PDF)', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 👈 تم تركيب الهيدر الشامل هنا بنجاح!
      appBar: const CustomHeader(title: 'المركز المالي والمحافظ'),
      
      drawer: const CustomDrawer(
        userName: 'مالك النظام',
        phoneNumber: '774578241',
        role: 'مالك النظام (Super Admin)',
        balanceOrPoints: 'أرباح النظام: 5,430,000 ريال',
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Column( // غلّفنا الـ TabBar والـ TabBarView في عمود ليظهروا تحت الهيدر الجديد بشكل صحيح
          children: [
            // شريط التبويبات (Tabs)
            Container(
              color: Colors.white,
              child: TabBar(
                controller: _tabController,
                labelColor: Colors.blueAccent,
                unselectedLabelColor: Colors.grey,
                indicatorColor: Colors.blueAccent,
                indicatorWeight: 3,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                tabs: const [
                  Tab(icon: Icon(Icons.download), text: 'طلبات الشحن'),
                  Tab(icon: Icon(Icons.account_balance_wallet), text: 'أرصدة المحافظ'),
                  Tab(icon: Icon(Icons.receipt_long), text: 'السجل الشامل'),
                ],
              ),
            ),
            
            // محتوى التبويبات (يجب أن يكون بداخل Expanded ليأخذ باقي الشاشة)
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildRechargeRequestsTab(),
                  _buildWalletsTab(),
                  _buildLedgerTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // التبويب الأول: طلبات شحن المحافظ 📥
  // ==========================================
  Widget _buildRechargeRequestsTab() {
    if (_rechargeRequests.isEmpty) return const Center(child: Text('لا توجد طلبات شحن قيد الانتظار.'));
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _rechargeRequests.length,
      itemBuilder: (context, index) {
        final req = _rechargeRequests[index];
        return Card(
          elevation: 3,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(req['agent'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue)),
                    Text(req['date'], style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
                const Divider(),
                _buildInfoRow('المودع:', req['depositor']),
                _buildInfoRow('المبلغ:', '${req['amount']} ريال', isBold: true, color: Colors.green),
                _buildInfoRow('البنك المحول منه:', req['bank']),
                _buildInfoRow('رقم المرجع:', req['ref']),
                _buildInfoRow('المستفيد (أنت):', req['beneficiary']),
                const SizedBox(height: 10),
                
                // زر عرض صورة الحوالة
                OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.image, size: 18),
                  label: const Text('عرض صورة سند التحويل'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 40)),
                ),
                const SizedBox(height: 10),

                // أزرار القبول والرفض
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _acceptRequest(index),
                        icon: const Icon(Icons.check_circle, color: Colors.white),
                        label: const Text('تأكيد الشحن ✅', style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _showRejectDialog(index),
                        icon: const Icon(Icons.cancel, color: Colors.white),
                        label: const Text('رفض مع السبب ❌', style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ==========================================
  // التبويب الثاني: أرصدة المحافظ الحالية 💰
  // ==========================================
  Widget _buildWalletsTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _wallets.length,
      itemBuilder: (context, index) {
        final wallet = _wallets[index];
        final isDanger = wallet['balance'] <= wallet['dangerLimit'];

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: BorderSide(color: isDanger ? Colors.red : Colors.transparent, width: 2),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(wallet['agent'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Row(
                      children: [
                        if (isDanger) const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
                        const SizedBox(width: 5),
                        Text('${wallet['balance']} ريال', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDanger ? Colors.red : Colors.green)),
                      ],
                    ),
                  ],
                ),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildIconButton(Icons.settings, 'تسوية يدوية', Colors.blue, () => _showManualSettlementDialog(wallet['agent'])),
                    _buildIconButton(Icons.tune, 'حد الخطر', Colors.orange, () => _showDangerLimitDialog(wallet['agent'], wallet['dangerLimit'])),
                    _buildIconButton(Icons.picture_as_pdf, 'كشف حساب', Colors.red, () => _showPdfStatementDialog(wallet['agent'])),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ==========================================
  // التبويب الثالث: سجل الحركات المالي الشامل 📜
  // ==========================================
  Widget _buildLedgerTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _ledger.length,
      itemBuilder: (context, index) {
        final log = _ledger[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: log['color'].withOpacity(0.1),
              child: Icon(Icons.swap_horiz, color: log['color']),
            ),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(log['agent'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text(log['amount'], style: TextStyle(fontWeight: FontWeight.bold, color: log['color'], fontSize: 14), textDirection: TextDirection.ltr),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(log['type'], style: const TextStyle(color: Colors.black87)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(log['date'], style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    Text('الرصيد المتبقي: ${log['remaining']}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // دوال مساعدة للتصميم
  Widget _buildInfoRow(String title, String value, {bool isBold = false, Color color = Colors.black87}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(color: Colors.blueGrey)),
          Text(value, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: color)),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, IconData icon) {
    return TextField(
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.blueAccent),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
      ),
    );
  }

  Widget _buildIconButton(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 12, color: color)),
        ],
      ),
    );
  }
}
