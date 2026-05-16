// lib/features/super_admin/screens/advanced_reset_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/providers/system_provider.dart';
import '../../../core/providers/ui_provider.dart';
import '../../../core/widgets/custom_header.dart';

class AdvancedResetScreen extends StatefulWidget {
  const AdvancedResetScreen({super.key});

  @override
  State<AdvancedResetScreen> createState() => _AdvancedResetScreenState();
}

class _AdvancedResetScreenState extends State<AdvancedResetScreen> {
  // ========== خيارات الهدف ==========
  String _targetType = 'agent'; // agent, user, all_agents, all_users, self
  final TextEditingController _targetPhoneController = TextEditingController();
  final TextEditingController _targetAccountController = TextEditingController();

  // ========== خيارات الإجراء ==========
  bool _resetBalance = false;
  bool _resetNetworks = false;
  bool _resetTransactions = false;
  bool _resetCards = false;
  bool _resetBankAccounts = false;
  bool _resetSubscriptions = false;
  bool _deleteAccount = false;
  bool _renameAccount = false;
  bool _mergeRecords = false;
  bool _exportBeforeDelete = false;

  // ========== إعادة تسمية ==========
  final TextEditingController _renameController = TextEditingController();

  // ========== دمج ==========
  final TextEditingController _mergeFromController = TextEditingController();
  final TextEditingController _mergeToController = TextEditingController();

  // ========== حالة التحقق ==========
  bool _obscurePassword = true;
  bool _obscurePin = true;
  bool _usePinInstead = true; // افتراضي: PIN

  bool _isProcessing = false;
  String? _previewResult;

  void _play(String type) =>
      Provider.of<UiProvider>(context, listen: false).playSound(type);

  @override
  void dispose() {
    _targetPhoneController.dispose();
    _targetAccountController.dispose();
    _renameController.dispose();
    _mergeFromController.dispose();
    _mergeToController.dispose();
    super.dispose();
  }

  // ==========================================
  // معاينة التأثير
  // ==========================================
  Future<void> _preview() async {
    _play('click');
    setState(() => _previewResult = null);
    final sys = Provider.of<SystemProvider>(context, listen: false);
    try {
      final res = await sys.previewResetImpact(
        phone: _targetPhoneController.text.trim(),
        accountNumber: _targetAccountController.text.trim(),
        targetType: _targetType,
        options: _collectOptions(),
      );
      setState(() => _previewResult = res);
    } catch (e) {
      setState(() => _previewResult = 'خطأ: $e');
    }
  }

