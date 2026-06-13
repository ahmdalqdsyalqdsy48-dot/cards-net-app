import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/providers/wallet_provider.dart';
import '../../../core/providers/agent_admin_provider.dart';
import '../../../core/providers/ui_provider.dart';
import '../../../core/widgets/custom_drawer.dart';
import '../../../core/widgets/custom_header.dart';
import 'agent_profile_screen.dart';

class AgentManagementScreen extends StatefulWidget {
  const AgentManagementScreen({super.key});

  @override
  State<AgentManagementScreen> createState() => _AgentManagementScreenState();
}

class _AgentManagementScreenState extends State<AgentManagementScreen> {
  String _searchQuery = '';
  // 🆕 متغير لتتبع أي وكيل مفتوح حالياً
  String? _expandedAgentPhone;

  void _play(String type) => context.read<UiProvider>().playSound(type);

  bool _can(String permission) {
    final auth = context.read<AuthProvider>();
    return auth.currentUserRole == 'super_admin' || auth.hasPermission(permission);
  }

  void _showSnackBar(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, textDirection: TextDirection.rtl),
        backgroundColor: error ? Colors.red.shade800 : Colors.green.shade800,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ==========================================
  // 1. نافذة إضافة وكيل جديد
  // ==========================================
  void _showAddAgentDialog(AgentAdminProvider agentAdmin) {
    if (!_can('إضافة وكيل')) return;
    _play('click');
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final profitController = TextEditingController();
    final passwordController = TextEditingController();
    final balanceController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) {
          bool isLoading = false;

          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              backgroundColor: Theme.of(context).colorScheme.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Icon(Icons.person_add, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text('إضافة وكيل جديد',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Theme.of(context).colorScheme.onSurface)),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildTextField('الاسم الرباعي للوكيل', Icons.person, controller: nameController),
                    _buildTextField('رقم الهاتف (اسم المستخدم)', Icons.phone, controller: phoneController, isNumber: true),
                    _buildTextField('نسبة رسوم النظام %', Icons.percent, controller: profitController, isNumber: true,
                        hint: 'النسبة التي يخصمها النظام من مبيعات الوكيل'),
                    _buildTextField('كلمة المرور', Icons.lock, controller: passwordController),
                    const Divider(height: 20),
                    _buildTextField('الرصيد الابتدائي (اختياري)', Icons.account_balance_wallet, controller: balanceController, isNumber: true),
                    const SizedBox(height: 5),
                    const Text('اتركه فارغاً إذا كنت لا تريد إضافة رصيد الآن.',
                        style: TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ),
              actions: [
                if (!isLoading)
                  TextButton(
                    onPressed: () { _play('click'); Navigator.pop(ctx); },
                    child: const Text('إلغاء', style: TextStyle(color: Colors.red)),
                  ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: isLoading ? null : () async {
                    String phone = phoneController.text.trim();
                    String name = nameController.text.trim();

                    if (name.isNotEmpty && phone.isNotEmpty) {
                      setStateDialog(() => isLoading = true);

                      try {
                        await agentAdmin.addAgent(
                          name: name,
                          phone: phone,
                          password: passwordController.text.trim().isNotEmpty
                              ? passwordController.text.trim()
                              : phone,
                          profitMargin: profitController.text.trim(),
                          initialBalance: double.tryParse(balanceController.text.trim()) ?? 0,
                        );

                        if (mounted) {
                          _play('success');
                          Navigator.pop(ctx);
                          _showSnackBar('تم إضافة الوكيل بنجاح! ✅');
                        }
                      } catch (error) {
                        _play('error');
                        setStateDialog(() => isLoading = false);
                        if (mounted) _showSnackBar('فشل الحفظ ❌: $error', error: true);
                      }
                    } else {
                      _play('error');
                      _showSnackBar('يرجى إدخال الاسم ورقم الهاتف على الأقل! ❌', error: true);
                    }
                  },
                  child: isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('حفظ واعتماد', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ==========================================
  // 2. نافذة تعديل بيانات وكيل حالي
  // ==========================================
  void _showEditAgentDialog(Map<String, dynamic> agent, AgentAdminProvider agentAdmin) {
    if (!_can('تعديل وكيل')) return;
    _play('click');
    final nameController = TextEditingController(text: agent['name']);
    final phoneController = TextEditingController(text: agent['phone']);
    final profitController = TextEditingController(
      text: agent['profitMargin']?.toString().replaceAll('%', '') ?? '0',
    );
    final passwordController = TextEditingController(text: agent['password']);

    final oldPhone = agent['phone'];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) {
          bool isLoading = false;

          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              backgroundColor: Theme.of(context).colorScheme.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Icon(Icons.edit, color: Theme.of(context).colorScheme.secondary),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text('تعديل بيانات الوكيل',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Theme.of(context).colorScheme.onSurface)),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildTextField('الاسم الرباعي', Icons.person, controller: nameController),
                    _buildTextField('رقم الهاتف (الآيدي للحساب)', Icons.phone, controller: phoneController, isNumber: true),
                    _buildTextField('نسبة رسوم النظام %', Icons.percent, controller: profitController, isNumber: true,
                        hint: 'النسبة التي يخصمها النظام من مبيعات الوكيل'),
                    _buildTextField('كلمة المرور', Icons.lock, controller: passwordController),
                  ],
                ),
              ),
              actions: [
                if (!isLoading)
                  TextButton(onPressed: () { _play('click'); Navigator.pop(ctx); }, child: const Text('إلغاء')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.secondary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: isLoading ? null : () async {
                    setStateDialog(() => isLoading = true);

                    try {
                      await agentAdmin.updateAgentDetails(
                        oldPhone: oldPhone,
                        newPhone: phoneController.text.trim(),
                        newName: nameController.text.trim(),
                        newNetwork: '',
                        newLocation: '',
                        newProfit: '${profitController.text.trim()}%',
                        newPassword: passwordController.text.trim(),
                      );

                      if (mounted) {
                        _play('success');
                        Navigator.pop(ctx);
                        _showSnackBar('تم تطبيق التعديلات بنجاح ✅');
                      }
                    } catch (error) {
                      _play('error');
                      setStateDialog(() => isLoading = false);
                      if (mounted) _showSnackBar('فشل التعديل ❌: $error', error: true);
                    }
                  },
                  child: isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('حفظ التعديلات', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ==========================================
  // 3. تجميد / تنشيط الوكيل
  // ==========================================
  void _toggleFreeze(Map<String, dynamic> agent, AgentAdminProvider agentAdmin) {
    if (!_can('تجميد/تنشيط وكيل')) return;
    _play('click');
    bool isGoingToFreeze = agent['status'] == 'نشط';

    try {
      agentAdmin.toggleUserStatus(agent['phone'], agent['status']);
      _play('success');
      _showSnackBar(isGoingToFreeze ? 'تم تجميد حساب الوكيل ⏸️' : 'تم إعادة تنشيط الوكيل ▶️');
    } catch (e) {
      _play('error');
      _showSnackBar('فشل تغيير الحالة ❌: $e', error: true);
    }
  }

  // ==========================================
  // 4. حذف الوكيل
  // ==========================================
  void _deleteAgent(Map<String, dynamic> agent, AgentAdminProvider agentAdmin) {
    if (!_can('حذف وكيل')) return;
    _play('click');
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: const Text('تأكيد الحذف النهائي', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          content: Text('هل أنت متأكد من مسح بيانات الوكيل (${agent['name']}) نهائياً؟'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('تراجع')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                try {
                  agentAdmin.deleteAgent(agent['phone']);
                  _play('success');
                  Navigator.pop(ctx);
                  _showSnackBar('تم الحذف النهائي من السيرفر 🗑️');
                } catch (e) {
                  _play('error');
                  Navigator.pop(ctx);
                  _showSnackBar('فشل الحذف ❌: $e', error: true);
                }
              },
              child: const Text('نعم، احذف', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showAgentDetails(Map<String, dynamic> agent) {
    _play('click');
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AgentProfileScreen(agentData: agent)),
    );
  }

  // 🆕 عرض الشبكة على الخريطة
  void _showNetworkMap(double lat, double lng, String title) {
    _play('click');
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text('موقع: $title'),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: FlutterMap(
              options: MapOptions(initialCenter: LatLng(lat, lng), initialZoom: 15.0),
              children: [
                TileLayer(urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png'),
                MarkerLayer(markers: [
                  Marker(point: LatLng(lat, lng), width: 40, height: 40,
                      child: const Icon(Icons.location_pin, color: Colors.red, size: 40)),
                ]),
              ],
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق'))],
        ),
      ),
    );
  }

  // 🆕 تحميل شبكات الوكيل من Firestore
  Future<Map<String, dynamic>> _loadAgentNetworks(String phone) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('networks')
          .where('agentPhone', isEqualTo: phone)
          .get();

      final networks = snap.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'] ?? '',
          'location': data['location'] ?? '',
          'ip': data['ip'] ?? '',
          'isActive': data['isActive'] ?? true,
          'latitude': data['latitude'],
          'longitude': data['longitude'],
          'categories': data['categories'] ?? [],
        };
      }).toList();

      // جلب رقم الحساب من وثيقة المستخدم
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(phone).get();
      final accountNumber = userDoc.data()?['accountNumber'] as String?;

      return {
        'networks': networks,
        'accountNumber': accountNumber,
      };
    } catch (e) {
      return {'networks': [], 'accountNumber': null};
    }
  }

  // ==========================================
  // بناء واجهة المستخدم (متجاوبة + توسيع)
  // ==========================================
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final settings = context.watch<SettingsProvider>();
    final wallet = context.watch<WalletProvider>();
    final agentAdmin = context.read<AgentAdminProvider>();
    final colorScheme = Theme.of(context).colorScheme;

    // 🆕 استجابة لحجم الشاشة
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;

    final realAgentsList = wallet.agentsList;

    final filteredAgents = realAgentsList.where((agent) =>
        (agent['name']?.toString() ?? '').contains(_searchQuery) ||
        (agent['phone']?.toString() ?? '').contains(_searchQuery)
    ).toList();

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: const CustomHeader(title: 'إدارة الوكلاء'),
      drawer: CustomDrawer(
        userName: wallet.currentUserName,
        phoneNumber: auth.activeUserPhone ?? '',
        role: auth.currentUserRole == 'super_admin' ? 'مالك النظام' : 'موظف مخصص',
        balanceOrPoints: 'أرباح النظام: ${settings.adminMainBalance.toStringAsFixed(0)} ريال',
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {});
          await Future.delayed(const Duration(milliseconds: 300));
          _play('success');
          _showSnackBar('تم تحديث الصفحة بنجاح ✅');
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // الرأس المتحرك (يختفي مع التمرير)
            SliverToBoxAdapter(
              child: Column(
                children: [
                  if (_can('إضافة وكيل'))
                    Padding(
                      padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
                      child: SizedBox(
                        width: double.infinity,
                        height: isSmallScreen ? 44 : 50,
                        child: ElevatedButton.icon(
                          onPressed: () => _showAddAgentDialog(agentAdmin),
                          icon: const Icon(Icons.person_add, color: Colors.white),
                          label: Text('إضافة وكيل جديد',
                              style: TextStyle(
                                  fontSize: isSmallScreen ? 14 : 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorScheme.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 12.0 : 16.0),
                    child: TextField(
                      onChanged: (value) {
                        if (value.length == 1) _play('click');
                        setState(() => _searchQuery = value);
                      },
                      decoration: InputDecoration(
                        hintText: 'ابحث بالاسم أو الهاتف...',
                        prefixIcon: Icon(Icons.search, color: colorScheme.onSurfaceVariant, size: isSmallScreen ? 20 : 24),
                        filled: true,
                        fillColor: colorScheme.surfaceContainerHighest,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: EdgeInsets.symmetric(vertical: isSmallScreen ? 8 : 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 12.0 : 16.0),
                    child: Text('${filteredAgents.length} وكيل',
                        style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: isSmallScreen ? 12 : 14)),
                  ),
                  const Divider(),
                ],
              ),
            ),
            // قائمة الوكلاء
            filteredAgents.isEmpty
                ? const SliverFillRemaining(
                    child: Center(
                        child: Text('لا يوجد وكلاء مطابقين للبحث أو لم يتم إضافة وكلاء بعد.',
                            style: TextStyle(color: Colors.grey))))
                : SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final agent = filteredAgents[index];
                        final isFrozen = agent['status'] == 'مجمد';
                        final phone = agent['phone'] ?? '';
                        final isExpanded = _expandedAgentPhone == phone;

                        return FutureBuilder<Map<String, dynamic>>(
                          future: _loadAgentNetworks(phone),
                          initialData: {'networks': [], 'accountNumber': agent['accountNumber']},
                          builder: (context, snapshot) {
                            final data = snapshot.data ?? {'networks': [], 'accountNumber': agent['accountNumber']};
                            final networks = data['networks'] as List<Map<String, dynamic>>;
                            final accountNumber = data['accountNumber'] as String?;

                            return Card(
                              margin: EdgeInsets.symmetric(
                                  horizontal: isSmallScreen ? 8 : 16,
                                  vertical: isSmallScreen ? 4 : 6),
                              elevation: 3,
                              color: colorScheme.surface,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                                side: BorderSide(
                                  color: isFrozen ? colorScheme.error.withOpacity(0.3) : Colors.transparent,
                                  width: 1.5,
                                ),
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(15),
                                onTap: () {
                                  _play('click');
                                  setState(() {
                                    // 🆕 توسيع/طي البطاقة
                                    _expandedAgentPhone = isExpanded ? null : phone;
                                  });
                                },
                                child: Padding(
                                  padding: EdgeInsets.all(isSmallScreen ? 10.0 : 12.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // الصف الأول: الاسم والحالة
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              agent['name'] ?? 'مجهول',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: isSmallScreen ? 16 : 18,
                                                color: colorScheme.onSurface,
                                                decoration: isFrozen ? TextDecoration.lineThrough : null,
                                              ),
                                            ),
                                          ),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                padding: EdgeInsets.symmetric(
                                                    horizontal: isSmallScreen ? 8 : 12,
                                                    vertical: isSmallScreen ? 4 : 6),
                                                decoration: BoxDecoration(
                                                  color: isFrozen ? Colors.red : Colors.green,
                                                  borderRadius: BorderRadius.circular(20),
                                                ),
                                                child: Text(
                                                  agent['status'] ?? 'نشط',
                                                  style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: isSmallScreen ? 10 : 12,
                                                      fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              // 🆕 أيقونة التوسيع
                                              Icon(
                                                isExpanded ? Icons.expand_less : Icons.expand_more,
                                                color: colorScheme.onSurfaceVariant,
                                                size: isSmallScreen ? 20 : 24,
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const Divider(),
                                      // المعلومات المختصرة (تظهر دائماً)
                                      if (accountNumber != null && accountNumber.isNotEmpty)
                                        _buildInfoRow(Icons.credit_card, 'رقم الحساب', accountNumber, Colors.teal, isSmallScreen),
                                      _buildInfoRow(Icons.phone_android, 'رقم الهاتف', phone, Colors.indigo, isSmallScreen),
                                      _buildInfoRow(Icons.percent, 'رسوم النظام', agent['profitMargin'] ?? '0%', Colors.orange, isSmallScreen),
                                      _buildInfoRow(Icons.account_balance_wallet, 'الرصيد', '${(agent['balance'] ?? 0).toString()} ريال', Colors.green, isSmallScreen),
                                      // ملخص الشبكات (يظهر دائماً)
                                      _buildInfoRow(
                                        networks.isNotEmpty ? Icons.wifi : Icons.wifi_off,
                                        'الشبكات',
                                        networks.isNotEmpty ? '${networks.length} شبكات' : 'لم يضف شبكات بعد',
                                        networks.isNotEmpty ? Colors.blue : Colors.grey,
                                        isSmallScreen,
                                      ),

                                      // 🆕 المحتوى الموسع (يظهر فقط عند التوسيع)
                                      if (isExpanded) ...[
                                        const Divider(),
                                        // عرض الشبكات بالتصميم الموحد
                                        if (networks.isNotEmpty) ...[
                                          Text('الشبكات:',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: isSmallScreen ? 14 : 16,
                                                  color: colorScheme.onSurface)),
                                          const SizedBox(height: 8),
                                          ...networks.map((net) => _buildNetworkCard(net, isSmallScreen)),
                                        ],
                                        const Divider(),
                                        // أزرار التحكم بالوكيل
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                                          children: [
                                            if (_can('عرض الوكلاء'))
                                              _buildActionButton(Icons.visibility, 'تفاصيل', Colors.blue, () => _showAgentDetails(agent), isSmallScreen),
                                            if (_can('تعديل وكيل'))
                                              _buildActionButton(Icons.edit, 'تعديل', Colors.orange, () => _showEditAgentDialog(agent, agentAdmin), isSmallScreen),
                                            if (_can('تجميد/تنشيط وكيل'))
                                              _buildActionButton(
                                                isFrozen ? Icons.play_arrow : Icons.pause,
                                                isFrozen ? 'تنشيط' : 'تجميد',
                                                isFrozen ? Colors.green : Colors.red,
                                                () => _toggleFreeze(agent, agentAdmin),
                                                isSmallScreen,
                                              ),
                                            if (_can('حذف وكيل'))
                                              _buildActionButton(Icons.delete_forever, 'حذف', Colors.red, () => _deleteAgent(agent, agentAdmin), isSmallScreen),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                      childCount: filteredAgents.length,
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  // 🆕 بطاقة شبكة واحدة بالتصميم الموحد (متجاوبة)
  Widget _buildNetworkCard(Map<String, dynamic> net, bool isSmallScreen) {
    final bool isActive = net['isActive'] == true;
    final String name = net['name'] ?? 'بدون اسم';
    final String location = net['location'] ?? '';
    final String ip = net['ip'] ?? '';
    final int catCount = (net['categories'] as List?)?.length ?? 0;
    final double? lat = net['latitude']?.toDouble();
    final double? lng = net['longitude']?.toDouble();
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      color: isActive ? colorScheme.surface : Colors.grey.shade200,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isActive ? colorScheme.outlineVariant : Colors.grey.shade300),
      ),
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 8 : 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // رأس البطاقة: دائرة + اسم + شريحة حالة
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: isActive ? Colors.green.withOpacity(0.15) : Colors.grey.withOpacity(0.15),
                  radius: isSmallScreen ? 14 : 18,
                  child: Icon(Icons.router,
                      color: isActive ? Colors.green : Colors.grey,
                      size: isSmallScreen ? 16 : 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: isSmallScreen ? 13 : 15,
                      color: colorScheme.onSurface,
                      decoration: isActive ? null : TextDecoration.lineThrough,
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 6 : 8, vertical: isSmallScreen ? 2 : 3),
                  decoration: BoxDecoration(
                    color: isActive ? Colors.green.withOpacity(0.15) : Colors.red.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isActive ? 'نشط' : 'مجمد',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 10 : 11,
                      fontWeight: FontWeight.bold,
                      color: isActive ? Colors.green.shade700 : Colors.red.shade700,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: isSmallScreen ? 8 : 10),
            // صفوف المعلومات
            if (location.isNotEmpty)
              _buildInfoRow(Icons.location_on, 'الموقع', location, Colors.orange, isSmallScreen),
            if (ip.isNotEmpty)
              _buildInfoRow(Icons.wifi, 'IP', ip, Colors.blueGrey, isSmallScreen),
            _buildInfoRow(Icons.category, 'عدد الفئات', '$catCount فئة', Colors.purple, isSmallScreen),
            // زر الخريطة
            if (lat != null && lng != null)
              TextButton.icon(
                onPressed: () => _showNetworkMap(lat, lng, name),
                icon: Icon(Icons.map, size: isSmallScreen ? 14 : 16, color: colorScheme.primary),
                label: Text('عرض على الخريطة',
                    style: TextStyle(color: colorScheme.primary, fontSize: isSmallScreen ? 10 : 12)),
                style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 30)),
              ),
            // أزرار التحكم بالشبكة
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _networkActionBtn(Icons.bolt, 'اختبار', Colors.blue, () {
                  _play('click');
                  _showSnackBar('اختبار الاتصال بـ $name...');
                }, isSmallScreen),
                const SizedBox(width: 4),
                _networkActionBtn(
                  isActive ? Icons.pause_circle_filled : Icons.play_circle_fill,
                  isActive ? 'تجميد' : 'تنشيط',
                  Colors.orange,
                  () {
                    _play('click');
                    _showSnackBar(isActive ? 'تم تجميد $name' : 'تم تنشيط $name');
                  },
                  isSmallScreen,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _networkActionBtn(IconData icon, String label, Color color, VoidCallback onTap, bool isSmallScreen) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: isSmallScreen ? 14 : 16, color: color),
      label: Text(label,
          style: TextStyle(fontSize: isSmallScreen ? 10 : 11, color: color, fontWeight: FontWeight.bold)),
      style: TextButton.styleFrom(
        padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 4 : 6, vertical: 2),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, Color color, bool isSmallScreen) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 2 : 3),
      child: Row(
        children: [
          Icon(icon, size: isSmallScreen ? 14 : 16, color: color),
          const SizedBox(width: 6),
          Text('$label: ',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: isSmallScreen ? 11 : 12,
                  color: Colors.grey)),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: isSmallScreen ? 11 : 12, color: Theme.of(context).colorScheme.onSurface),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, IconData icon,
      {TextEditingController? controller, bool isNumber = false, String? hint}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: Theme.of(context).colorScheme.primary),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String tooltip, Color color, VoidCallback onTap, bool isSmallScreen) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: EdgeInsets.all(isSmallScreen ? 6.0 : 8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: isSmallScreen ? 20 : 24),
              SizedBox(height: isSmallScreen ? 2 : 4),
              Text(tooltip, style: TextStyle(fontSize: isSmallScreen ? 10 : 11, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}
