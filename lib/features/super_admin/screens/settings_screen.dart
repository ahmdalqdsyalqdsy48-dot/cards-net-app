import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/providers/wallet_provider.dart';
import '../../../core/providers/agent_admin_provider.dart';
import '../../../core/providers/audit_provider.dart';
import '../../../core/providers/ui_provider.dart';
import '../../../core/widgets/custom_drawer.dart';
import '../../../core/widgets/custom_header.dart';

import 'portals_management_screen.dart';
import 'banners_screen.dart';
import 'sms_gateway_screen.dart';
import 'backup_screen.dart';
import 'audit_log_screen.dart';
import 'advanced_reset_screen.dart';

class GlobalSettingsScreen extends StatefulWidget {
  const GlobalSettingsScreen({super.key});

  @override
  State<GlobalSettingsScreen> createState() => _GlobalSettingsScreenState();
}

class _GlobalSettingsScreenState extends State<GlobalSettingsScreen> {
  // متحكمات النصوص
  final _termsController = TextEditingController();
  final _supportController = TextEditingController();
  final _minChargeController = TextEditingController();
  final _announcementController = TextEditingController();
  final _transferFeeController = TextEditingController();
  final _dailyLimitController = TextEditingController();
  final _monthlyLimitController = TextEditingController();
  final _sessionTimeoutController = TextEditingController();
  final _maxLoginAttemptsController = TextEditingController();
  final _lowStockThresholdController = TextEditingController();
  final _reportEmailController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _facebookController = TextEditingController();
  final _telegramController = TextEditingController();
  final _targetedNewsController = TextEditingController();
  final _emergencyAlertTextController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();
  final _promoImageController = TextEditingController();
  final _promoPhoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    final settings = context.read<SettingsProvider>();
    _termsController.text = settings.termsAndConditions;
    _supportController.text = settings.supportNumbers;
    _minChargeController.text = settings.minimumChargeLimit;
    _transferFeeController.text = (settings.transferFeeRate * 100).toString();
    _dailyLimitController.text = settings.dailyTransferLimit.toString();
    _monthlyLimitController.text = settings.monthlyTransferLimit.toString();
    _sessionTimeoutController.text = settings.sessionTimeoutMinutes.toString();
    _maxLoginAttemptsController.text = settings.maxLoginAttempts.toString();
    _lowStockThresholdController.text = settings.lowStockThreshold.toString();
    _reportEmailController.text = settings.reportEmail;
    _whatsappController.text = settings.socialLinks['whatsapp'] ?? '';
    _facebookController.text = settings.socialLinks['facebook'] ?? '';
    _telegramController.text = settings.socialLinks['telegram'] ?? '';
  }

  @override
  void dispose() {
    _termsController.dispose();
    _supportController.dispose();
    _minChargeController.dispose();
    _announcementController.dispose();
    _transferFeeController.dispose();
    _dailyLimitController.dispose();
    _monthlyLimitController.dispose();
    _sessionTimeoutController.dispose();
    _maxLoginAttemptsController.dispose();
    _lowStockThresholdController.dispose();
    _reportEmailController.dispose();
    _whatsappController.dispose();
    _facebookController.dispose();
    _telegramController.dispose();
    _targetedNewsController.dispose();
    _emergencyAlertTextController.dispose();
    _emergencyPhoneController.dispose();
    _promoImageController.dispose();
    _promoPhoneController.dispose();
    super.dispose();
  }

  void _play(String type) => context.read<UiProvider>().playSound(type);

  Future<void> _saveAll() async {
    _play('click');
    final settings = context.read<SettingsProvider>();
    try {
      await Future.wait([
        settings.updatePoliciesSettings(
          terms: _termsController.text,
          support: _supportController.text,
          minCharge: _minChargeController.text,
          autoRounding: settings.isCurrencyAutoRounding,
        ),
        settings.updateSystemStatusSettings(
          maintenance: settings.isMaintenanceMode,
          forcedUpdate: settings.isForcedUpdate,
          showNews: settings.showNewsBar,
        ),
        settings.updateAgentPortalSettings(
          hideProfit: settings.hideProfitEnabled,
          leaderboard: settings.leaderboardEnabled,
          forceTheme: settings.forceAgentTheme,
          universalHidden: settings.agentUniversalHiddenSections,
        ),
        settings.updateUserPortalSettings(
          guestMode: settings.guestModeEnabled,
          kyc: settings.kycRequired,
          loyalty: settings.loyaltySystemEnabled,
          universalHidden: settings.userUniversalHiddenSections,
          social: {
            'whatsapp': _whatsappController.text,
            'facebook': _facebookController.text,
            'telegram': _telegramController.text,
          },
        ),
      ]);
      _play('success');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حفظ جميع الإعدادات بنجاح ✅', textDirection: TextDirection.rtl), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      _play('error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل الحفظ: $e', textDirection: TextDirection.rtl), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _navigateTo(Widget screen) {
    _play('click');
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final settings = context.watch<SettingsProvider>();
    final wallet = context.watch<WalletProvider>();
    final agentAdmin = context.read<AgentAdminProvider>();
    final audit = context.read<AuditProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: const CustomHeader(title: 'الإعدادات العامة'),
      drawer: CustomDrawer(
        userName: wallet.currentUserName,
        phoneNumber: auth.activeUserPhone ?? '',
        role: 'مالك النظام',
        balanceOrPoints: 'أرباح: ${settings.adminMainBalance.toStringAsFixed(0)} ريال',
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: RefreshIndicator(
          onRefresh: () async {
            _loadSettings();
            await Future.delayed(const Duration(milliseconds: 300));
            _play('success');
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ────────────── الروابط السريعة ──────────────
              _buildSectionTitle('⚡ إعدادات متقدمة (شاشات متخصصة)'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildQuickLink('إدارة البوابات', Icons.web, () => _navigateTo(const PortalsManagementScreen())),
                  _buildQuickLink('الإعلانات', Icons.campaign, () => _navigateTo(const BannersScreen())),
                  _buildQuickLink('بوابة SMS', Icons.sms, () => _navigateTo(const SmsGatewayScreen())),
                  _buildQuickLink('النسخ الاحتياطي', Icons.cloud_upload, () => _navigateTo(const BackupScreen())),
                  _buildQuickLink('السجل الأسود', Icons.security, () => _navigateTo(const AuditLogScreen())),
                  _buildQuickLink('التحكم الشامل', Icons.cleaning_services, () => _navigateTo(const AdvancedResetScreen())),
                ],
              ),
              const Divider(height: 30),

              // ────────────── حالة النظام ──────────────
              _buildSectionTitle('🖥️ حالة النظام'),
              SwitchListTile(
                title: const Text('وضع الصيانة'),
                subtitle: const Text('إيقاف التطبيق للمستخدمين مع رسالة صيانة'),
                value: settings.isMaintenanceMode,
                onChanged: (v) {
                  _play('click');
                  settings.updateSystemStatusSettings(maintenance: v, forcedUpdate: settings.isForcedUpdate, showNews: settings.showNewsBar);
                },
              ),
              SwitchListTile(
                title: const Text('تحديث إجباري'),
                subtitle: const Text('إجبار جميع المستخدمين على تحديث التطبيق'),
                value: settings.isForcedUpdate,
                onChanged: (v) {
                  _play('click');
                  settings.updateSystemStatusSettings(maintenance: settings.isMaintenanceMode, forcedUpdate: v, showNews: settings.showNewsBar);
                },
              ),
              SwitchListTile(
                title: const Text('التقريب التلقائي للعملة'),
                value: settings.isCurrencyAutoRounding,
                onChanged: (v) {
                  _play('click');
                  settings.updatePoliciesSettings(terms: _termsController.text, support: _supportController.text, minCharge: _minChargeController.text, autoRounding: v);
                },
              ),
              const Divider(),

              // ────────────── السياسات المالية ──────────────
              _buildSectionTitle('💰 السياسات المالية'),
              _buildTextField('الحد الأدنى للشحن (بالريال)', _minChargeController, Icons.money),
              _buildTextField('رسوم التحويل (%)', _transferFeeController, Icons.percent),
              _buildTextField('حد التحويل اليومي (للمستخدم)', _dailyLimitController, Icons.today),
              _buildTextField('حد التحويل الشهري (للمستخدم)', _monthlyLimitController, Icons.calendar_month),
              const Divider(),

              // ────────────── الشريط الإخباري ──────────────
              _buildSectionTitle('📢 الشريط الإخباري (Marquee)'),
              SwitchListTile(
                title: const Text('تفعيل الشريط الإخباري'),
                value: settings.showNewsBar,
                onChanged: (v) {
                  _play('click');
                  settings.updateSystemStatusSettings(maintenance: settings.isMaintenanceMode, forcedUpdate: settings.isForcedUpdate, showNews: v);
                },
              ),
              _buildTextField('نص الشريط', _announcementController, Icons.edit_note, maxLines: 2),
              const Divider(),

              // ────────────── إعدادات الوكلاء ──────────────
              _buildSectionTitle('👥 إعدادات الوكلاء'),
              SwitchListTile(
                title: const Text('إخفاء الأرباح عن الوكلاء'),
                value: settings.hideProfitEnabled,
                onChanged: (v) {
                  _play('click');
                  settings.updateAgentPortalSettings(hideProfit: v, leaderboard: settings.leaderboardEnabled, forceTheme: settings.forceAgentTheme, universalHidden: settings.agentUniversalHiddenSections);
                },
              ),
              SwitchListTile(
                title: const Text('لوحة الصدارة'),
                value: settings.leaderboardEnabled,
                onChanged: (v) {
                  _play('click');
                  settings.updateAgentPortalSettings(hideProfit: settings.hideProfitEnabled, leaderboard: v, forceTheme: settings.forceAgentTheme, universalHidden: settings.agentUniversalHiddenSections);
                },
              ),
              SwitchListTile(
                title: const Text('إجبار ثيم النظام للوكلاء'),
                value: settings.forceAgentTheme,
                onChanged: (v) {
                  _play('click');
                  settings.updateAgentPortalSettings(hideProfit: settings.hideProfitEnabled, leaderboard: settings.leaderboardEnabled, forceTheme: v, universalHidden: settings.agentUniversalHiddenSections);
                },
              ),
              const Divider(),

              // ────────────── إعدادات المستخدمين ──────────────
              _buildSectionTitle('🧑‍💻 إعدادات المستخدمين'),
              SwitchListTile(
                title: const Text('وضع الضيف'),
                value: settings.guestModeEnabled,
                onChanged: (v) {
                  _play('click');
                  settings.updateUserPortalSettings(guestMode: v, kyc: settings.kycRequired, loyalty: settings.loyaltySystemEnabled, universalHidden: settings.userUniversalHiddenSections, social: settings.socialLinks);
                },
              ),
              SwitchListTile(
                title: const Text('التحقق (KYC)'),
                value: settings.kycRequired,
                onChanged: (v) {
                  _play('click');
                  settings.updateUserPortalSettings(guestMode: settings.guestModeEnabled, kyc: v, loyalty: settings.loyaltySystemEnabled, universalHidden: settings.userUniversalHiddenSections, social: settings.socialLinks);
                },
              ),
              SwitchListTile(
                title: const Text('نظام الولاء'),
                value: settings.loyaltySystemEnabled,
                onChanged: (v) {
                  _play('click');
                  settings.updateUserPortalSettings(guestMode: settings.guestModeEnabled, kyc: settings.kycRequired, loyalty: v, universalHidden: settings.userUniversalHiddenSections, social: settings.socialLinks);
                },
              ),
              _buildTextField('رابط واتساب', _whatsappController, Icons.chat),
              _buildTextField('رابط فيسبوك', _facebookController, Icons.facebook),
              _buildTextField('رابط تيليغرام', _telegramController, Icons.telegram),
              const Divider(),

              // ────────────── التنبيهات والنوافذ ──────────────
              _buildSectionTitle('🚨 التنبيهات والنوافذ'),
              SwitchListTile(
                title: const Text('تنبيه طوارئ للوكلاء'),
                value: settings.agentEmergencyAlert['isActive'] ?? false,
                onChanged: (v) {
                  _play('click');
                  settings.setEmergencyAlert(
                    isActive: v,
                    text: settings.agentEmergencyAlert['text'] ?? '',
                    targetType: settings.agentEmergencyAlert['targetType'] ?? 'all',
                    targetPhones: List<String>.from(settings.agentEmergencyAlert['targetPhones'] ?? []),
                  );
                },
              ),
              _buildTextField('نص التنبيه', _emergencyAlertTextController, Icons.warning),
              _buildTextField('رقم الوكيل (إن كان الاستهداف فردي)', _emergencyPhoneController, Icons.phone),
              SwitchListTile(
                title: const Text('نافذة ترويجية للمستخدمين'),
                value: settings.userPromoPopup['isActive'] ?? false,
                onChanged: (v) {
                  _play('click');
                  settings.updateUserPortalSettings(
                    guestMode: settings.guestModeEnabled,
                    kyc: settings.kycRequired,
                    loyalty: settings.loyaltySystemEnabled,
                    universalHidden: settings.userUniversalHiddenSections,
                    social: settings.socialLinks,
                  );
                },
              ),
              _buildTextField('رابط الصورة الترويجية', _promoImageController, Icons.image),
              _buildTextField('رقم المستخدم (إن كان الاستهداف فردي)', _promoPhoneController, Icons.person),
              const Divider(),

              // ────────────── الأخبار المستهدفة ──────────────
              _buildSectionTitle('📰 الأخبار المستهدفة'),
              Row(
                children: [
                  Expanded(child: _buildTextField('نص الخبر', _targetedNewsController, Icons.article)),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      if (_targetedNewsController.text.isNotEmpty) {
                        _play('click');
                        settings.addTargetedNews(text: _targetedNewsController.text, targetRole: 'all');
                        _targetedNewsController.clear();
                        _play('success');
                      }
                    },
                    child: const Text('إضافة'),
                  ),
                ],
              ),
              ...settings.targetedNews.map((news) => ListTile(
                title: Text(news['text'] ?? ''),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () {
                    _play('click');
                    settings.removeTargetedNews(news);
                    _play('success');
                  },
                ),
              )),
              const Divider(),

              // ────────────── الإشعارات العامة ──────────────
              _buildSectionTitle('🔔 الإشعارات العامة'),
              SwitchListTile(
                title: const Text('إشعارات الشحن'),
                value: settings.notifyOnRecharge,
                onChanged: (v) => settings.setNotifyOnRecharge(v),
              ),
              SwitchListTile(
                title: const Text('إشعارات الكوبونات'),
                value: settings.notifyOnCoupon,
                onChanged: (v) => settings.setNotifyOnCoupon(v),
              ),
              SwitchListTile(
                title: const Text('إشعارات التحديثات'),
                value: settings.notifyOnUpdate,
                onChanged: (v) => settings.setNotifyOnUpdate(v),
              ),
              SwitchListTile(
                title: const Text('إشعارات التذاكر'),
                value: settings.notifyOnTicket,
                onChanged: (v) => settings.setNotifyOnTicket(v),
              ),
              const Divider(),

              // ────────────── الأمان ──────────────
              _buildSectionTitle('🔒 الأمان والحماية'),
              SwitchListTile(
                title: const Text('التحقق بخطوتين (2FA)'),
                value: settings.twoFactorEnabled,
                onChanged: (v) => settings.setTwoFactorEnabled(v),
              ),
              _buildTextField('مدة الجلسة (دقائق)', _sessionTimeoutController, Icons.timer),
              _buildTextField('أقصى محاولات دخول فاشلة', _maxLoginAttemptsController, Icons.lock),
              const Divider(),

              // ────────────── الكروت والمخزون ──────────────
              _buildSectionTitle('🎴 الكروت والمخزون'),
              SwitchListTile(
                title: const Text('الشراء التلقائي عند نفاذ المخزون'),
                value: settings.autoPurchaseEnabled,
                onChanged: (v) => settings.setAutoPurchaseEnabled(v),
              ),
              _buildTextField('حد المخزون للتنبيه', _lowStockThresholdController, Icons.inventory),
              SwitchListTile(
                title: const Text('إخفاء الكروت المباعة'),
                value: settings.hideSoldCards,
                onChanged: (v) => settings.setHideSoldCards(v),
              ),
              const Divider(),

              // ────────────── الفوترة والتقارير ──────────────
              _buildSectionTitle('📊 الفوترة والتقارير'),
              SwitchListTile(
                title: const Text('تقارير أسبوعية للبريد'),
                value: settings.weeklyReportsEnabled,
                onChanged: (v) => settings.setWeeklyReportsEnabled(v),
              ),
              _buildTextField('البريد الإلكتروني للتقارير', _reportEmailController, Icons.email),
              SwitchListTile(
                title: const Text('تسجيل الأرباح كمصروفات'),
                value: settings.logProfitAsExpense,
                onChanged: (v) => settings.setLogProfitAsExpense(v),
              ),
              const Divider(),

              // ────────────── واجهة المستخدم ──────────────
              _buildSectionTitle('🎨 واجهة المستخدم'),
              SwitchListTile(
                title: const Text('السحب للتحديث'),
                value: settings.pullToRefreshEnabled,
                onChanged: (v) => settings.setPullToRefreshEnabled(v),
              ),
              SwitchListTile(
                title: const Text('المؤثرات البصرية'),
                value: settings.animationsEnabled,
                onChanged: (v) => settings.setAnimationsEnabled(v),
              ),
              SwitchListTile(
                title: const Text('الوضع الليلي الإجباري'),
                value: settings.forceDarkMode,
                onChanged: (v) => settings.setForceDarkMode(v),
              ),
              const Divider(),

              // ────────────── المستخدمين المحظورين ──────────────
              _buildSectionTitle('🚫 المستخدمين المحظورين'),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('users').where('isBanned', isEqualTo: true).snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const CircularProgressIndicator();
                  final banned = snapshot.data!.docs;
                  if (banned.isEmpty) return const Text('لا يوجد مستخدمين محظورين');
                  return Column(
                    children: banned.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return ListTile(
                        leading: const Icon(Icons.block, color: Colors.red),
                        title: Text(data['name'] ?? 'مجهول'),
                        subtitle: Text(data['phone'] ?? ''),
                        trailing: ElevatedButton(
                          onPressed: () {
                            _play('click');
                            agentAdmin.adminToggleUserBan(data['phone'], false);
                            _play('success');
                          },
                          child: const Text('فك الحظر'),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
              const Divider(),

              // ────────────── أرقام النظام ──────────────
              _buildSectionTitle('📈 أرقام النظام (قراءة فقط)'),
              _buildReadOnlyRow('الرصيد الرئيسي', '${settings.adminMainBalance.toStringAsFixed(0)} ريال'),
              _buildReadOnlyRow('إجمالي الكروت', '${settings.totalSystemCards}'),
              _buildReadOnlyRow('رصيد SMS', '${settings.smsBalance}'),
              const SizedBox(height: 20),

              // ────────────── زر الحفظ ──────────────
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _saveAll,
                  icon: const Icon(Icons.save, color: Colors.white),
                  label: const Text('حفظ جميع الإعدادات', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 16),
      child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blueAccent)),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, IconData icon, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.blueAccent),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        ),
      ),
    );
  }

  Widget _buildReadOnlyRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(value, style: const TextStyle(fontSize: 16, color: Colors.blueGrey)),
        ],
      ),
    );
  }

  Widget _buildQuickLink(String label, IconData icon, VoidCallback onTap) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue.shade50,
        foregroundColor: Colors.blueAccent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
