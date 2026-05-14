// lib/features/user_panel/screens/user_wallet_screen.dart

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
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

class _UserWalletScreenState extends State<UserWalletScreen> {
  String _searchQuery = '';
  String? _selectedBankAccountId; // لمعرفة الحساب المختار حالياً
  final _amountController = TextEditingController();
  final _referenceController = TextEditingController();
  File? _receiptImage;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _amountController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  void _play(BuildContext context, String type) =>
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

  // جلب الحسابات البنكية النشطة التي تطابق شبكات المستخدم
  // يأتي من مزود النظام ويُعرض كبطاقات قابلة للإختيار
  Future<List<Map<String, dynamic>>> _fetchBankAccounts(
      SystemProvider provider) async {
    try {
      return await provider.getActiveBankAccountsForUserNetworks();
    } catch (e) {
      _showSnack('فشل تحميل الحسابات البنكية: $e', error: true);
      return [];
    }
  }

  // فتح كاميرا أو معرض الصور لرفع الإيصال
  Future<void> _pickReceiptImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _receiptImage = File(picked.path));
    }
  }

  // إرسال طلب الشحن
  Future<void> _submitDepositRequest(SystemProvider provider) async {
    if (_selectedBankAccountId == null) {
      _showSnack('الرجاء اختيار حساب بنكي أولاً', error: true);
      return;
    }
    if (_amountController.text.trim().isEmpty) {
      _showSnack('الرجاء إدخال المبلغ', error: true);
      return;
    }
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      _showSnack('المبلغ غير صحيح', error: true);
      return;
    }
    if (_receiptImage == null) {
      _showSnack('الرجاء إرفاق صورة الإيصال', error: true);
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      // رفع صورة الإيصال إلى Firebase Storage ثم الحصول على الرابط
      final receiptUrl = await provider.uploadReceiptImage(_receiptImage!);

      // إنشاء طلب الشحن
      await provider.submitDepositRequest(
        bankAccountId: _selectedBankAccountId!,
        amount: amount,
        reference: _referenceController.text.trim(),
        receiptImageUrl: receiptUrl,
      );

      _play(context, 'success');
      _showSnack('تم إرسال طلب الشحن بنجاح، بانتظار مراجعة الوكيل');

      // تنظيف الحقول
      _amountController.clear();
      _referenceController.clear();
      setState(() {
        _receiptImage = null;
        _selectedBankAccountId = null;
      });
    } catch (e) {
      _showSnack('فشل إرسال الطلب: $e', error: true);
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  // إلغاء طلب معلق
  Future<void> _cancelPendingRequest(
      SystemProvider provider, String docId) async {
    try {
      await provider.cancelDepositRequest(docId);
      _showSnack('تم إلغاء الطلب');
    } catch (e) {
      _showSnack('فشل إلغاء الطلب: $e', error: true);
    }
  }

  // نسخ بيانات الحساب
  void _copyAccountDetails(Map<String, dynamic> account) {
    final buffer = StringBuffer();
    buffer.writeln('🏦 ${account['bankName']}');
    buffer.writeln('🔢 الحساب: ${account['accountNumber']}');
    buffer.writeln('👤 باسم: ${account['beneficiary'] ?? ''}');
    if ((account['networkName'] ?? '').toString().isNotEmpty) {
      buffer.writeln('🌐 الشبكة: ${account['networkName']}');
    }
    if ((account['note'] ?? '').toString().isNotEmpty &&
        account['note'] != 'لا توجد ملاحظات') {
      buffer.writeln('📝 ملاحظة: ${account['note']}');
    }
    Clipboard.setData(ClipboardData(text: buffer.toString()));
    _showSnack('تم نسخ بيانات الحساب');
  }

  // مشاركة بيانات الحساب
  void _shareAccountDetails(Map<String, dynamic> account) {
    final buffer = StringBuffer();
    buffer.writeln('🏦 ${account['bankName']}');
    buffer.writeln('🔢 الحساب: ${account['accountNumber']}');
    buffer.writeln('👤 باسم: ${account['beneficiary'] ?? ''}');
    if ((account['networkName'] ?? '').toString().isNotEmpty) {
      buffer.writeln('🌐 الشبكة: ${account['networkName']}');
    }
    Share.share(buffer.toString(), subject: 'بيانات الحساب البنكي');
  }

  // بناء بطاقة الحساب البنكي (قابلة للتحديد)
  Widget _buildBankAccountCard(
      Map<String, dynamic> account, SystemProvider provider) {
    final colors = Theme.of(context).colorScheme;
    final bool isSelected = _selectedBankAccountId == account['docId'];

    return Card(
      elevation: isSelected ? 4 : 1,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? colors.primary : colors.outlineVariant,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          setState(() {
            _selectedBankAccountId = account['docId'];
          });
          _play(context, 'click');
        },
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      account['bankName'] ?? '',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: colors.primary),
                    ),
                  ),
                  // شبكة الحساب
                  if ((account['networkName'] ?? '').toString().isNotEmpty)
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: colors.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        account['networkName'] ?? '',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'رقم الحساب: ${account['accountNumber'] ?? ''}',
                style: TextStyle(fontSize: 14, color: colors.onSurface),
                textDirection: TextDirection.ltr,
              ),
              Text(
                'المستفيد: ${account['beneficiary'] ?? ''}',
                style:
                    TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
              ),
              if (account['note'] != null &&
                  account['note'].toString().isNotEmpty &&
                  account['note'] != 'لا توجد ملاحظات')
                Text(
                  'ملاحظة: ${account['note']}',
                  style: TextStyle(fontSize: 10, color: colors.onSurfaceVariant),
                ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: Icon(Icons.copy, size: 20, color: colors.primary),
                    onPressed: () => _copyAccountDetails(account),
                    tooltip: 'نسخ البيانات',
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: Icon(Icons.share, size: 20, color: colors.primary),
                    onPressed: () => _shareAccountDetails(account),
                    tooltip: 'مشاركة',
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // بناء عنصر طلب معلق
  Widget _buildPendingRequest(
      Map<String, dynamic> request, SystemProvider provider) {
    final colors = Theme.of(context).colorScheme;
    final status = request['status'] ?? '';
    final isPending = status == 'pending';
    final IconData statusIcon;
    final Color statusColor;
    switch (status) {
      case 'approved':
        statusIcon = Icons.check_circle;
        statusColor = Colors.green;
        break;
      case 'rejected':
        statusIcon = Icons.cancel;
        statusColor = colors.error;
        break;
      default:
        statusIcon = Icons.hourglass_empty;
        statusColor = Colors.orange;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: Icon(statusIcon, color: statusColor, size: 28),
        title: Text(
          '${request['amount'] ?? ''} ريال',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (request['bankName'] != null)
              Text('الحساب: ${request['bankName']}'),
            if (request['createdAt'] != null)
              Text('التاريخ: ${_formatTimestamp(request['createdAt'])}'),
            if (status == 'rejected' && request['rejectionReason'] != null)
              Text('سبب الرفض: ${request['rejectionReason']}',
                  style: TextStyle(color: colors.error, fontSize: 12)),
          ],
        ),
        trailing: isPending
            ? IconButton(
                icon: const Icon(Icons.close, color: Colors.red),
                onPressed: () => _cancelPendingRequest(provider, request['docId']),
                tooltip: 'إلغاء الطلب',
              )
            : null,
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '';
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      return '${date.year}/${date.month}/${date.day}';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final sys = Provider.of<SystemProvider>(context);
    final colors = Theme.of(context).colorScheme;

    // البيانات الأساسية
    final balance = sys.currentUserBalance;
    final networkIds = sys.currentUserNetworkIds ?? [];
    final bool hasNetworks = networkIds.isNotEmpty;

    return Scaffold(
      appBar: const CustomHeader(title: 'محفظتي'),
      drawer: CustomUserDrawer(
        userName: sys.currentUserName,
        phoneNumber: sys.currentUserPhone,
        role: 'مستخدم',
        currentBalance: balance,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              // ============ 1. بطاقة الرصيد ============
              Container(
                width: double.infinity,
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [colors.primary, colors.secondary],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: colors.primary.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Text(
                      'رصيدي الحالي',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$balance ريال',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildActionButton(
                          label: 'إيداع',
                          icon: Icons.add_circle_outline,
                          onTap: () {
                            // التركيز على قسم الإيداع الموجود بالأسفل
                            // يمكن استخدام Scrollable.ensureVisible إذا أردت
                          },
                        ),
                        if (false) // زر تحويل إن وُجد لاحقاً
                          _buildActionButton(
                            label: 'تحويل',
                            icon: Icons.swap_horiz,
                            onTap: () {},
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // ============ 2. قسم الإيداع ============
              if (!hasNetworks)
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Text(
                    'أنت غير مرتبط بأي شبكة حالياً. تواصل مع الدعم لربط حسابك بشبكة.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                )
              else ...[
                // عنوان
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'اختر الحساب البنكي للتحويل إليه',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // قائمة الحسابات البنكية (تأتي من جميع الوكلاء الذين يشتركون بشبكات المستخدم)
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _fetchBankAccounts(sys),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError || snapshot.data == null) {
                      return const Center(child: Text('فشل تحميل الحسابات'));
                    }
                    final accounts = snapshot.data!;
                    if (accounts.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('لا توجد حسابات بنكية نشطة متاحة لشبكاتك حالياً.'),
                      );
                    }
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: accounts
                            .map((acc) => _buildBankAccountCard(acc, sys))
                            .toList(),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 16),

                // نموذج إدخال بيانات الشحن (يظهر فقط عند اختيار حساب)
                if (_selectedBankAccountId != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'بيانات التحويل',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _amountController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'المبلغ (بالريال)',
                                prefixIcon: Icon(Icons.money, color: colors.primary),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _referenceController,
                              decoration: InputDecoration(
                                labelText: 'رقم العملية / الحوالة (اختياري)',
                                prefixIcon: Icon(Icons.receipt_long,
                                    color: colors.primary),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                            const SizedBox(height: 12),
                            // صورة الإيصال
                            InkWell(
                              onTap: _pickReceiptImage,
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                      color: colors.outlineVariant),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: _receiptImage == null
                                    ? Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.camera_alt,
                                              color: colors.primary),
                                          const SizedBox(width: 8),
                                          Text('اضغط لإرفاق صورة الإيصال',
                                              style: TextStyle(
                                                  color: colors.primary)),
                                        ],
                                      )
                                    : Column(
                                        children: [
                                          Image.file(
                                            _receiptImage!,
                                            height: 150,
                                            width: double.infinity,
                                            fit: BoxFit.cover,
                                          ),
                                          const SizedBox(height: 8),
                                          TextButton.icon(
                                            onPressed: _pickReceiptImage,
                                            icon: const Icon(Icons.refresh),
                                            label: const Text('تغيير الصورة'),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton.icon(
                                onPressed:
                                    _isSubmitting ? null : () => _submitDepositRequest(sys),
                                icon: _isSubmitting
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white),
                                      )
                                    : const Icon(Icons.check_circle_outline),
                                label: Text(_isSubmitting
                                    ? 'جارٍ الإرسال...'
                                    : 'تأكيد التحويل وإرسال الطلب'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: colors.primary,
                                  foregroundColor: colors.onPrimary,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],

              const SizedBox(height: 16),

              // ============ 3. الطلبات المعلقة ============
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'طلبات الشحن المعلقة',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        // الانتقال إلى شاشة كشف الحساب الكامل
                        Navigator.pushNamed(context, '/transactions');
                        // أو استبدلها بشاشتك الفعلية
                      },
                      icon: const Icon(Icons.history),
                      label: const Text('عرض الكل'),
                    ),
                  ],
                ),
              ),
              StreamBuilder<List<Map<String, dynamic>>>(
                stream: sys.getPendingDepositRequestsStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final requests = snapshot.data ?? [];
                  if (requests.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('لا توجد طلبات شحن حالياً.',
                          style: TextStyle(color: colors.onSurfaceVariant)),
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: requests
                          .map((req) => _buildPendingRequest(req, sys))
                          .toList(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(
      {required String label,
      required IconData icon,
      required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }
}
