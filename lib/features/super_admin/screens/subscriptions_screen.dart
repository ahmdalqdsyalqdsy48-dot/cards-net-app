import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math';

import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/providers/wallet_provider.dart';
import '../../../core/providers/agent_admin_provider.dart';
import '../../../core/providers/coupon_provider.dart';
import '../../../core/providers/audit_provider.dart';
import '../../../core/providers/ui_provider.dart';
import '../../../core/widgets/custom_drawer.dart';
import '../../../core/widgets/custom_header.dart';

class SubscriptionsScreen extends StatefulWidget {
  const SubscriptionsScreen({super.key});

  @override
  State<SubscriptionsScreen> createState() => _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends State<SubscriptionsScreen> {
  String _selectedFilter = 'الكل';

  void _play(String type) =>
      context.read<UiProvider>().playSound(type);

  // ==========================================
  // 1. تطبيق خطة / اشتراك
  // ==========================================
  void _showCreatePlanDialog(AgentAdminProvider agentAdmin) {
    _play('click');
    int targetingFilter = 1;
    final planNameController = TextEditingController();
    final planPriceController = TextEditingController();
    final durationController = TextEditingController();
    final phoneController = TextEditingController();

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
                Text('تطبيق خطة / تجديد',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTextField('اسم الخطة (مثال: باقة 5%)', Icons.star,
                      controller: planNameController),
                  _buildTextField('قيمة الباقة بالريال (لحساب الأرباح)',
                      Icons.monetization_on,
                      isNumber: true,
                      controller: planPriceController),
                  _buildTextField('المدة (بالأشهر)', Icons.calendar_today,
                      isNumber: true, controller: durationController),
                  const Divider(),
                  const Text('الاستهداف السحابي:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  RadioListTile(
                    title: const Text('تطبيق على جميع الوكلاء'),
                    value: 1,
                    groupValue: targetingFilter,
                    onChanged: (val) {
                      _play('click');
                      setStateDialog(() => targetingFilter = val as int);
                    },
                  ),
                  RadioListTile(
                    title: const Text('تطبيق على وكيل محدد'),
                    value: 2,
                    groupValue: targetingFilter,
                    onChanged: (val) {
                      _play('click');
                      setStateDialog(() => targetingFilter = val as int);
                    },
                  ),
                  if (targetingFilter == 2)
                    _buildTextField('رقم الوكيل المستهدف', Icons.phone,
                        isNumber: true, controller: phoneController),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () {
                    _play('click');
                    Navigator.pop(context);
                  },
                  child: const Text('إلغاء',
                      style: TextStyle(color: Colors.red))),
              ElevatedButton(
                onPressed: () {
                  if (planNameController.text.isNotEmpty &&
                      durationController.text.isNotEmpty &&
                      planPriceController.text.isNotEmpty) {
                    _play('click');
                    final messenger = ScaffoldMessenger.of(context);
                    int months = int.tryParse(durationController.text) ?? 1;
                    double price =
                        double.tryParse(planPriceController.text) ?? 0.0;

                    agentAdmin
                        .applySubscriptionPlan(
                      targetingFilter: targetingFilter,
                      planName: planNameController.text,
                      planPrice: price,
                      durationMonths: months,
                      targetAgentPhone: phoneController.text,
                    )
                        .then((_) {
                      _play('success');
                    }).catchError((e) {
                      _play('error');
                      messenger.showSnackBar(
                          SnackBar(content: Text('خطأ: $e')));
                    });

                    Navigator.pop(context);
                    messenger.showSnackBar(const SnackBar(
                        content: Text('جاري تطبيق الخطة سحابياً 🚀',
                            textDirection: TextDirection.rtl)));
                  }
                },
                child: const Text('اعتماد'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // 2. نافذة الكوبونات
  // ==========================================
  void _showCouponsManagerDialog(CouponProvider couponProvider) {
    _play('click');
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          contentPadding: EdgeInsets.zero,
          title: const Row(
            children: [
              Icon(Icons.local_offer, color: Colors.orange),
              SizedBox(width: 8),
              Text('مركز الكوبونات الذكية',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 450,
            child: DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  TabBar(
                    labelColor: Colors.orange,
                    indicatorColor: Colors.orange,
                    onTap: (index) => _play('click'),
                    tabs: const [
                      Tab(text: 'توليد جديد ➕'),
                      Tab(text: 'الكوبونات النشطة 📊')
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildCreateCouponTab(couponProvider, context),
                        _buildActiveCouponsTab(couponProvider),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () {
                  _play('click');
                  Navigator.pop(context);
                },
                child: const Text('إغلاق')),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateCouponTab(
      CouponProvider couponProvider, BuildContext parentContext) {
    final codeController = TextEditingController();
    final discountValueController = TextEditingController();
    final maxUsesController = TextEditingController();
    String discountType = 'تمديد أيام مجانية';
    String sendMethod = 'إرسال إشعار داخل التطبيق 📱';

    return StatefulBuilder(
      builder: (context, setStateTab) => SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                    child: _buildTextField(
                        'كود الكوبون', Icons.qr_code, controller: codeController)),
                IconButton(
                  icon: const Icon(Icons.casino, color: Colors.orange),
                  tooltip: 'توليد آلي 🎲',
                  onPressed: () {
                    _play('click');
                    const chars =
                        'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
                    final rnd = Random();
                    setStateTab(() {
                      codeController.text =
                          'NET-${String.fromCharCodes(Iterable.generate(6, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))))}';
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: discountType,
              decoration: InputDecoration(
                  labelText: 'نوع الخصم',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10))),
              items: ['تمديد أيام مجانية', 'خصم نسبة مئوية %']
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (val) {
                _play('click');
                setStateTab(() => discountType = val!);
              },
            ),
            const SizedBox(height: 15),
            _buildTextField('قيمة الخصم (رقم فقط)', Icons.numbers,
                isNumber: true, controller: discountValueController),
            _buildTextField('حد الاستخدام (مثال: 50 وكيل)', Icons.group,
                isNumber: true, controller: maxUsesController),
            const Divider(),
            DropdownButtonFormField<String>(
              value: sendMethod,
              decoration: InputDecoration(
                  labelText: 'قناة الإرسال',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  prefixIcon: const Icon(Icons.send)),
              items: [
                'إرسال إشعار داخل التطبيق 📱',
                'إرسال رسالة SMS 💬',
                'الكل (تطبيق + SMS) 🚀'
              ]
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (val) {
                _play('click');
                setStateTab(() => sendMethod = val!);
              },
            ),
            const SizedBox(height: 15),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    padding: const EdgeInsets.symmetric(vertical: 12)),
                onPressed: () {
                  if (codeController.text.isNotEmpty &&
                      discountValueController.text.isNotEmpty &&
                      maxUsesController.text.isNotEmpty) {
                    _play('click');
                    final messenger =
                        ScaffoldMessenger.of(parentContext);

                    couponProvider.createSmartCoupon(
                      code: codeController.text,
                      discountDetails:
                          '$discountType: ${discountValueController.text}',
                      maxUses: int.parse(maxUsesController.text),
                      sendMethod: sendMethod,
                    ).then((_) {
                      _play('success');
                    }).catchError((e) {
                      _play('error');
                      messenger.showSnackBar(SnackBar(
                          content: Text('خطأ: $e')));
                    });

                    Navigator.pop(parentContext);
                    messenger.showSnackBar(SnackBar(
                        content: Text(
                            'تم توليد الكوبون وتسجيل أمر الإرسال ✅',
                            textDirection: TextDirection.rtl),
                        backgroundColor: Colors.green));
                  }
                },
                child: const Text('توليد وحفظ وإرسال',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveCouponsTab(CouponProvider couponProvider) {
    final coupons = couponProvider.coupons;
    if (coupons.isEmpty)
      return const Center(
          child: Text('لا توجد كوبونات',
              style: TextStyle(color: Colors.grey)));

    return ListView.builder(
      itemCount: coupons.length,
      itemBuilder: (context, index) {
        final coupon = coupons[index];
        final isActive = coupon['isActive'] ?? false;

        return ListTile(
          leading: Icon(
              isActive ? Icons.local_offer : Icons.block,
              color: isActive ? Colors.green : Colors.red),
          title: Text(coupon['code'],
              style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(
              '${coupon['discountDetails']}\nالاستخدام: ${coupon['usedCount']} / ${coupon['maxUses']}'),
          trailing: isActive
              ? IconButton(
                  icon: const Icon(Icons.power_settings_new,
                      color: Colors.red),
                  tooltip: 'إعدام الكوبون فوراً',
                  onPressed: () {
                    _play('click');
                    couponProvider.deactivateCoupon(
                        coupon['docId'], coupon['code']);
                    _play('success');
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text(
                              'تم إيقاف الكوبون بنجاح 🚫',
                              textDirection: TextDirection.rtl),
                          backgroundColor: Colors.red),
                    );
                  },
                )
              : const Text('منتهي',
                  style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold)),
        );
      },
    );
  }

  // ==========================================
  // 3. نافذة تعديل فترة السماح
  // ==========================================
  Future<void> _showEditGracePeriodDialog(
      String agentName, String agentPhone, AgentAdminProvider agentAdmin) async {
    _play('click');
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
                primary: Colors.blueAccent,
                onPrimary: Colors.white,
                onSurface: Colors.black),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      String formattedDate =
          '${pickedDate.year}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}';
      final messenger = ScaffoldMessenger.of(context);

      agentAdmin
          .updateAgentGracePeriod(agentPhone, formattedDate)
          .then((_) {
            _play('success');
          })
          .catchError((error) {
            _play('error');
            messenger.showSnackBar(SnackBar(
                content: Text('فشل التعديل ❌: $error',
                    textDirection: TextDirection.rtl),
                backgroundColor: Colors.red));
          });

      messenger.showSnackBar(SnackBar(
          content: Text(
              'تم تمديد $agentName حتى $formattedDate ⏱️',
              textDirection: TextDirection.rtl),
          backgroundColor: Colors.blueGrey));
    }
  }

  // ==========================================
  // 4. نافذة السجل التاريخي
  // ==========================================
  void _showHistoryLog(
      String agentName, String agentPhone, AuditProvider auditProvider) {
    _play('click');
    final agentLogs = auditProvider.auditLogs
        .where((log) =>
            log['targetPhone'] == agentPhone || log['phone'] == agentPhone)
        .toList();

    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text('الخط الزمني لـ: $agentName',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 16)),
          content: SizedBox(
            width: double.maxFinite,
            child: agentLogs.isEmpty
                ? const Center(
                    child: Text('لا توجد سجلات تاريخية.',
                        style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: agentLogs.length,
                    itemBuilder: (context, index) {
                      final log = agentLogs[index];
                      Color dotColor = Colors.blue;
                      if (log['action'].toString().contains('تجميد') ||
                          log['action'].toString().contains('حذف'))
                        dotColor = Colors.red;
                      if (log['action'].toString().contains('تطبيق') ||
                          log['action'].toString().contains('تجديد'))
                        dotColor = Colors.green;
                      if (log['action'].toString().contains('تعديل'))
                        dotColor = Colors.orange;

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(
                            children: [
                              Container(
                                  width: 15,
                                  height: 15,
                                  decoration: BoxDecoration(
                                      color: dotColor,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: Colors.white, width: 2))),
                              if (index != agentLogs.length - 1)
                                Container(
                                    width: 2,
                                    height: 50,
                                    color: Colors.grey.withOpacity(0.3)),
                            ],
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Padding(
                              padding:
                                  const EdgeInsets.only(bottom: 15.0),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(log['action'] ?? 'إجراء',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: dotColor)),
                                  Text(log['details'],
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey)),
                                  Text(log['datetime'],
                                      style: const TextStyle(
                                          fontSize: 10,
                                          color: Colors.blueGrey,
                                          fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
                onPressed: () {
                  _play('click');
                  Navigator.pop(context);
                },
                child: const Text('إغلاق'))
          ],
        ),
      ),
    );
  }

  void _togglePausePlan(
      String agentPhone, String currentStatus, AgentAdminProvider agentAdmin) {
    _play('click');
    final messenger = ScaffoldMessenger.of(context);
    agentAdmin
        .toggleSubscriptionStatus(agentPhone, currentStatus)
        .then((_) {
          _play('success');
        })
        .catchError((error) {
          _play('error');
          messenger.showSnackBar(SnackBar(
              content: Text('خطأ: $error',
                  textDirection: TextDirection.rtl)));
        });
    messenger.showSnackBar(SnackBar(
        content: Text(
            currentStatus == 'موقوف مؤقتاً'
                ? 'جاري الاستئناف... ▶️'
                : 'جاري الإيقاف... ⏸️',
            textDirection: TextDirection.rtl),
        backgroundColor: Colors.blueGrey,
        duration: const Duration(seconds: 1)));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final settings = context.watch<SettingsProvider>();
    final wallet = context.watch<WalletProvider>();
    final agentAdmin = context.read<AgentAdminProvider>();
    final couponProvider = context.read<CouponProvider>();
    final auditProvider = context.read<AuditProvider>();

    final stats = wallet.subscriptionStats;

    List<Map<String, dynamic>> displayedAgents = wallet.agentsList.where((agent) {
      String status = agent['subStatus'] ?? 'نشط';
      if (_selectedFilter == 'الكل') return true;
      if (_selectedFilter == 'نشط' &&
          (status == 'نشط' || status == 'فترة مجانية')) return true;
      if (_selectedFilter == 'إنذار' && status == 'إنذار') return true;
      if (_selectedFilter == 'مجمد' &&
          (status == 'مجمد' || status == 'موقوف مؤقتاً')) return true;
      return false;
    }).toList();

    return Scaffold(
      appBar: const CustomHeader(title: 'الرادار والاشتراكات'),
      drawer: CustomDrawer(
        userName: wallet.currentUserName,
        phoneNumber: auth.activeUserPhone ?? '',
        role: 'مالك النظام',
        balanceOrPoints:
            'أرباح النظام: ${settings.adminMainBalance.toStringAsFixed(0)} ريال',
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {});
          await Future.delayed(const Duration(milliseconds: 300));
          _play('success');
        },
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.black26
                    : Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10)
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem(
                      'نشط', stats['active'].toString(), Colors.green),
                  _buildStatItem('إنذار',
                      stats['expiringSoon'].toString(), Colors.orange),
                  _buildStatItem(
                      'موقوف', stats['frozen'].toString(), Colors.red),
                  _buildStatItem('متوقع',
                      '${stats['expectedRevenue']} ر.ي', Colors.blue),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          _showCreatePlanDialog(agentAdmin),
                      icon: const Icon(Icons.flash_on,
                          color: Colors.white),
                      label: const Text('تطبيق خطة',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          padding: const EdgeInsets.symmetric(
                              vertical: 12)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 1,
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          _showCouponsManagerDialog(couponProvider),
                      icon: const Icon(Icons.local_offer,
                          color: Colors.white),
                      label: const Text('كوبونات',
                          style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          padding: const EdgeInsets.symmetric(
                              vertical: 12)),
                    ),
                  ),
                ],
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10),
              child: Row(
                children: ['الكل', 'نشط', 'إنذار', 'مجمد'].map((filter) {
                  bool isSelected = _selectedFilter == filter;
                  return Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: ChoiceChip(
                      label: Text(filter,
                          style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : Colors.black87,
                              fontWeight: FontWeight.bold)),
                      selected: isSelected,
                      selectedColor: Colors.blueAccent,
                      backgroundColor:
                          Colors.grey.withOpacity(0.2),
                      onSelected: (val) {
                        _play('click');
                        setState(() => _selectedFilter = filter);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            Expanded(
              child: displayedAgents.isEmpty
                  ? Center(
                      child: Text(
                      'لا يوجد وكلاء في قسم "$_selectedFilter"',
                      style: const TextStyle(color: Colors.grey),
                    ))
                  : ListView.builder(
                      itemCount: displayedAgents.length,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 5),
                      itemBuilder: (context, index) {
                        final agent = displayedAgents[index];
                        final subStatus =
                            agent['subStatus'] ?? 'نشط';
                        final isPaused = subStatus == 'موقوف مؤقتاً' ||
                            subStatus == 'مجمد';

                        Color statusColor = Colors.grey;
                        if (subStatus == 'نشط' ||
                            subStatus == 'فترة مجانية')
                          statusColor = Colors.green;
                        if (subStatus == 'إنذار')
                          statusColor = Colors.orange;
                        if (subStatus == 'موقوف مؤقتاً' ||
                            subStatus == 'مجمد')
                          statusColor = Colors.red;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(15),
                              side: BorderSide(
                                  color: statusColor
                                      .withOpacity(0.3))),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment
                                          .spaceBetween,
                                  children: [
                                    Text(
                                        agent['name'] ?? 'مجهول',
                                        style: const TextStyle(
                                            fontWeight:
                                                FontWeight.bold,
                                            fontSize: 16)),
                                    Container(
                                      padding: const EdgeInsets
                                          .symmetric(
                                          horizontal: 8,
                                          vertical: 4),
                                      decoration: BoxDecoration(
                                          color: statusColor
                                              .withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(
                                                  20),
                                          border: Border.all(
                                              color: statusColor)),
                                      child: Text(subStatus,
                                          style: TextStyle(
                                              color: statusColor,
                                              fontSize: 12,
                                              fontWeight:
                                                  FontWeight.bold)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 5),
                                Text(
                                    'الهاتف: ${agent['phone']}',
                                    style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 12)),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment
                                          .spaceBetween,
                                  children: [
                                    Text(
                                        'الخطة: ${agent['subPlan'] ?? 'افتراضية'}',
                                        style: const TextStyle(
                                            color: Colors.blueGrey,
                                            fontSize: 13)),
                                    Text(
                                        'الانتهاء: ${agent['subExpiry'] ?? '--'}',
                                        style: TextStyle(
                                            color: statusColor,
                                            fontWeight:
                                                FontWeight.bold,
                                            fontSize: 13)),
                                  ],
                                ),
                                const Divider(),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment
                                          .spaceEvenly,
                                  children: [
                                    _buildActionButton(
                                        Icons.calendar_month,
                                        'تعديل التقويم',
                                        Colors.blue,
                                        () => _showEditGracePeriodDialog(
                                            agent['name'],
                                            agent['phone'],
                                            agentAdmin)),
                                    _buildActionButton(
                                      isPaused
                                          ? Icons.play_circle_fill
                                          : Icons
                                              .pause_circle_filled,
                                      isPaused
                                          ? 'استئناف'
                                          : 'إيقاف',
                                      isPaused
                                          ? Colors.green
                                          : Colors.redAccent,
                                      () => _togglePausePlan(
                                          agent['phone'],
                                          subStatus,
                                          agentAdmin),
                                    ),
                                    _buildActionButton(
                                        Icons.timeline,
                                        'الخط الزمني',
                                        Colors.blueGrey,
                                        () => _showHistoryLog(
                                            agent['name'],
                                            agent['phone'],
                                            auditProvider)),
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

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value,
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 18, color: color)),
        Text(label,
            style: const TextStyle(fontSize: 11, color: Colors.blueGrey)),
      ],
    );
  }

  Widget _buildTextField(String label, IconData icon,
      {bool isNumber = false, TextEditingController? controller}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.blueAccent),
          border:
              OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }

  Widget _buildActionButton(
      IconData icon, String tooltip, Color color, VoidCallback onTap) {
    return IconButton(
        icon: Icon(icon, color: color, size: 28),
        tooltip: tooltip,
        onPressed: onTap);
  }
}
