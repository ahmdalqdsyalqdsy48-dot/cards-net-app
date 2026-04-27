import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart' as intl;
import 'package:cloud_firestore/cloud_firestore.dart';

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
  String? _selectedAgentPhone;
  List<Map<String, dynamic>> _agentBankAccounts = [];
  Map<String, dynamic>? _selectedBankAccount;
  final _amountController = TextEditingController();
  final _refController = TextEditingController();
  String? _receiptBase64;
  final _picker = ImagePicker();

  // تحويل
  final _searchController = TextEditingController();
  final _transferAmountController = TextEditingController();
  Map<String, dynamic>? _transferTarget;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, textDirection: TextDirection.rtl),
        backgroundColor: error ? Colors.red.shade800 : Colors.green.shade800,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _loadAgentBanks(String agentPhone) async {
    final sys = Provider.of<SystemProvider>(context, listen: false);
    final banks = await sys.getAgentBankAccountsForUser(agentPhone);
    setState(() {
      _agentBankAccounts = banks;
      _selectedBankAccount = banks.isNotEmpty ? banks.first : null;
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
    if (_selectedAgentPhone == null) {
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
        agentPhone: _selectedAgentPhone!,
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
      _selectedAgentPhone = null;
      _agentBankAccounts = [];
      _selectedBankAccount = null;
    });
  }

  // تعديل طلب شحن: يملأ النموذج بالبيانات القديمة
  void _editRechargeRequest(Map<String, dynamic> request) {
    setState(() {
      _selectedAgentPhone = request['targetPhone'];
      _amountController.text = request['amount']?.toString() ?? '';
      _refController.text = request['reference'] ?? '';
      _receiptBase64 = request['receiptBase64'];
    });
    _loadAgentBanks(request['targetPhone']);
  }

  // إلغاء طلب شحن
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

  // تنفيذ التحويل
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

  @override
  Widget build(BuildContext context) {
    final sys = Provider.of<SystemProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userBalance = sys.currentUserBalance;
    final accountNumber = sys.currentUserAccountNumber ?? 'غير متوفر';
    final userName = sys.currentUserName;

    final myWallets = sys.usersList
            .firstWhere((u) => u['phone'] == sys.currentUserPhone,
                orElse: () => {'wallets': {}})['wallets']
        as Map<String, dynamic>? ??
        {};
    final agentPhones = myWallets.keys.toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: const CustomHeader(title: 'محفظتي'),
      drawer: CustomUserDrawer(
        userName: sys.currentUserName,
        phoneNumber: sys.currentUserPhone,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.all(20),
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [Colors.teal.shade900, Colors.teal.shade700]
                        : [Colors.teal.shade600, Colors.teal.shade400],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                        color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(userName,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold)),
                        IconButton(
                          icon: Icon(Icons.settings, color: Colors.white70),
                          onPressed: () {
                            Navigator.pushNamed(context, '/user_settings');
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow(Icons.credit_card, 'رقم الحساب', accountNumber,
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: accountNumber));
                          _showSnack('تم نسخ رقم الحساب');
                        }),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () {
                        setState(() => _isBalanceVisible = !_isBalanceVisible);
                      },
                      child: _buildInfoRow(
                        Icons.account_balance_wallet,
                        'الرصيد',
                        _isBalanceVisible
                            ? '${intl.NumberFormat('#,###.##').format(userBalance)} ريال'
                            : '**** ريال',
                        trailing: Icon(
                          _isBalanceVisible ? Icons.visibility_off : Icons.visibility,
                          color: Colors.white70,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverAppBarDelegate(
                TabBar(
                  controller: _tabController,
                  labelColor: Colors.orangeAccent,
                  unselectedLabelColor: isDark ? Colors.white70 : Colors.black54,
                  indicatorColor: Colors.orangeAccent,
                  indicatorWeight: 4,
                  labelStyle: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13),
                  tabs: const [
                    Tab(icon: Icon(Icons.account_balance_wallet), text: 'شحن'),
                    Tab(icon: Icon(Icons.send_to_mobile), text: 'تحويل'),
                    Tab(icon: Icon(Icons.qr_code_2), text: 'QR'),
                  ],
                ),
                color: Theme.of(context).scaffoldBackgroundColor,
              ),
            ),
          ],
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildRechargeTab(agentPhones, isDark),
              _buildTransferTab(isDark),
              _buildQRTab(accountNumber, userName),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value,
      {VoidCallback? onTap, Widget? trailing}) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Text('$label: ',
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
          Expanded(
              child: Text(value,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15))),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _buildRechargeTab(List<String> agentPhones, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('📥 طلب شحن رصيد',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _selectedAgentPhone,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'اختر الوكيل',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              prefixIcon: const Icon(Icons.person),
            ),
            items: agentPhones
                .map((phone) => DropdownMenuItem(
                      value: phone,
                      child: Text('وكيل: $phone'),
                    ))
                .toList(),
            onChanged: (val) {
              setState(() => _selectedAgentPhone = val);
              if (val != null) _loadAgentBanks(val);
            },
          ),
          const SizedBox(height: 15),
          if (_selectedAgentPhone != null && _agentBankAccounts.isNotEmpty) ...[
            DropdownButtonFormField<int>(
              value: _selectedBankAccount != null
                  ? _agentBankAccounts.indexOf(_selectedBankAccount!)
                  : 0,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'اختر حساب الوكيل للتحويل',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                prefixIcon: const Icon(Icons.account_balance),
              ),
              items: _agentBankAccounts.asMap().entries.map((e) {
                final bank = e.value;
                return DropdownMenuItem<int>(
                  value: e.key,
                  child: Text(
                    '${bank['bankName']} - ${bank['accountNumber']}',
                    style: const TextStyle(fontSize: 13),
                  ),
                );
              }).toList(),
              onChanged: (idx) {
                setState(() => _selectedBankAccount = _agentBankAccounts[idx!]);
              },
            ),
            if (_selectedBankAccount != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.teal.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.teal.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _copyableRow('اسم البنك: ${_selectedBankAccount!['bankName']}'),
                    _copyableRow('رقم الحساب: ${_selectedBankAccount!['accountNumber']}'),
                    _copyableRow('المستفيد: ${_selectedBankAccount!['note'] ?? ''}'),
                  ],
                ),
              ),
            ],
          ] else if (_selectedAgentPhone != null)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text('لا توجد حسابات بنكية نشطة لهذا الوكيل',
                  style: TextStyle(color: Colors.grey)),
            ),
          const SizedBox(height: 15),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
                labelText: 'المبلغ (ريال)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                prefixIcon: const Icon(Icons.attach_money)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _refController,
            decoration: InputDecoration(
                labelText: 'رقم الحوالة / المرجع',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                prefixIcon: const Icon(Icons.receipt)),
          ),
          const SizedBox(height: 15),
          OutlinedButton.icon(
            onPressed: _pickReceipt,
            icon: Icon(
                _receiptBase64 == null ? Icons.image : Icons.check_circle,
                color: _receiptBase64 == null ? Colors.teal : Colors.green),
            label: Text(_receiptBase64 == null ? 'إرفاق صورة السند' : 'تم الإرفاق'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 45),
              side: BorderSide(
                  color: _receiptBase64 == null ? Colors.teal : Colors.green),
            ),
          ),
          const SizedBox(height: 25),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _submitRecharge,
              icon: const Icon(Icons.send, color: Colors.white),
              label: const Text('إرسال طلب الشحن',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal.shade700,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
            ),
          ),
          const SizedBox(height: 25),
          // 🆕 سجل طلباتي المعلقة
          const Text('📋 طلباتي المعلقة',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('user_recharges')
                .where('userPhone', isEqualTo: Provider.of<SystemProvider>(context, listen: false).currentUserPhone)
                .where('status', isEqualTo: 'قيد الانتظار')
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final requests = snapshot.data?.docs ?? [];
              if (requests.isEmpty) {
                return const Text('لا توجد طلبات معلقة حالياً.',
                    style: TextStyle(color: Colors.grey));
              }
              return Column(
                children: requests.map((doc) {
                  final req = doc.data() as Map<String, dynamic>;
                  final DateTime? ts = (req['timestamp'] as Timestamp?)?.toDate();
                  final String timeStr = ts != null
                      ? intl.DateFormat('yyyy/MM/dd - hh:mm a').format(ts)
                      : '';
                  final double amount = (req['amount'] ?? 0.0).toDouble();
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text('مبلغ: ${amount.toStringAsFixed(0)} ريال'),
                      subtitle: Text('الوكيل: ${req['targetPhone']} - $timeStr'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () => _editRechargeRequest({
                              'targetPhone': req['targetPhone'],
                              'amount': amount,
                              'reference': req['reference'] ?? '',
                              'receiptBase64': req['receiptBase64'] ?? '',
                            }),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _cancelRechargeRequest(doc.id),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _copyableRow(String text) {
    return Row(
      children: [
        Expanded(child: Text(text, style: const TextStyle(fontSize: 12))),
        InkWell(
          onTap: () {
            Clipboard.setData(ClipboardData(text: text));
            _showSnack('تم النسخ');
          },
          child: const Icon(Icons.copy, size: 16, color: Colors.teal),
        ),
      ],
    );
  }

  Widget _buildTransferTab(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('💸 تحويل لشخص آخر',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: 'رقم الحساب أو الاسم الرباعي',
                    border:
                        OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    prefixIcon: const Icon(Icons.search),
                  ),
                  onSubmitted: (v) => _searchForTransfer(),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                  onPressed: _isSearching ? null : _searchForTransfer,
                  child: const Text('بحث'))
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
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('الاسم: ${_transferTarget!['name']}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('رقم الحساب: ${_transferTarget!['accountNumber']}'),
                  Text('الرصيد الظاهر: ${_transferTarget!['balance']} ريال'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _transferAmountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'المبلغ (ريال)',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                prefixIcon: const Icon(Icons.money),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _executeTransfer,
                icon: const Icon(Icons.send, color: Colors.white),
                label: const Text('تنفيذ التحويل',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade700,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10))),
              ),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildQRTab(String accountNumber, String userName) {
    final qrData = '{"acc":"$accountNumber","name":"$userName"}';
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('استقبال رصيد',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 5),
            const Text('امسح هذا الكود لتحويل الرصيد إليك',
                style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 25),
            RepaintBoundary(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))
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
                  icon: const Icon(Icons.copy),
                  label: const Text('نسخ الحساب'),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: () {
                    _showSnack('ميزة مسح QR قيد التطوير');
                  },
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('مسح QR'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;
  final Color color;
  _SliverAppBarDelegate(this._tabBar, {required this.color});
  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;
  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) =>
      Container(color: color, child: _tabBar);
  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}