  // ==========================================
  // نافذة التحقق المزدوج (PIN أو كلمة مرور)
  // ==========================================
  Future<bool> _showAuthDialog() async {
    final sys = Provider.of<SystemProvider>(context, listen: false);
    final pinController = TextEditingController();
    final passController = TextEditingController();

    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('تأكيد هوية المشرف', textAlign: TextAlign.center),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // زر التبديل بين PIN وكلمة المرور
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(_usePinInstead ? 'PIN' : 'كلمة المرور',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    Switch(
                      value: _usePinInstead,
                      onChanged: (v) {
                        setState(() => _usePinInstead = v);
                        setDialogState(() => _usePinInstead = v);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_usePinInstead)
                  TextField(
                    controller: pinController,
                    obscureText: _obscurePin,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: InputDecoration(
                      labelText: 'رمز PIN (6 أرقام)',
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePin
                            ? Icons.visibility_off
                            : Icons.visibility),
                        onPressed: () {
                          setState(() => _obscurePin = !_obscurePin);
                          setDialogState(() => _obscurePin = !_obscurePin);
                        },
                      ),
                      border: const OutlineInputBorder(),
                    ),
                  )
                else
                  TextField(
                    controller: passController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'كلمة المرور',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility),
                        onPressed: () {
                          setState(() =>
                              _obscurePassword = !_obscurePassword);
                          setDialogState(() =>
                              _obscurePassword = !_obscurePassword);
                        },
                      ),
                      border: const OutlineInputBorder(),
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () async {
                  bool ok = false;
                  if (_usePinInstead) {
                    ok = sys.validatePin(pinController.text);
                  } else {
                    final doc = await FirebaseFirestore.instance
                        .collection('users')
                        .doc(sys.currentUserPhone)
                        .get();
                    ok = (doc.data()?['password'] ?? '') ==
                        passController.text;
                  }
                  Navigator.pop(ctx, ok);
                },
                child: const Text('تأكيد'),
              ),
            ],
          ),
        ),
      ),
    ) == true;
  }

  // ==========================================
  // تنفيذ الإجراء
  // ==========================================
  Future<void> _execute() async {
    _play('click');
    final sys = Provider.of<SystemProvider>(context, listen: false);

    final bool verified = await _showAuthDialog();
    if (!verified) {
      _showSnack('فشل التحقق من الهوية', error: true);
      return;
    }

    setState(() => _isProcessing = true);
    try {
      await sys.executeReset(
        phone: _targetPhoneController.text.trim(),
        accountNumber: _targetAccountController.text.trim(),
        targetType: _targetType,
        options: _collectOptions(),
        adminPassword: '', // لم نعد نستخدمها مباشرة
        renameTo: _renameAccount ? _renameController.text.trim() : null,
        mergeFrom: _mergeRecords ? _mergeFromController.text.trim() : null,
        mergeTo: _mergeRecords ? _mergeToController.text.trim() : null,
        exportBeforeDelete: _exportBeforeDelete,
      );
      _play('success');
      _showSnack('تم تنفيذ الإجراء بنجاح');
      _clearForm();
    } catch (e) {
      _play('error');
      _showSnack('فشل: $e', error: true);
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Map<String, dynamic> _collectOptions() {
    return {
      'resetBalance': _resetBalance,
      'resetNetworks': _resetNetworks,
      'resetTransactions': _resetTransactions,
      'resetCards': _resetCards,
      'resetBankAccounts': _resetBankAccounts,
      'resetSubscriptions': _resetSubscriptions,
      'deleteAccount': _deleteAccount,
      'renameAccount': _renameAccount,
      'mergeRecords': _mergeRecords,
    };
  }

  void _clearForm() {
    _targetPhoneController.clear();
    _targetAccountController.clear();
    setState(() {
      _resetBalance = false;
      _resetNetworks = false;
      _resetTransactions = false;
      _resetCards = false;
      _resetBankAccounts = false;
      _resetSubscriptions = false;
      _deleteAccount = false;
      _renameAccount = false;
      _mergeRecords = false;
      _exportBeforeDelete = false;
      _renameController.clear();
      _mergeFromController.clear();
      _mergeToController.clear();
      _previewResult = null;
    });
  }

  void _showSnack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg, textDirection: TextDirection.rtl),
          backgroundColor: error ? Colors.red : Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: CustomHeader(title: 'التحكم الشامل - إعادة التهيئة'),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ========== اختيار الهدف ==========
              Text('نوع الهدف', style: TextStyle(fontWeight: FontWeight.bold, color: colors.onSurface)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _targetType,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'agent', child: Text('وكيل محدد')),
                  DropdownMenuItem(value: 'user', child: Text('مستخدم محدد')),
                  DropdownMenuItem(value: 'all_agents', child: Text('جميع الوكلاء')),
                  DropdownMenuItem(value: 'all_users', child: Text('جميع المستخدمين')),
                  DropdownMenuItem(value: 'self', child: Text('مالك النظام (أنا)')),
                ],
                onChanged: (v) => setState(() => _targetType = v!),
              ),
              const SizedBox(height: 12),

              // حقول البحث (للاستهداف الفردي)
              if (_targetType == 'agent' || _targetType == 'user') ...[
                TextField(
                  controller: _targetPhoneController,
                  decoration: const InputDecoration(
                    labelText: 'رقم الهاتف',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _targetAccountController,
                  decoration: const InputDecoration(
                    labelText: 'رقم الحساب (اختياري)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.credit_card),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // ========== خيارات الإجراء ==========
              Text('اختر ما تريد تنفيذه', style: TextStyle(fontWeight: FontWeight.bold, color: colors.onSurface)),
              const SizedBox(height: 8),
              _buildCheckbox('تصفير الرصيد', _resetBalance, (v) => setState(() => _resetBalance = v!)),
              if (_targetType == 'agent' || _targetType == 'all_agents')
                _buildCheckbox('حذف الشبكات', _resetNetworks, (v) => setState(() => _resetNetworks = v!)),
              _buildCheckbox('حذف السجلات المالية', _resetTransactions, (v) => setState(() => _resetTransactions = v!)),
              _buildCheckbox('حذف الكروت المشتراة', _resetCards, (v) => setState(() => _resetCards = v!)),
              if (_targetType == 'agent' || _targetType == 'all_agents')
                _buildCheckbox('حذف الحسابات البنكية', _resetBankAccounts, (v) => setState(() => _resetBankAccounts = v!)),
              if (_targetType == 'agent' || _targetType == 'all_agents')
                _buildCheckbox('حذف الاشتراكات والباقات', _resetSubscriptions, (v) => setState(() => _resetSubscriptions = v!)),
              _buildCheckbox('حذف الحساب بالكامل (نهائي)', _deleteAccount, (v) => setState(() => _deleteAccount = v!)),

              const Divider(height: 30),

              // ========== خيارات إضافية ==========
              Text('خيارات متقدمة', style: TextStyle(fontWeight: FontWeight.bold, color: colors.onSurface)),
              const SizedBox(height: 8),
              _buildCheckbox('إعادة تسمية الحساب', _renameAccount, (v) => setState(() => _renameAccount = v!)),
              if (_renameAccount)
                TextField(
                  controller: _renameController,
                  decoration: const InputDecoration(labelText: 'الاسم الجديد', border: OutlineInputBorder()),
                ),
              const SizedBox(height: 8),
              _buildCheckbox('دمج سجلات', _mergeRecords, (v) => setState(() => _mergeRecords = v!)),
              if (_mergeRecords) ...[
                TextField(controller: _mergeFromController, decoration: const InputDecoration(labelText: 'رقم هاتف المصدر', border: OutlineInputBorder())),
                const SizedBox(height: 8),
                TextField(controller: _mergeToController, decoration: const InputDecoration(labelText: 'رقم هاتف الهدف', border: OutlineInputBorder())),
              ],
              const SizedBox(height: 8),
              _buildCheckbox('تصدير البيانات قبل الحذف', _exportBeforeDelete, (v) => setState(() => _exportBeforeDelete = v!)),

              const SizedBox(height: 20),

              // ========== أزرار التحكم ==========
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _preview,
                      icon: const Icon(Icons.preview),
                      label: const Text('معاينة التأثير'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isProcessing ? null : _execute,
                      icon: _isProcessing
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.warning),
                      label: Text(_isProcessing ? 'جاري التنفيذ...' : 'تنفيذ الإجراء'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ========== نتيجة المعاينة ==========
              if (_previewResult != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.surfaceVariant,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(_previewResult!, style: TextStyle(color: colors.onSurfaceVariant)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCheckbox(String title, bool value, Function(bool?) onChanged) {
    return CheckboxListTile(
      title: Text(title),
      value: value,
      onChanged: onChanged,
    );
  }
}
