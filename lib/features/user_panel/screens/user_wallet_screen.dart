// lib/features/user_panel/screens/user_wallet_screen.dart

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart' as intl;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/providers/system_provider.dart';
import '../../../core/providers/ui_provider.dart';
import '../../../core/widgets/custom_header.dart';
import '../widgets/custom_user_drawer.dart';

class UserWalletScreen extends StatefulWidget {
  const UserWalletScreen({super.key});

  @override
  State<UserWalletScreen> createState() => _UserWalletScreenState();
}

class _UserWalletScreenState extends State<UserWalletScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isBalanceVisible = false;

  // شحن
  Map<String, dynamic>? _selectedAgent;
  List<Map<String, dynamic>> _agentBankAccounts = [];
  final _amountController = TextEditingController();
  final _refController = TextEditingController();
  String? _receiptBase64;
  final _picker = ImagePicker();

  // تحويل
  final _searchController = TextEditingController();
  final _transferAmountController = TextEditingController();
  Map<String, dynamic>? _transferTarget;
  bool _isSearching = false;
  double? _transferFee = null; // للعمولة

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // استمع لأي طلبات مكتملة أو مرفوضة لإظهار إشعار
  }

  @override
  void dispose() {
    _tabController.dispose();
    _amountController.dispose();
    _refController.dispose();
    _searchController.dispose();
    _transferAmountController.dispose();
    super.dispose();
  }

  void _play(String type) =>
      Provider.of<UiProvider>(context, listen: false).playSound(type);

  void _showSnack(String msg, {bool error = false}) {
    if (!mounted) return;
    final colors = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, textDirection: TextDirection.rtl),
        backgroundColor: error ? colors.error : Colors.green.shade800,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _loadAgentBanks(String agentPhone) async {
    final sys = Provider.of<SystemProvider>(context, listen: false);
    final banks = await sys.getAgentBankAccountsForUser(agentPhone);
    setState(() {
      _agentBankAccounts = banks;
    });
  }

  Future<void> _pickReceipt() async {
    _play('click');
    try {
      final XFile? image = await _picker.pickImage(
          source: ImageSource.gallery, imageQuality: 40, maxWidth: 600);
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() => _receiptBase64 = base64Encode(bytes));
        _play('success');
      }
    } catch (e) {
      _showSnack('فشل تحميل الصورة', error: true);
    }
  }

  Future<void> _submitRecharge() async {
    final sys = Provider.of<SystemProvider>(context, listen: false);
    if (_selectedAgent == null) {
      _showSnack('اختر وكيلاً', error: true);
      return;
    }
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      _showSnack('أدخل مبلغاً صحيحاً', error: true);
      return;
    }
    if (_refController.text.isEmpty) {
      _showSnack('أدخل رقم الحوالة', error: true);
      return;
    }
    try {
      await sys.requestRechargeFromAgent(
        agentPhone: _selectedAgent!['phone'],
        amount: amount,
        paymentMethod: 'حوالة بنكية',
        reference: _refController.text,
        base64Image: _receiptBase64,
      );
      _play('success');
      _showSnack('تم إرسال طلب الشحن للوكيل');
      _clearRechargeForm();
    } catch (e) {
      _showSnack('فشل: $e', error: true);
    }
  }

  void _clearRechargeForm() {
    _amountController.clear();
    _refController.clear();
    setState(() {
      _receiptBase64 = null;
      _selectedAgent = null;
      _agentBankAccounts = [];
    });
  }

  void _editRechargeRequest(Map<String, dynamic> request) {
    final sys = Provider.of<SystemProvider>(context, listen: false);
    sys.getRealAgentsForRecharge().then((agents) {
      final agent = agents.firstWhere(
          (a) => a['phone'] == request['targetPhone'],
          orElse: () => {});
      if (agent.isNotEmpty) {
        setState(() {
          _selectedAgent = agent;
          _amountController.text = request['amount']?.toString() ?? '';
          _refController.text = request['reference'] ?? '';
          _receiptBase64 = request['receiptBase64'];
        });
        _loadAgentBanks(request['targetPhone']);
      }
    });
  }

  Future<void> _cancelRechargeRequest(String docId) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('إلغاء الطلب'),
          content: const Text('هل تريد إلغاء طلب الشحن نهائياً؟'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('تراجع')),
            ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('إلغاء الطلب',
                    style: TextStyle(color: Colors.white))),
          ],
        ),
      ),
    );
    if (confirm == true) {
      await FirebaseFirestore.instance
          .collection('user_recharges')
          .doc(docId)
          .delete();
      _play('success');
      _showSnack('تم إلغاء الطلب بنجاح');
    }
  }

  // حفظ/إزالة وكيل مفضل
  Future<void> _toggleFavoriteAgent(String agentPhone) async {
    final prefs = await SharedPreferences.getInstance();
    String key = 'fav_agent_${sys.currentUserPhone}';
    String? fav = prefs.getString(key);
    if (fav == agentPhone) {
      await prefs.remove(key);
    } else {
      await prefs.setString(key, agentPhone);
    }
    setState(() {}); // لإعادة بناء القائمة
  }

  Future<String?> _getFavoriteAgent() async {
    final prefs = await SharedPreferences.getInstance();
    String key = 'fav_agent_${sys.currentUserPhone}';
    return prefs.getString(key);
  }

  // البحث عن مستخدم للتحويل
  Future<void> _searchForTransfer() async {
    final sys = Provider.of<SystemProvider>(context, listen: false);
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    setState(() => _isSearching = true);
    try {
      final result = await sys.searchUserByAccountOrName(query);
      if (!mounted) return;
      setState(() {
        _transferTarget = result;
        _isSearching = false;
      });
      if (result == null) _showSnack('لم يتم العثور على مستخدم', error: true);
    } catch (e) {
      setState(() => _isSearching = false);
      _showSnack('خطأ: $e', error: true);
    }
  }

  // تنفيذ التحويل مع تأكيد
  Future<void> _executeTransfer() async {
    final sys = Provider.of<SystemProvider>(context, listen: false);
    if (_transferTarget == null) return;
    final amount = double.tryParse(_transferAmountController.text);
    if (amount == null || amount <= 0) {
      _showSnack('أدخل مبلغاً صحيحاً', error: true);
      return;
    }
    final targetPhone = _transferTarget!['phone'];
    if (targetPhone == 'مخفي') {
      _showSnack('لا يمكن التحويل لأن الرقم مخفي', error: true);
      return;
    }
    // تأكيد
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تأكيد التحويل'),
          content: Text('تحويل $amount ريال إلى ${_transferTarget!['name']}؟'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('تراجع')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('تأكيد')),
          ],
        ),
      ),
    );
    if (confirm != true) return;
    try {
      await sys.transferToUser(targetPhone: targetPhone, amount: amount);
      _play('success');
      _showSnack('تم التحويل بنجاح');
      _transferAmountController.clear();
      setState(() => _transferTarget = null);
      _searchController.clear();
    } catch (e) {
      _showSnack('فشل التحويل: $e', error: true);
    }
  }

  // مسح QR حقيقي
  void _startQRScan() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const QRScannerScreen(),
      ),
    );
    if (result != null && result is String) {
      try {
        final data = jsonDecode(result);
        if (data['acc'] != null) {
          _searchController.text = data['acc'];
          _searchForTransfer();
          _tabController.animateTo(1); // انتقل لتبويب التحويل
        } else {
          _showSnack('الكود لا يحتوي على رقم حساب صحيح', error: true);
        }
      } catch (e) {
        _showSnack('الكود غير صالح', error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sys = Provider.of<SystemProvider>(context);
    final colors = Theme.of(context).colorScheme;
    final userBalance = sys.currentUserBalance;
    final accountNumber = sys.currentUserAccountNumber ?? 'غير متوفر';
    final userName = sys.currentUserName;

    return Scaffold(
      backgroundColor: colors.surfaceContainerLowest,
      appBar: const CustomHeader(title: 'محفظتي'),
      drawer: CustomUserDrawer(
        userName: userName,
        phoneNumber: sys.currentUserPhone,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverAppBar(
              expandedHeight: 145.0,
              floating: false,
              pinned: true,
              backgroundColor: colors.primaryContainer,
              flexibleSpace: FlexibleSpaceBar(
                background: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [colors.primary, colors.primaryContainer],
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                      ),
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: const [
                        BoxShadow(
                            color: Colors.black26,
                            blurRadius: 8,
                            offset: Offset(0, 2))
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(userName,
                                  style: TextStyle(
                                      color: colors.onPrimaryContainer,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold)),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.qr_code_2,
                                      color: colors.onPrimaryContainer, size: 22),
                                  tooltip: 'رمز QR',
                                  onPressed: () => _tabController.animateTo(2),
                                ),
                                IconButton(
                                  icon: Icon(Icons.settings,
                                      color: colors.onPrimaryContainer, size: 20),
                                  onPressed: () {
                                    Navigator.pushNamed(
                                        context, '/user_settings');
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () {
                            setState(
                                () => _isBalanceVisible = !_isBalanceVisible);
                          },
                          child: Row(
                            children: [
                              Icon(Icons.account_balance_wallet,
                                  color: colors.onPrimaryContainer, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                _isBalanceVisible
                                    ? '${intl.NumberFormat('#,###.##').format(userBalance)} ريال'
                                    : '**** ريال',
                                style: TextStyle(
                                    color: colors.onPrimaryContainer,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                _isBalanceVisible
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: colors.onPrimaryContainer,
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(40),
                child: Container(
                  color: colors.surface,
                  child: TabBar(
                    controller: _tabController,
                    labelColor: colors.primary,
                    unselectedLabelColor: colors.onSurfaceVariant,
                    indicatorColor: colors.primary,
                    indicatorWeight: 3,
                    labelStyle: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13),
                    tabs: const [
                      Tab(icon: Icon(Icons.account_balance_wallet, size: 20), text: 'شحن'),
                      Tab(icon: Icon(Icons.send_to_mobile, size: 20), text: 'تحويل'),
                      Tab(icon: Icon(Icons.qr_code_2, size: 20), text: 'QR'),
                    ],
                  ),
                ),
              ),
            ),
          ],
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildRechargeTab(colors, sys),
              _buildTransferTab(colors),
              _buildQRTab(colors, accountNumber, userName),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== تبويب الشحن ====================
  Widget _buildRechargeTab(ColorScheme colors, SystemProvider sys) {
    return RefreshIndicator(
      onRefresh: () async => setState(() {}),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // إحصاءات سريعة
            FutureBuilder<QuerySnapshot>(
              future: FirebaseFirestore.instance
                  .collection('user_recharges')
                  .where('userPhone', isEqualTo: sys.currentUserPhone)
                  .where('status', isEqualTo: 'قيد الانتظار')
                  .count()
                  .get(),
              builder: (context, snap) {
                final pending = snap.data?.count ?? 0;
                return Text('📊 طلبات معلقة: $pending',
                    style: TextStyle(color: colors.onSurfaceVariant));
              },
            ),
            const SizedBox(height: 12),
            // القائمة المنسدلة للوكلاء مع مفضلة
            FutureBuilder<List<Map<String, dynamic>>>(
              future: sys.getRealAgentsForRecharge().then((agents) async {
                final fav = await _getFavoriteAgent();
                // ترتيب: المفضل أولاً
                if (fav != null && agents.any((a) => a['phone'] == fav)) {
                  final favAgent = agents.firstWhere((a) => a['phone'] == fav);
                  agents.remove(favAgent);
                  agents.insert(0, favAgent);
                }
                return agents;
              }),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final agents = snapshot.data ?? [];
                if (agents.isEmpty) {
                  return Text('لا يوجد وكلاء نشطين حالياً.',
                      style: TextStyle(color: colors.onSurfaceVariant));
                }
                return Column(
                  children: [
                    DropdownButtonFormField<Map<String, dynamic>>(
                      value: _selectedAgent,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'اختر الوكيل',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                        prefixIcon: const Icon(Icons.person),
                      ),
                      items: agents.map((agent) {
                        final isFav = _favoriteAgentPhone == agent['phone'];
                        return DropdownMenuItem<Map<String, dynamic>>(
                          value: agent,
                          child: Row(
                            children: [
                              if (isFav)
                                Icon(Icons.star, size: 16, color: Colors.amber),
                              const SizedBox(width: isFav ? 8 : 0),
                              Expanded(
                                child: Text(
                                  '${agent['name'] ?? agent['phone']}',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedAgent = val;
                          _agentBankAccounts = [];
                        });
                        if (val != null) _loadAgentBanks(val['phone']);
                      },
                    ),
                    // زر مفضلة
                    if (_selectedAgent != null)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => _toggleFavoriteAgent(_selectedAgent!['phone']),
                          icon: Icon(
                            _favoriteAgentPhone == _selectedAgent!['phone']
                                ? Icons.star
                                : Icons.star_border,
                            color: Colors.amber,
                          ),
                          label: Text(
                            _favoriteAgentPhone == _selectedAgent!['phone']
                                ? 'إزالة من المفضلة'
                                : 'إضافة للمفضلة',
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                  ],
                );
              },
            ),
            // حسابات الوكيل البنكية
            if (_selectedAgent != null) ...[
              if (_agentBankAccounts.isNotEmpty) ...[
                Text('حسابات ${_selectedAgent!['name'] ?? _selectedAgent!['phone']}:',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: colors.onSurface)),
                const SizedBox(height: 8),
                ..._agentBankAccounts.map((bank) => Card(
                      elevation: 1,
                      color: colors.surface,
                      child: ListTile(
                        leading:
                            Icon(Icons.account_balance, color: colors.primary),
                        title: Text(bank['bankName'] ?? ''),
                        subtitle: Text(
                            'رقم الحساب: ${bank['accountNumber']}\nالمستفيد: ${bank['beneficiary'] ?? ""}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.copy, color: colors.primary),
                              tooltip: 'نسخ',
                              onPressed: () {
                                final data =
                                    '🏦 ${bank['bankName']}\n🔢 الحساب: ${bank['accountNumber']}\n👤 باسم: ${bank['beneficiary'] ?? ""}';
                                Clipboard.setData(ClipboardData(text: data));
                                _showSnack('تم النسخ');
                              },
                            ),
                            IconButton(
                              icon: Icon(Icons.share, color: colors.primary),
                              tooltip: 'مشاركة',
                              onPressed: () {
                                final data =
                                    '🏦 ${bank['bankName']}\n🔢 الحساب: ${bank['accountNumber']}\n👤 باسم: ${bank['beneficiary'] ?? ""}';
                                Share.share(data);
                              },
                            ),
                          ],
                        ),
                      ),
                    )),
              ] else
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text('لا توجد حسابات بنكية نشطة لهذا الوكيل',
                      style: TextStyle(color: colors.onSurfaceVariant)),
                ),
            ],
            const SizedBox(height: 15),
            // حقول المبلغ والمرجع
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                  labelText: 'المبلغ (ريال)',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  prefixIcon: const Icon(Icons.attach_money)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _refController,
              decoration: InputDecoration(
                  labelText: 'رقم الحوالة / المرجع',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  prefixIcon: const Icon(Icons.receipt)),
            ),
            const SizedBox(height: 15),
            OutlinedButton.icon(
              onPressed: _pickReceipt,
              icon: Icon(
                  _receiptBase64 == null ? Icons.image : Icons.check_circle,
                  color:
                      _receiptBase64 == null ? colors.primary : Colors.green),
              label: Text(
                  _receiptBase64 == null ? 'إرفاق صورة السند' : 'تم الإرفاق'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 45),
                side: BorderSide(
                    color: _receiptBase64 == null
                        ? colors.primary
                        : Colors.green),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _submitRecharge,
                icon: Icon(Icons.send, color: colors.onPrimary),
                label: Text('إرسال طلب الشحن',
                    style: TextStyle(
                        color: colors.onPrimary,
                        fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10))),
              ),
            ),
            const SizedBox(height: 25),
            // سجل العمليات الكامل
            Text('📋 سجل الشحنات',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: colors.onSurface)),
            const SizedBox(height: 10),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('user_recharges')
                  .where('userPhone', isEqualTo: sys.currentUserPhone)
                  .orderBy('timestamp', descending: true)
                  .limit(10)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Text('خطأ في تحميل السجل',
                      style: TextStyle(color: colors.error));
                }
                final items = snapshot.data?.docs ?? [];
                if (items.isEmpty) {
                  return Text('لا توجد عمليات شحن بعد.',
                      style: TextStyle(color: colors.onSurfaceVariant));
                }
                return Column(
                  children: items.map((doc) {
                    final req = doc.data() as Map<String, dynamic>;
                    final amount = (req['amount'] ?? 0.0).toDouble();
                    final agent = req['targetPhone'] ?? '';
                    final status = req['status'] ?? 'قيد الانتظار';
                    final time = (req['timestamp'] as Timestamp?)?.toDate();
                    final dateStr = time != null
                        ? intl.DateFormat('yyyy/MM/dd - hh:mm a').format(time)
                        : '';
                    IconData icon;
                    Color iconColor;
                    String statusText;
                    switch (status) {
                      case 'مقبول':
                        icon = Icons.check_circle;
                        iconColor = Colors.green;
                        statusText = 'ناجح';
                        break;
                      case 'مرفوض':
                        icon = Icons.cancel;
                        iconColor = Colors.red;
                        statusText = 'مرفوض';
                        break;
                      default:
                        icon = Icons.hourglass_bottom;
                        iconColor = Colors.orange;
                        statusText = 'معلق';
                    }
                    return ListTile(
                      dense: true,
                      title: Text(
                          '$amount ريال من الوكيل $agent'),
                      subtitle: Text('$dateStr ($statusText)'),
                      leading: Icon(icon, color: iconColor, size: 20),
                      trailing: status == 'قيد الانتظار'
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.edit,
                                      color: colors.primary, size: 18),
                                  onPressed: () => _editRechargeRequest({
                                    'targetPhone': agent,
                                    'amount': amount,
                                    'reference':
                                        req['reference'] ?? '',
                                    'receiptBase64':
                                        req['receiptBase64'] ?? '',
                                  }),
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete,
                                      color: colors.error, size: 18),
                                  onPressed: () =>
                                      _cancelRechargeRequest(doc.id),
                                ),
                              ],
                            )
                          : null,
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ==================== تبويب التحويل ====================
  Widget _buildTransferTab(ColorScheme colors) {
    return RefreshIndicator(
      onRefresh: () async => setState(() {}),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('💸 تحويل لشخص آخر',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: colors.onSurface)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: 'رقم الحساب أو الاسم الرباعي',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      prefixIcon: const Icon(Icons.search),
                    ),
                    onSubmitted: (v) => _searchForTransfer(),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                    onPressed: _isSearching ? null : _searchForTransfer,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: colors.primary),
                    child: Text('بحث',
                        style: TextStyle(color: colors.onPrimary))),
              ],
            ),
            if (_isSearching)
              const Padding(
                padding: EdgeInsets.all(10),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (_transferTarget != null) ...[
              const SizedBox(height: 15),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.primaryContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: colors.primary),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('الاسم: ${_transferTarget!['name']}',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(
                        'رقم الحساب: ${_transferTarget!['accountNumber']}'),
                    Text(
                        'الرصيد الظاهر: ${_transferTarget!['balance']} ريال'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _transferAmountController,
                keyboardType: TextInputType.number,
                onChanged: (v) {
                  setState(() {});
                },
                decoration: InputDecoration(
                  labelText: 'المبلغ (ريال)',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  prefixIcon: const Icon(Icons.money),
                ),
              ),
              if (_transferAmountController.text.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'سيصل: ${(double.tryParse(_transferAmountController.text) ?? 0).toStringAsFixed(0)} ريال (بدون خصم)',
                    style: TextStyle(color: colors.primary, fontSize: 12),
                  ),
                ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _executeTransfer,
                  icon: Icon(Icons.send, color: colors.onPrimary),
                  label: Text('تنفيذ التحويل',
                      style: TextStyle(
                          color: colors.onPrimary,
                          fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: colors.primary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10))),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ==================== تبويب QR ====================
  Widget _buildQRTab(
      ColorScheme colors, String accountNumber, String userName) {
    final qrData = '{"acc":"$accountNumber","name":"$userName"}';
    return RefreshIndicator(
      onRefresh: () async => setState(() {}),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('استقبال رصيد',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colors.onSurface)),
            const SizedBox(height: 5),
            Text('امسح هذا الكود لتحويل الرصيد إليك',
                style: TextStyle(color: colors.onSurfaceVariant)),
            const SizedBox(height: 25),
            RepaintBoundary(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black12,
                        blurRadius: 8,
                        offset: Offset(0, 4))
                  ],
                ),
                child: QrImageView(
                  data: qrData,
                  version: QrVersions.auto,
                  size: 200,
                  backgroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: accountNumber));
                    _showSnack('تم نسخ رقم الحساب');
                  },
                  icon: Icon(Icons.copy, color: colors.onPrimary),
                  label: const Text('نسخ الحساب'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: colors.primary),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: _startQRScan,
                  icon: Icon(Icons.camera_alt, color: colors.primary),
                  label: const Text('مسح QR'),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: colors.primary,
                      side: BorderSide(color: colors.primary)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // متغير للوكيل المفضل الحالي
  String? _favoriteAgentPhone;
}

// ==============================
// شاشة مسح QR مستقلة
// ==============================
class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final MobileScannerController controller = MobileScannerController();
  bool _hasScanned = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('مسح QR'),
        actions: [
          IconButton(
            icon: Icon(Icons.flashlight_on),
            onPressed: () => controller.toggleTorch(),
          ),
          IconButton(
            icon: Icon(Icons.flip_camera_ios),
            onPressed: () => controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: controller,
            onDetect: (capture) {
              if (!_hasScanned) {
                _hasScanned = true;
                final List<Barcode> barcodes = capture.barcodes;
                for (final barcode in barcodes) {
                  if (barcode.rawValue != null) {
                    Navigator.pop(context, barcode.rawValue);
                    return;
                  }
                }
                _hasScanned = false;
              }
            },
          ),
          Align(
            alignment: Alignment.topCenter,
            child: Container(
              margin: const EdgeInsets.only(top: 20),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(10)),
              child: const Text('وجّه الكاميرا نحو رمز QR',
                  style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}
