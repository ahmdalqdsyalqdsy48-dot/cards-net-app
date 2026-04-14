import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:url_launcher/url_launcher.dart'; // 👈 مكتبة فتح التطبيقات الخارجية

import '../../../core/providers/system_provider.dart';
import '../../../core/providers/ui_provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/widgets/custom_header.dart';
import '../widgets/custom_agent_drawer.dart';

class AgentSupportScreen extends StatefulWidget {
  const AgentSupportScreen({super.key});

  @override
  State<AgentSupportScreen> createState() => _AgentSupportScreenState();
}

class _AgentSupportScreenState extends State<AgentSupportScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  void _play(String type) => Provider.of<UiProvider>(context, listen: false).playSound(type);

  void _showSnack(String m, {bool isErr = false}) {
    if(!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(m, textDirection: TextDirection.rtl), backgroundColor: isErr ? Colors.red : Colors.green)
    );
  }

  // ==========================================
  // 1. فتح الروابط الخارجية (واتساب / اتصال) 🚀
  // ==========================================
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
  // 2. نافذة فتح تذكرة دعم جديدة (مربوطة بالسيرفر) 🎫
  // ==========================================
  void _showCreateTicketDialog(SystemProvider sys) {
    _play('click');
    String subject = '';
    String description = '';
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: Theme.of(context).cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            title: const Row(
              children: [
                Icon(Icons.support_agent, color: Colors.blueAccent),
                SizedBox(width: 8),
                Text('فتح تذكرة دعم جديدة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('اشرح مشكلتك بوضوح وسيقوم فريق الدعم بالرد عليك في أقرب وقت.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 15),
                  TextField(
                    onChanged: (val) => subject = val,
                    decoration: InputDecoration(
                      labelText: 'عنوان المشكلة (مختصر)',
                      prefixIcon: const Icon(Icons.title),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    onChanged: (val) => description = val,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: 'تفاصيل المشكلة',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              if (!isSubmitting)
                TextButton(onPressed: () { _play('click'); Navigator.pop(context); }, child: const Text('إلغاء', style: TextStyle(color: Colors.red))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                onPressed: isSubmitting ? null : () async {
                  if (subject.isNotEmpty && description.isNotEmpty) {
                    setStateDialog(() => isSubmitting = true);
                    try {
                      // 1. إنشاء التذكرة في السيرفر
                      await _db.collection('support_tickets').add({
                        'agentPhone': sys.currentUserPhone,
                        'agentName': sys.currentUserName,
                        'subject': subject,
                        'description': description,
                        'status': 'مفتوحة',
                        'priority': 'عادية',
                        'timestamp': FieldValue.serverTimestamp(),
                        'replies': [],
                      });

                      // 2. إرسال إشعار للإدارة بوجود تذكرة جديدة
                      await _db.collection('notifications').add({
                        'targetPhones': ['774578241', 'all_staff'], // إشعار للمالك أو الموظفين
                        'title': 'تذكرة دعم جديدة 🎫',
                        'body': 'من الوكيل: ${sys.currentUserName}\nالعنوان: $subject',
                        'timestamp': FieldValue.serverTimestamp(),
                        'isRead': false,
                        'readBy': [],
                      });

                      _play('success');
                      if (mounted) {
                        Navigator.pop(context);
                        _showSnack('تم إرسال تذكرتك بنجاح! سنتواصل معك قريباً.');
                      }
                    } catch (e) {
                      setStateDialog(() => isSubmitting = false);
                      _play('error');
                      _showSnack('حدث خطأ أثناء الإرسال!', isErr: true);
                    }
                  } else {
                    _play('error');
                    _showSnack('يرجى تعبئة جميع الحقول!', isErr: true);
                  }
                },
                child: isSubmitting 
                    ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('إرسال التذكرة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // 3. نافذة الدردشة المباشرة (مع فلترة الردود السرية) 💬
  // ==========================================
  void _showTicketChat(Map<String, dynamic> ticket, String docId, SystemProvider sys) {
    _play('click');
    final replyController = TextEditingController();
    final isClosed = ticket['status'] == 'مغلقة';

    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          title: Text('تذكرة ${docId.substring(0, 5).toUpperCase()}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // رسالة الوكيل الأساسية
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(color: Theme.of(context).brightness == Brightness.dark ? Colors.blue.shade900 : Colors.blue.shade50, borderRadius: BorderRadius.circular(10)),
                    child: Text('أنت: ${ticket['subject']}\n${ticket['description']}', style: TextStyle(color: Provider.of<ThemeProvider>(context).adaptiveTextColor, fontSize: 13)),
                  ),
                ),
                
                // عرض الردود المفلترة (بدون الردود الداخلية/السرية) 🔒
                if (ticket['replies'] != null)
                  ...List.generate((ticket['replies'] as List).length, (index) {
                    var reply = ticket['replies'][index];
                    bool isInternal = reply['isInternal'] ?? false;
                    
                    // 👈 الفلتر: تخطي الرد إذا كان سرياً للإدارة فقط!
                    if (isInternal) return const SizedBox.shrink();

                    bool isMe = reply['sender'] == 'agent'; // هل الرد من الوكيل أم الإدارة؟

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: isMe ? (Theme.of(context).brightness == Brightness.dark ? Colors.blue.shade900 : Colors.blue.shade50) : Colors.green.withOpacity(0.15), 
                          borderRadius: BorderRadius.circular(10), 
                        ),
                        child: Text('${isMe ? "أنت:" : "الدعم الفني:"}\n${reply['text']}', style: TextStyle(fontSize: 13, color: Provider.of<ThemeProvider>(context).adaptiveTextColor)),
                      ),
                    );
                  }),

                const Divider(),
                
                if (isClosed)
                  const Text('تم إغلاق هذه التذكرة من قبل الإدارة.', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
                else
                  TextField(
                    controller: replyController,
                    decoration: InputDecoration(
                      hintText: 'اكتب ردك هنا...',
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.send, color: Colors.blue), 
                        onPressed: () async {
                          if (replyController.text.isEmpty) return;
                          _play('click');
                          
                          // إضافة الرد لقاعدة البيانات
                          await _db.collection('support_tickets').doc(docId).update({
                            'replies': FieldValue.arrayUnion([{
                              'text': replyController.text, 
                              'isInternal': false, 
                              'sender': 'agent',
                              'timestamp': DateTime.now().toIso8601String()
                            }])
                          });
                          
                          // إشعار للإدارة بوجود رد جديد
                          await _db.collection('notifications').add({
                            'targetPhones': ['774578241', 'all_staff'],
                            'title': 'رد جديد على تذكرة 💬',
                            'body': 'الوكيل ${sys.currentUserName} قام بالرد على تذكرته.',
                            'timestamp': FieldValue.serverTimestamp(),
                            'isRead': false,
                            'readBy': [],
                          });

                          replyController.clear();
                          if (mounted) Navigator.pop(context); // إغلاق لإجبار التحديث أو يمكن تركه مفتوحاً مع StreamBuilder
                        }
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () { _play('click'); Navigator.pop(context); }, child: const Text('إغلاق الدردشة')),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sys = Provider.of<SystemProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final cardColor = Theme.of(context).cardColor;

    // استخراج أرقام وروابط الدعم الحقيقية
    final String whatsappLink = sys.socialLinks['whatsapp'] ?? '';
    // تنظيف رقم الهاتف للاتصال
    final String cleanPhone = sys.supportNumbers.replaceAll(RegExp(r'[^0-9+]'), '');

    return Scaffold(
      appBar: const CustomHeader(title: 'الدعم الفني الموحد'),
      drawer: CustomAgentDrawer(
        agentName: sys.currentUserName,
        phoneNumber: sys.currentUserPhone,
        role: 'وكيل معتمد',
        currentBalance: sys.currentUserBalance,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            // ==========================================
            // 1. بطاقات التواصل المباشر (دايناميكية) 📱
            // ==========================================
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 5)],
              ),
              child: Column(
                children: [
                  Text('نحن هنا لمساعدتك! تواصل معنا عبر:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: themeProvider.adaptiveTextColor)),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            // إذا كان الرابط لا يبدأ بـ http، نضيف له رابط واتساب الرسمي
                            String finalUrl = whatsappLink;
                            if (whatsappLink.isNotEmpty && !whatsappLink.startsWith('http')) {
                              finalUrl = 'https://wa.me/$whatsappLink';
                            }
                            _launchURL(finalUrl, 'رقم الواتساب غير مضاف من قبل الإدارة.');
                          },
                          icon: const Icon(Icons.chat, color: Colors.white),
                          label: const Text('واتساب', style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, padding: const EdgeInsets.symmetric(vertical: 12)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            _launchURL('tel:$cleanPhone', 'رقم الهاتف غير مضاف من قبل الإدارة.');
                          },
                          icon: const Icon(Icons.phone, color: Colors.white),
                          label: const Text('اتصال مباشر', style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, padding: const EdgeInsets.symmetric(vertical: 12)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),

            // ==========================================
            // 2. زر إضافة تذكرة جديدة
            // ==========================================
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _showCreateTicketDialog(sys),
                  icon: const Icon(Icons.add_circle_outline, color: Colors.blueAccent),
                  label: const Text('فتح تذكرة دعم جديدة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blueAccent)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    side: const BorderSide(color: Colors.blueAccent, width: 2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),
            
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text('سجل التذاكر الخاصة بك:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blueGrey)),
              ),
            ),
            
            // ==========================================
            // 3. قائمة التذاكر الحية من السيرفر 📡
            // ==========================================
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                // استدعاء التذاكر الخاصة بهذا الوكيل فقط!
                stream: _db.collection('support_tickets')
                    .where('agentPhone', isEqualTo: sys.currentUserPhone)
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('لا توجد تذاكر دعم حالياً.', style: TextStyle(color: Colors.grey)));

                  var tickets = snapshot.data!.docs;

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    physics: const BouncingScrollPhysics(),
                    itemCount: tickets.length,
                    itemBuilder: (context, index) {
                      var docId = tickets[index].id;
                      var ticket = tickets[index].data() as Map<String, dynamic>;
                      
                      final isClosed = ticket['status'] == 'مغلقة';
                      Color statusColor = isClosed ? Colors.grey : Colors.green;
                      if(ticket['status'] == 'قيد المعالجة') statusColor = Colors.orange;

                      String timeStr = 'الآن';
                      if(ticket['timestamp'] != null) {
                         timeStr = DateFormat('yyyy-MM-dd hh:mm a').format((ticket['timestamp'] as Timestamp).toDate());
                      }

                      return Card(
                        color: cardColor,
                        elevation: 2,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: isDark ? Colors.grey.shade800 : Colors.grey.shade300)),
                        child: InkWell(
                          onTap: () => _showTicketChat(ticket, docId, sys),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: statusColor.withOpacity(0.1),
                                      child: Icon(Icons.receipt_long, color: statusColor),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(ticket['subject'] ?? 'بدون عنوان', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: themeProvider.adaptiveTextColor)),
                                          const SizedBox(height: 4),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text('تذكرة: ${docId.substring(0, 5).toUpperCase()}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                              Text(timeStr, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                const Divider(height: 1),
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('اضغط هنا لفتح الدردشة المباشرة 💬', style: TextStyle(color: Colors.blueAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                                      child: Text(ticket['status'] ?? '', style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                )
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
