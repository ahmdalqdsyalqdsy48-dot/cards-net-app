import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart'; 

import '../../../core/providers/system_provider.dart';
import '../../../core/providers/ui_provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/widgets/custom_header.dart';
import '../widgets/custom_user_drawer.dart';

class UserSupportScreen extends StatefulWidget {
  const UserSupportScreen({super.key});

  @override
  State<UserSupportScreen> createState() => _UserSupportScreenState();
}

class _UserSupportScreenState extends State<UserSupportScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  void _play(String type) => Provider.of<UiProvider>(context, listen: false).playSound(type);

  void _showSnack(String m, {bool isErr = false}) {
    if(!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(m, textDirection: TextDirection.rtl), backgroundColor: isErr ? Colors.red : Colors.green)
    );
  }

  Future<void> _launchURL(String urlString, String fallbackMsg) async {
    _play('click');
    if (urlString.isEmpty) {
      _showSnack(fallbackMsg, isErr: true);
      return;
    }
    
    final Uri url = Uri.parse(urlString);
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        _showSnack('لم نتمكن من فتح الرابط/التطبيق. تأكد من تثبيته.', isErr: true);
      }
    } catch (e) {
      _showSnack('حدث خطأ أثناء محاولة الفتح.', isErr: true);
    }
  }

  // ==========================================
  // نافذة إرسال تذكرة دعم فني حقيقية (موجهة) 📝
  // ==========================================
  void _showTicketDialog(BuildContext context, SystemProvider sys) {
    _play('click');
    final TextEditingController subjectController = TextEditingController();
    final TextEditingController descController = TextEditingController();
    bool isSubmitting = false;
    
    // 👈 القيمة الافتراضية: توجيه التذكرة للإدارة
    String targetPhone = 'admin'; 

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => Directionality(
          textDirection: TextDirection.rtl, 
          child: AlertDialog(
            backgroundColor: Theme.of(context).cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.support_agent, color: Colors.purple),
                SizedBox(width: 10),
                Text('إرسال تذكرة دعم', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('لمن تود توجيه هذه التذكرة؟', style: TextStyle(fontSize: 13, color: Colors.blueGrey, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  
                  // 👈 القائمة المنسدلة لاختيار الوجهة (الإدارة أو وكيل محدد)
                  DropdownButtonFormField<String>(
                    value: targetPhone,
                    isExpanded: true,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade50,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                    ),
                    items: [
                      const DropdownMenuItem(value: 'admin', child: Text('الإدارة العامة (مشكلة بالتطبيق)')),
                      ...sys.agentsList.map((agent) {
                        return DropdownMenuItem(
                          value: agent['phone'],
                          child: Text('الوكيل: ${agent['name']} (${agent['networkName'] ?? 'بدون شبكة'})'),
                        );
                      }),
                    ],
                    onChanged: (val) {
                      setStateDialog(() {
                        targetPhone = val!;
                      });
                    },
                  ),
                  const SizedBox(height: 15),

                  TextField(
                    controller: subjectController,
                    decoration: InputDecoration(
                      hintText: 'عنوان المشكلة (مختصر)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      filled: true,
                      fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade50,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: descController,
                    maxLines: 4, 
                    decoration: InputDecoration(
                      hintText: 'اكتب تفاصيل المشكلة هنا...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      filled: true,
                      fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade50,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              if (!isSubmitting)
                TextButton(
                  onPressed: () { _play('click'); Navigator.pop(context); }, 
                  child: const Text('إلغاء', style: TextStyle(color: Colors.grey))
                ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                ),
                onPressed: isSubmitting ? null : () async {
                  if (subjectController.text.trim().isNotEmpty && descController.text.trim().isNotEmpty) {
                    _play('click');
                    setStateDialog(() => isSubmitting = true);
                    try {
                      // 1. إرسال التذكرة بالهيكلة الموجهة الجديدة
                      await _db.collection('support_tickets').add({
                        'creatorPhone': sys.currentUserPhone, 
                        'creatorName': sys.currentUserName,
                        'targetAgentPhone': targetPhone, // 👈 لمن التذكرة؟ 'admin' أو هاتف الوكيل
                        'subject': subjectController.text.trim(),
                        'description': descController.text.trim(),
                        'status': 'مفتوحة',
                        'priority': 'عادية',
                        'role': 'user', 
                        'timestamp': FieldValue.serverTimestamp(),
                        'replies': [],
                      });

                      // 2. إرسال الإشعار للجهة المعنية فقط!
                      List<String> notificationTargets = targetPhone == 'admin' 
                          ? ['774578241', 'all_staff'] 
                          : [targetPhone];

                      await _db.collection('notifications').add({
                        'targetPhones': notificationTargets,
                        'title': 'تذكرة جديدة من زبون 👤',
                        'body': 'الزبون: ${sys.currentUserName}\nالمشكلة: ${subjectController.text.trim()}',
                        'timestamp': FieldValue.serverTimestamp(),
                        'isRead': false,
                        'readBy': [],
                      });

                      _play('success');
                      if (mounted) {
                        Navigator.pop(context); 
                        _showSnack('تم إرسال تذكرتك بنجاح! ✅');
                      }
                    } catch (e) {
                      setStateDialog(() => isSubmitting = false);
                      _play('error');
                      _showSnack('حدث خطأ أثناء إرسال التذكرة!', isErr: true);
                    }
                  } else {
                    _play('error');
                    _showSnack('يرجى تعبئة العنوان والتفاصيل أولاً! ❌', isErr: true);
                  }
                },
                icon: isSubmitting ? const SizedBox.shrink() : const Icon(Icons.send, color: Colors.white, size: 18),
                label: isSubmitting 
                    ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('إرسال التذكرة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sys = Provider.of<SystemProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    final String whatsappLink = sys.socialLinks['whatsapp'] ?? '';
    final String cleanPhone = sys.supportNumbers.replaceAll(RegExp(r'[^0-9+]'), '');

    return Scaffold(
      appBar: const CustomHeader(title: 'الدعم الفني والشكاوى'),
      drawer: CustomUserDrawer(
        userName: sys.currentUserName,
        phoneNumber: sys.currentUserPhone,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SingleChildScrollView( 
          padding: const EdgeInsets.all(20),
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark ? Colors.blue.shade900.withOpacity(0.3) : Colors.blue.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.headset_mic, size: 80, color: Colors.blue.shade600),
                ),
              ),
              const SizedBox(height: 20),
              Text('كيف يمكننا مساعدتك اليوم؟ 🤝', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: themeProvider.adaptiveTextColor)),
              const SizedBox(height: 10),
              const Text('اختر الطريقة الأنسب للتواصل معنا، فريقنا متواجد على مدار الساعة لخدمتك وحل أي مشكلة تواجهك.', style: TextStyle(color: Colors.grey, height: 1.5)),
              const SizedBox(height: 40),
              
              _buildSupportOption(
                context, 
                Icons.chat, 
                'محادثة عبر واتساب', 
                'رد سريع خلال دقائق', 
                Colors.green,
                () {
                  String finalUrl = whatsappLink;
                  if (whatsappLink.isNotEmpty && !whatsappLink.startsWith('http')) {
                    finalUrl = 'https://wa.me/$whatsappLink';
                  }
                  _launchURL(finalUrl, 'رقم الواتساب غير متوفر حالياً.');
                }
              ),
              
              _buildSupportOption(
                context, 
                Icons.phone, 
                'اتصال هاتفي بالدعم', 
                'للحالات الطارئة والمستعجلة', 
                Colors.blue,
                () {
                  _launchURL('tel:$cleanPhone', 'رقم الهاتف غير متوفر حالياً.');
                }
              ),
              
              _buildSupportOption(
                context, 
                Icons.email, 
                'إرسال تذكرة دعم', 
                'للمشاكل التقنية والمالية', 
                Colors.purple,
                () {
                  _showTicketDialog(context, sys);
                }
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSupportOption(BuildContext context, IconData icon, String title, String subtitle, Color color, VoidCallback onTap) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    
    return Card(
      elevation: 2,
      color: Theme.of(context).cardColor,
      margin: const EdgeInsets.only(bottom: 15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: color.withOpacity(0.2), width: 1.5),
      ),
      child: InkWell( 
        onTap: onTap, 
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: themeProvider.adaptiveTextColor)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
