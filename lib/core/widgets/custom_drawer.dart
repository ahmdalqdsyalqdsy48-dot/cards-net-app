import 'dart:convert'; // 👈 ضروري للتعامل مع صور Base64
import 'dart:typed_data'; 
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 

// 👈 استدعاء العقول المدبرة للألوان والأصوات
import '../providers/theme_provider.dart';
import '../providers/ui_provider.dart'; 

import '../../features/auth/screens/sso_login_screen.dart';

import '../../features/super_admin/screens/super_admin_dashboard.dart';
import '../../features/super_admin/screens/agent_management_screen.dart';
import '../../features/super_admin/screens/financial_center_screen.dart';
import '../../features/super_admin/screens/subscriptions_screen.dart';
import '../../features/super_admin/screens/staff_support_screen.dart';
import '../../features/super_admin/screens/bank_accounts_screen.dart';
import '../../features/super_admin/screens/reports_screen.dart';
import '../../features/super_admin/screens/settings_screen.dart';
import '../../features/super_admin/screens/audit_log_screen.dart';
import '../../features/super_admin/screens/banners_screen.dart';
import '../../features/super_admin/screens/sms_gateway_screen.dart';
import '../../features/super_admin/screens/backup_screen.dart';
import '../../features/super_admin/screens/portals_management_screen.dart';

class CustomDrawer extends StatefulWidget {
  final String userName;
  final String phoneNumber;
  final String role;
  final String balanceOrPoints;
  final String? profileImageUrl; // تم الإبقاء عليه لعدم كسر الشاشات الأخرى

  const CustomDrawer({
    super.key,
    required this.userName,
    required this.phoneNumber,
    required this.role,
    required this.balanceOrPoints,
    this.profileImageUrl,
  });

  @override
  State<CustomDrawer> createState() => _CustomDrawerState();
}

class _CustomDrawerState extends State<CustomDrawer> {
  bool _isBalanceHidden = false;
  bool _isUploading = false; 

  void _navigateTo(BuildContext context, Widget screen) {
    Provider.of<UiProvider>(context, listen: false).playSound('click');
    Navigator.pop(context);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  void _showCandorSnackBar(BuildContext context, String message, {Color bgColor = Colors.orange, IconData icon = Icons.handyman}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Directionality(
          textDirection: TextDirection.rtl,
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(message, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
            ],
          ),
        ),
        backgroundColor: bgColor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // ========================================================
  // 🚀 المحرك الحقيقي لرفع الصورة كـ Base64
  // ========================================================
  Future<void> _pickAndUploadImage(BuildContext context) async {
    final uiProvider = Provider.of<UiProvider>(context, listen: false);
    uiProvider.playSound('click'); 

    final picker = ImagePicker();
    
    try {
      final XFile? pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 400, // ضغط الصورة 
        imageQuality: 40,
      );

      if (pickedFile == null) return; 

      setState(() => _isUploading = true);
      if (Navigator.canPop(context)) Navigator.pop(context); 
      
      _showCandorSnackBar(context, 'جاري حفظ الصورة... ⏳', bgColor: Colors.orange.shade700, icon: Icons.cloud_upload);

      final Uint8List bytes = await pickedFile.readAsBytes();
      String base64Image = base64Encode(bytes); // تشفير الصورة

      await FirebaseFirestore.instance.collection('users').doc(widget.phoneNumber).set({
        'profileImageBase64': base64Image,
      }, SetOptions(merge: true));

      setState(() => _isUploading = false);

      uiProvider.playSound('success'); 
      _showCandorSnackBar(context, 'تم تغيير الصورة الشخصية بنجاح! ✅', bgColor: Colors.green.shade700, icon: Icons.check_circle);

    } catch (e) {
      setState(() => _isUploading = false);
      uiProvider.playSound('error'); 
      _showCandorSnackBar(context, 'فشل تحديث الصورة: $e', bgColor: Colors.red.shade700, icon: Icons.error);
    }
  }

  Future<void> _deleteProfileImage(BuildContext context) async {
    final uiProvider = Provider.of<UiProvider>(context, listen: false);
    uiProvider.playSound('click');

    try {
      setState(() => _isUploading = true);
      if (Navigator.canPop(context)) Navigator.pop(context);

      await FirebaseFirestore.instance.collection('users').doc(widget.phoneNumber).update({
        'profileImageBase64': FieldValue.delete(),
      });

      setState(() => _isUploading = false);

      uiProvider.playSound('success'); 
      _showCandorSnackBar(context, 'تم حذف الصورة بنجاح.', bgColor: Colors.blueGrey, icon: Icons.delete);
    } catch (e) {
      setState(() => _isUploading = false);
      uiProvider.playSound('error'); 
    }
  }

