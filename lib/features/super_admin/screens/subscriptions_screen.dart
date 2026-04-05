import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/system_provider.dart'; 
import '../../../core/widgets/custom_drawer.dart';
import '../../../core/widgets/custom_header.dart';

class SubscriptionsScreen extends StatefulWidget {
  const SubscriptionsScreen({super.key});

  @override
  State<SubscriptionsScreen> createState() => _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends State<SubscriptionsScreen> {

  // ==========================================
  // 1. نافذة إنشاء خطة / اشتراك جديد ➕ (مربوطة بالسحابة)
  // ==========================================
  void _showCreatePlanDialog(SystemProvider provider) {
    int targetingFilter = 1; // 1: الكل, 2: وكيل محدد
    
    final planNameController = TextEditingController();
    final durationController = TextEditingController();
    final phoneController = TextEditingController(); // للوكيل المحدد

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.add_box, color: Colors.blue),
                SizedBox(width: 8),
                Text('إنشاء وتطبيق خطة جديدة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTextField('اسم الخطة (مثال: باقة 5% مفتوح)', Icons.star, controller: planNameController),
                  _buildTextField('مدة الخطة (بالأشهر)', Icons.calendar_today, isNumber: true, controller: durationController),
                  
                  const Divider(),
                  const Text('الاستهداف والتطبيق السحابي:', style: TextStyle(fontWeight: FontWeight.bold)),
                  RadioListTile(
                    title: const Text('تطبيق على جميع الوكلاء (دفعة واحدة)'),
                    value: 1,
                    groupValue: targetingFilter,
                    onChanged: (val) => setStateDialog(() => targetingFilter = val as int),
                  ),
                  RadioListTile(
                    title: const Text('تطبيق على وكيل محدد فقط'),
                    value: 2,
                    groupValue: targetingFilter,
                    onChanged: (val) => setStateDialog(() => targetingFilter = val as int),
                  ),
                  if (targetingFilter == 2)
                    _buildTextField('رقم هاتف الوكيل المستهدف', Icons.phone, isNumber: true, controller: phoneController),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء', style: TextStyle(color: Colors.red))),
              ElevatedButton(
                onPressed: () {
                  if (planNameController.text.isNotEmpty && durationController.text.isNotEmpty) {
                    if (targetingFilter == 2 && phoneController.text.isEmpty) {
                       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى إدخال رقم الوكيل المستهدف ❌', textDirection: TextDirection.rtl), backgroundColor: Colors.red));
                       return;
                    }

                    final messenger = ScaffoldMessenger.of(context);
                    int months = int.tryParse(durationController.text) ?? 1;

                    // 1. إرسال الأوامر للسحابة (بدون تعطيل الشاشة)
                    provider.applySubscriptionPlan(
                      targetingFilter: targetingFilter,
                      planName: planNameController.text,
                      durationMonths: months,
                      targetAgentPhone: phoneController.text,
                    ).catchError((error) {
                      messenger.showSnackBar(SnackBar(content: Text('فشل التطبيق ❌: $error', textDirection: TextDirection.rtl), backgroundColor: Colors.red));
                    });

                    // 2. إغلاق النافذة فوراً
                    Navigator.pop(context);
                    
                    // 3. إشعار النجاح المبدئي
                    messenger.showSnackBar(const SnackBar(content: Text('تم إرسال الخطة للروبوت الآلي لتطبيقها سحابياً 🚀', textDirection: TextDirection.rtl), backgroundColor: Colors.blueGrey));
                  } else {
                     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى تعبئة الحقول الأساسية ❌', textDirection: TextDirection.rtl), backgroundColor: Colors.red));
                  }
                },
                child: const Text('اعتماد وتطبيق الخطة'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // 2. نافذة إنشاء كوبون ترويجي ذكي 🎟️
  // ==========================================
  void _showCreateCouponDialog(SystemProvider provider) {
    final codeController = TextEditingController();
    final discountController = TextEditingController();
    final maxUsesController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.local_offer, color: Colors.green),
              SizedBox(width: 8),
              Text('توليد كوبون ذكي', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTextField('كود الكوبون (مثال: YEMEN2026)', Icons.local_offer, controller: codeController),
              _buildTextField('تفاصيل الخصم (مثال: شهر مجاني)', Icons.discount, controller: discountController),
              _buildTextField('الحد الأقصى لعدد الاستخدامات (مثال: 50)', Icons.group, isNumber: true, controller: maxUsesController),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green), 
              onPressed: () {
                if (codeController.text.isNotEmpty && maxUsesController.text.isNotEmpty) {
                  final messenger = ScaffoldMessenger.of(context);
                  int maxUses = int.tryParse(maxUsesController.text) ?? 10;

                  provider.createSmartCoupon(
                    code: codeController.text,
                    discountDetails: discountController.text,
                    maxUses: maxUses,
                  ).catchError((error) {
                    messenger.showSnackBar(SnackBar(content: Text('فشل توليد الكوبون ❌: $error', textDirection: TextDirection.rtl), backgroundColor: Colors.red));
                  });

                  Navigator.pop(context);
                  messenger.showSnackBar(const SnackBar(content: Text('جاري زرع الكوبون في السحابة... ☁️🎟️', textDirection: TextDirection.rtl), backgroundColor: Colors.green));
                }
              }, 
              child: const Text('توليد الكوبون', style: TextStyle(color: Colors.white))
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // 3. نافذة تعديل فترة السماح / الانتهاء ⏳
  // ==========================================
  void _showEditGracePeriodDialog(String agentName, String agentPhone, SystemProvider provider) {
    final dateController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text('تعديل فترة: $agentName', style: const TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('بمجرد الحفظ، سيتم تعديل تاريخ الانتهاء وتحويل الوكيل لحالة (إنذار).', style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.5)),
              const SizedBox(height: 15),
              _buildTextField('تاريخ الانتهاء الجديد (YYYY-MM-DD)', Icons.stop_circle_outlined, controller: dateController),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () {
                if (dateController.text.isNotEmpty) {
                  final messenger = ScaffoldMessenger.of(context);
                  
                  provider.updateAgentGracePeriod(agentPhone, dateController.text).catchError((error) {
                    messenger.showSnackBar(SnackBar(content: Text('فشل التعديل ❌: $error', textDirection: TextDirection.rtl), backgroundColor: Colors.red));
                  });

                  Navigator.pop(context);
                  messenger.showSnackBar(const SnackBar(content: Text('تم إرسال إحداثيات الرادار للسحابة ⏱️', textDirection: TextDirection.rtl), backgroundColor: Colors.blueGrey));
                }
              }, 
              child: const Text('تحديث العداد')
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // 4. نافذة السجل التاريخي الحقيقي 📜
  // ==========================================
  void _showHistoryLog(String agentName, String agentPhone, SystemProvider provider) {
    // فلترة السجل الخاص بهذا الوكيل فقط
    final agentLogs = provider.auditLogs.where((log) => log['targetPhone'] == agentPhone || log['phone'] == agentPhone).toList();

    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text('السجل التاريخي لـ: $agentName', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          content: SizedBox(
            width: double.maxFinite,
            child: agentLogs.isEmpty
                ? const Center(child: Text('لا توجد سجلات تاريخية لهذا الوكيل بعد.', style: TextStyle(color: Colors.grey)))
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: agentLogs.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (context, index) {
                      final log = agentLogs[index];
                      return ListTile(
                        leading: const Icon(Icons.history, color: Colors.blueGrey),
                        title: Text(log['action'] ?? 'إجراء مجهول', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: Text('${log['details']}\nالتاريخ: ${log['datetime']}', style: const TextStyle(fontSize: 12)),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق')),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // إيقاف واستئناف الخطة ⏸️ ▶️
  // ==========================================
  void _togglePausePlan(String agentPhone, String currentStatus, SystemProvider provider) {
    final messenger = ScaffoldMessenger.of(context);
    
    provider.toggleSubscriptionStatus(agentPhone, currentStatus).catchError((error) {
      messenger.showSnackBar(SnackBar(content: Text('فشل الإجراء ❌: $error', textDirection: TextDirection.rtl), backgroundColor: Colors.red));
    });

    messenger.showSnackBar(SnackBar(
      content: Text(currentStatus == 'موقوف مؤقتاً' ? 'جاري استئناف الخطة... ▶️' : 'جاري إيقاف الخطة... ⏸️', textDirection: TextDirection.rtl),
      backgroundColor: Colors.blueGrey,
      duration: const Duration(seconds: 1),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final systemProvider = Provider.of<SystemProvider>(context);
    final adminBalance = systemProvider.adminMainBalance;
    final agents = systemProvider.agentsList; // 👈 جلب الوكلاء الفعليين
    final stats = systemProvider.subscriptionStats; // 👈 إحصائيات الرادار

    return Scaffold(
      appBar: const CustomHeader(title: 'إدارة الاشتراكات والخطط'),
      
      drawer: CustomDrawer(
        userName: systemProvider.currentUserName,
        phoneNumber: systemProvider.currentUserPhone,
        role: 'مالك النظام (Super Admin)',
        balanceOrPoints: 'أرباح النظام: ${adminBalance.toStringAsFixed(0)} ريال',
      ),
      
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            // === 💡 1. شريط إحصائيات الرادار (Dashboard) ===
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark ? Colors.black26 : Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem('نشط', stats['active'].toString(), Colors.green),
                  _buildStatItem('إنذار', stats['expiringSoon'].toString(), Colors.orange),
                  _buildStatItem('موقوف/مجمد', stats['frozen'].toString(), Colors.red),
                  _buildStatItem('الأرباح المتوقعة', '${stats['expectedRevenue']} ريال', Colors.blue),
                ],
              ),
            ),

            // === 2. أدوات التخصيص العلوية ===
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () => _showCreatePlanDialog(systemProvider),
                      icon: const Icon(Icons.add, color: Colors.white),
                      label: const Text('تطبيق خطة / اشتراك', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, padding: const EdgeInsets.symmetric(vertical: 12)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 1,
                    child: ElevatedButton.icon(
                      onPressed: () => _showCreateCouponDialog(systemProvider),
                      icon: const Icon(Icons.local_offer, color: Colors.white),
                      label: const Text('توليد كوبون', style: TextStyle(color: Colors.white, fontSize: 13)),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, padding: const EdgeInsets.symmetric(vertical: 12)),
                    ),
                  ),
                ],
              ),
            ),

            // === 3. جدول المراقبة الرئيسي الحقيقي ===
            Expanded(
              child: agents.isEmpty
                  ? const Center(child: Text('لا يوجد وكلاء في النظام حالياً.', style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      itemCount: agents.length,
                      padding: const EdgeInsets.all(16),
                      itemBuilder: (context, index) {
                        final agent = agents[index];
                        final subStatus = agent['subStatus'] ?? 'غير محدد';
                        final isPaused = subStatus == 'موقوف مؤقتاً' || subStatus == 'مجمد';
                        
                        // تحديد لون الحالة
                        Color statusColor = Colors.grey;
                        if (subStatus == 'نشط' || subStatus == 'فترة مجانية') statusColor = Colors.green;
                        if (subStatus == 'إنذار') statusColor = Colors.orange;
                        if (subStatus == 'موقوف مؤقتاً' || subStatus == 'مجمد') statusColor = Colors.red;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 15),
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: statusColor.withOpacity(0.5))),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(agent['name'] ?? 'مجهول', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(color: statusColor, borderRadius: BorderRadius.circular(20)),
                                      child: Text(subStatus, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 5),
                                Text('الهاتف: ${agent['phone']} | الشبكة: ${agent['networkName']}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                Text('الخطة الحالية: ${agent['subPlan'] ?? 'افتراضية'}', style: const TextStyle(color: Colors.blueGrey, fontSize: 14)),
                                Text('تاريخ الانتهاء: ${agent['subExpiry'] ?? 'غير محدد'}', style: TextStyle(color: statusColor == Colors.orange ? Colors.orange : Colors.grey, fontWeight: FontWeight.bold, fontSize: 14)),
                                
                                const Divider(),
                                // === أزرار التحكم الفردية ===
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: [
                                    _buildActionButton(Icons.edit_calendar, 'تعديل فترة السماح', Colors.blue, () => _showEditGracePeriodDialog(agent['name'], agent['phone'], systemProvider)),
                                    _buildActionButton(
                                      isPaused ? Icons.play_arrow : Icons.pause_circle_outline,
                                      isPaused ? 'استئناف' : 'إيقاف مؤقت',
                                      isPaused ? Colors.green : Colors.deepOrange,
                                      () => _togglePausePlan(agent['phone'], subStatus, systemProvider),
                                    ),
                                    _buildActionButton(Icons.history_edu, 'السجل التاريخي', Colors.blueGrey, () => _showHistoryLog(agent['name'], agent['phone'], systemProvider)),
                                  ],
                                ),
                              ],
                            ),
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

  // أداة بناء إحصائيات الرادار
  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: color)),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.blueGrey)),
      ],
    );
  }

  // أداة بناء حقول الإدخال
  Widget _buildTextField(String label, IconData icon, {bool isNumber = false, TextEditingController? controller}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.blueAccent),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }

  // أداة بناء أزرار الإجراءات
  Widget _buildActionButton(IconData icon, String tooltip, Color color, VoidCallback onTap) {
    return IconButton(
      icon: Icon(icon, color: color),
      tooltip: tooltip,
      onPressed: onTap,
    );
  }
}