  void _showProfileImageActionDialog(BuildContext context, String? currentBase64) {
    Provider.of<UiProvider>(context, listen: false).playSound('click'); 
    bool hasImage = currentBase64 != null && currentBase64.isNotEmpty;
    
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('إدارة الصورة الشخصية', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 130, height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle, color: Theme.of(context).primaryColor.withOpacity(0.1), border: Border.all(color: Colors.blue.shade100, width: 3),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
                  image: hasImage ? DecorationImage(image: MemoryImage(base64Decode(currentBase64)), fit: BoxFit.cover) : null,
                ),
                child: !hasImage ? const Icon(Icons.person, size: 80, color: Colors.blueGrey) : null,
              ),
              const SizedBox(height: 25),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _pickAndUploadImage(context), 
                    icon: Icon(hasImage ? Icons.sync : Icons.add_photo_alternate, color: Colors.white, size: 16),
                    label: Text(hasImage ? 'تغيير' : 'إضافة', style: const TextStyle(color: Colors.white, fontSize: 13)),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade600),
                  ),
                  if (hasImage) 
                    ElevatedButton.icon(
                      onPressed: () => _deleteProfileImage(context), 
                      icon: const Icon(Icons.delete_forever, color: Colors.white, size: 16),
                      label: const Text('حذف', style: TextStyle(color: Colors.white, fontSize: 13)),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade400),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context); 
    final uiProvider = Provider.of<UiProvider>(context, listen: false);

    return Drawer(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                physics: const BouncingScrollPhysics(),
                children: [
                  SafeArea(
                    bottom: false,
                    child: StreamBuilder<DocumentSnapshot>(
                      // 👈 قراءة حية للصورة الشخصية للمالك من السيرفر
                      stream: FirebaseFirestore.instance.collection('users').doc(widget.phoneNumber).snapshots(),
                      builder: (context, snapshot) {
                        String? base64Image;
                        if (snapshot.hasData && snapshot.data!.exists) {
                          final data = snapshot.data!.data() as Map<String, dynamic>?;
                          if (data != null && data.containsKey('profileImageBase64')) {
                            base64Image = data['profileImageBase64'];
                          }
                        }
                        bool hasImage = base64Image != null && base64Image.isNotEmpty;

                        return Container(
                          width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                          color: Colors.transparent,
                          child: Column(
                            children: [
                              GestureDetector(
                                onTap: () => _showProfileImageActionDialog(context, base64Image),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Container(
                                      width: 100, height: 100,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle, color: themeProvider.primaryColor.withOpacity(0.1),
                                        border: Border.all(color: themeProvider.primaryColor.withOpacity(0.3), width: 2),
                                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3))],
                                        image: hasImage ? DecorationImage(image: MemoryImage(base64Decode(base64Image!)), fit: BoxFit.cover) : null,
                                      ),
                                      child: !hasImage ? Icon(Icons.person, size: 60, color: themeProvider.primaryColor.withOpacity(0.7)) : null,
                                    ),
                                    if (_isUploading)
                                      Container(
                                        width: 100, height: 100,
                                        decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black.withOpacity(0.5)),
                                        child: const CircularProgressIndicator(color: Colors.white),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 15),
                              
                              _buildGradientCard(text: widget.userName, icon: Icons.badge, colors: [Colors.blue.shade800, Colors.blue.shade500]),
                              _buildGradientCard(text: widget.phoneNumber, icon: Icons.phone, colors: [Colors.teal.shade800, Colors.teal.shade500]),
                              _buildGradientCard(text: widget.role, icon: Icons.admin_panel_settings, colors: [Colors.orange.shade800, Colors.orange.shade500]),
                              
                              GestureDetector(
                                onTap: () {
                                  uiProvider.playSound('click'); 
                                  setState(() => _isBalanceHidden = !_isBalanceHidden);
                                },
                                child: _buildGradientCard(
                                  text: _isBalanceHidden ? '******' : widget.balanceOrPoints,
                                  icon: Icons.account_balance_wallet,
                                  colors: [Colors.purple.shade800, Colors.purple.shade500],
                                  trailingIcon: _isBalanceHidden ? Icons.visibility_off : Icons.visibility,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Divider(height: 1, color: themeProvider.adaptiveTextColor.withOpacity(0.2)),
                            ],
                          ),
                        );
                      }
                    ),
                  ),
                  
                  _buildDrawerItem(context, 'الرئيسية (غرفة العمليات)', Icons.dashboard, Colors.blue, const SuperAdminDashboard()),
                  _buildDrawerItem(context, 'إدارة الوكلاء', Icons.people_alt, Colors.purple, const AgentManagementScreen()),
                  _buildDrawerItem(context, 'إدارة الاشتراكات', Icons.event_available, Colors.teal, const SubscriptionsScreen()),
                  
                  Divider(color: themeProvider.adaptiveTextColor.withOpacity(0.2)),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), child: Text('المالية والمحاسبة', style: TextStyle(color: themeProvider.adaptiveTextColor.withOpacity(0.7), fontSize: 12, fontWeight: FontWeight.bold))),
                  
                  _buildDrawerItem(context, 'المركز المالي والمحافظ', Icons.account_balance_wallet, Colors.green, const FinancialCenterScreen()),
                  _buildDrawerItem(context, 'الحسابات البنكية', Icons.account_balance, Colors.indigo, const BankAccountsScreen()),
                  _buildDrawerItem(context, 'التقارير الشاملة', Icons.analytics, Colors.orange, const ReportsScreen()),
                  
                  Divider(color: themeProvider.adaptiveTextColor.withOpacity(0.2)),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), child: Text('الإدارة والتسويق', style: TextStyle(color: themeProvider.adaptiveTextColor.withOpacity(0.7), fontSize: 12, fontWeight: FontWeight.bold))),
                  
                  _buildDrawerItem(context, 'إدارة بوابات النظام', Icons.important_devices, Colors.deepPurple, const PortalsManagementScreen()),
                  _buildDrawerItem(context, 'إدارة الموظفين والدعم', Icons.support_agent, Colors.brown, const StaffSupportScreen()),
                  _buildDrawerItem(context, 'الإعلانات والبنرات', Icons.campaign, Colors.deepOrange, const BannersScreen()),
                  _buildDrawerItem(context, 'بوابة رسائل SMS', Icons.sms, Colors.blueAccent, const SmsGatewayScreen()),
                  
                  Divider(color: themeProvider.adaptiveTextColor.withOpacity(0.2)),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), child: Text('الأمان والنظام', style: TextStyle(color: themeProvider.adaptiveTextColor.withOpacity(0.7), fontSize: 12, fontWeight: FontWeight.bold))),
                  
                  _buildDrawerItem(context, 'السجل الأسود للنشاط', Icons.security, Colors.red, const AuditLogScreen()),
                  _buildDrawerItem(context, 'الإعدادات العامة', Icons.settings, Colors.blueGrey, const GlobalSettingsScreen()),
                  _buildDrawerItem(context, 'النسخ الاحتياطي', Icons.save, Colors.black87, const BackupScreen()),
                ],
              ),
            ),
            
            Divider(height: 1, color: themeProvider.adaptiveTextColor.withOpacity(0.2)),
            ListTile(
              dense: true,
              leading: const Icon(Icons.logout, color: Colors.red, size: 20),
              title: const Text('تسجيل الخروج', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              onTap: () {
                 uiProvider.playSound('click'); 
                 Navigator.pop(context);
                 Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const SSOLoginScreen()), (route) => false);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem(BuildContext context, String title, IconData icon, Color iconColor, Widget targetScreen) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    
    final boxColor = themeProvider.primaryColor.computeLuminance() > 0.45 
        ? Colors.black.withOpacity(0.05) 
        : Colors.white.withOpacity(0.9);

    return ListTile(
      dense: true, visualDensity: VisualDensity.compact,
      leading: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: boxColor, borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: iconColor, size: 18),
      ),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: themeProvider.adaptiveTextColor)),
      trailing: Icon(Icons.arrow_forward_ios, size: 11, color: themeProvider.adaptiveTextColor.withOpacity(0.5)),
      onTap: () => _navigateTo(context, targetScreen),
    );
  }

  Widget _buildGradientCard({required String text, required IconData icon, required List<Color> colors, IconData? trailingIcon}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8), 
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors, begin: Alignment.topRight, end: Alignment.bottomLeft),
        borderRadius: BorderRadius.circular(10), 
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))], 
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5), overflow: TextOverflow.ellipsis)),
          if (trailingIcon != null) Icon(trailingIcon, color: Colors.white70, size: 17),
        ],
      ),
    );
  }
}
