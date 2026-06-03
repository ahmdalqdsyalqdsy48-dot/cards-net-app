import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/providers/wallet_provider.dart';
import '../../../core/providers/ui_provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/widgets/custom_header.dart';
import '../widgets/custom_agent_drawer.dart';

class AgentSupportScreen extends StatefulWidget {
  const AgentSupportScreen({super.key});

  @override
  State<AgentSupportScreen> createState() => _AgentSupportScreenState();
}

class _AgentSupportScreenState extends State<AgentSupportScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        context.read<UiProvider>().playSound('click');
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showSnack(String m, {bool isErr = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(m, textDirection: TextDirection.rtl),
        backgroundColor: isErr ? Colors.red : Colors.green,
      ),
    );
  }

  Future<void> _launchURL(String urlString, String fallbackMsg) async {
    context.read<UiProvider>().playSound('click');
    if (urlString.isEmpty) {
      _showSnack(fallbackMsg, isErr: true);
      return;
    }

    final Uri url = Uri.parse(urlString);
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        _showSnack('لم نتمكن من فتح الرابط/التطبيق.', isErr: true);
      }
    } catch (e) {
      _showSnack('حدث خطأ أثناء الفتح.', isErr: true);
    }
  }

  void _showCreateTicketDialog() {
    context.read<UiProvider>().playSound('click');
    final auth = context.read<AuthProvider>();
    String subject = '';
    String description = '';
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: Theme.of(context).cardColor,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15)),
            title: const Row(
              children: [
                Icon(Icons.support_agent, color: Colors.blueAccent),
                SizedBox(width: 8),
                Text('فتح تذكرة للإدارة',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    onChanged: (val) => subject = val,
                    decoration: InputDecoration(
                        labelText: 'عنوان المشكلة',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10))),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    onChanged: (val) => description = val,
                    maxLines: 4,
                    decoration: InputDecoration(
                        labelText: 'تفاصيل المشكلة',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10))),
                  ),
                ],
              ),
            ),
            actions: [
              if (!isSubmitting)
                TextButton(
                    onPressed: () {
                      context.read<UiProvider>().playSound('click');
                      Navigator.pop(ctx);
                    },
                    child: const Text('إلغاء')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent),
                onPressed: isSubmitting
                    ? null
                    : () async {
                        if (subject.isNotEmpty && description.isNotEmpty) {
                          setStateDialog(() => isSubmitting = true);
                          try {
                            await _db.collection('support_tickets').add({
                              'agentPhone': auth.activeUserPhone,
                              'agentName': auth.currentUserName,
                              'subject': subject,
                              'description': description,
                              'status': 'مفتوحة',
                              'priority': 'عادية',
                              'role': 'agent',
                              'timestamp': FieldValue.serverTimestamp(),
                              'replies': [],
                            });

                            await _db
                                .collection('notifications')
                                .add({
                              'targetPhones': ['774578241', 'all_staff'],
                              'title': 'تذكرة وكيل جديدة 🎫',
                              'body':
                                  'من الوكيل: ${auth.currentUserName}\nالعنوان: $subject',
                              'timestamp': FieldValue.serverTimestamp(),
                              'isRead': false,
                              'readBy': [],
                            });

                            context.read<UiProvider>().playSound('success');
                            if (mounted) {
                              Navigator.pop(ctx);
                              _showSnack('تم إرسال تذكرتك للإدارة بنجاح!');
                            }
                          } catch (e) {
                            setStateDialog(() => isSubmitting = false);
                            context.read<UiProvider>().playSound('error');
                            _showSnack('حدث خطأ أثناء الإرسال!', isErr: true);
                          }
                        } else {
                          _showSnack('يرجى تعبئة جميع الحقول!', isErr: true);
                        }
                      },
                child: isSubmitting
                    ? const SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('إرسال التذكرة',
                        style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAdminTicketChat(
      Map<String, dynamic> ticket, String docId) {
    context.read<UiProvider>().playSound('click');
    final auth = context.read<AuthProvider>();
    final replyController = TextEditingController();
    final isClosed = ticket['status'] == 'مغلقة';

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          title: Text(
              'تذكرتي للإدارة - ${docId.substring(0, 5).toUpperCase()}',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 14)),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10)),
                    child: Text(
                        'أنت: ${ticket['subject']}\n${ticket['description']}',
                        style: TextStyle(
                            color: context
                                .read<ThemeProvider>()
                                .adaptiveTextColor,
                            fontSize: 13)),
                  ),
                ),
                if (ticket['replies'] != null)
                  ...List.generate((ticket['replies'] as List).length,
                      (index) {
                    var reply = ticket['replies'][index];
                    if (reply['isInternal'] ?? false)
                      return const SizedBox.shrink();

                    bool isMe = reply['sender'] == 'agent';

                    return Align(
                      alignment: isMe
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: isMe
                              ? Colors.blue.withOpacity(0.1)
                              : Colors.green.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                            '${isMe ? "أنت:" : "الدعم الفني:"}\n${reply['text']}',
                            style: TextStyle(
                                fontSize: 13,
                                color: context
                                    .read<ThemeProvider>()
                                    .adaptiveTextColor)),
                      ),
                    );
                  }),
                const Divider(),
                if (isClosed)
                  const Text('تم إغلاق هذه التذكرة من قبل الإدارة.',
                      style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold))
                else
                  TextField(
                    controller: replyController,
                    decoration: InputDecoration(
                      hintText: 'اكتب ردك للإدارة هنا...',
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.send, color: Colors.blue),
                        onPressed: () async {
                          if (replyController.text.isEmpty) return;
                          context.read<UiProvider>().playSound('click');
                          await _db
                              .collection('support_tickets')
                              .doc(docId)
                              .update({
                            'replies': FieldValue.arrayUnion([
                              {
                                'text': replyController.text,
                                'isInternal': false,
                                'sender': 'agent',
                                'timestamp':
                                    DateTime.now().toIso8601String()
                              }
                            ])
                          });
                          await _db
                              .collection('notifications')
                              .add({
                            'targetPhones': ['774578241', 'all_staff'],
                            'title': 'رد جديد من الوكيل 💬',
                            'body':
                                'الوكيل ${auth.currentUserName} قام بالرد على تذكرته.',
                            'timestamp': FieldValue.serverTimestamp(),
                            'isRead': false,
                            'readBy': [],
                          });
                          if (mounted) Navigator.pop(ctx);
                        },
                      ),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15)),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () {
                  context.read<UiProvider>().playSound('click');
                  Navigator.pop(ctx);
                },
                child: const Text('إغلاق الدردشة'))
          ],
        ),
      ),
    );
  }

  void _showCustomerTicketChat(
      Map<String, dynamic> ticket, String docId) {
    context.read<UiProvider>().playSound('click');
    final auth = context.read<AuthProvider>();
    final replyController = TextEditingController();
    final isClosed = ticket['status'] == 'مغلقة';
    final String customerName = ticket['creatorName'] ?? 'زبون';
    final String customerPhone = ticket['creatorPhone'] ?? '';

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          title: Text('شكوى من: $customerName',
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Colors.purple)),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                        color: Colors.purple.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10)),
                    child: Text(
                        'الزبون: ${ticket['subject']}\n${ticket['description']}',
                        style: TextStyle(
                            color: context
                                .read<ThemeProvider>()
                                .adaptiveTextColor,
                            fontSize: 13)),
                  ),
                ),
                if (ticket['replies'] != null)
                  ...List.generate((ticket['replies'] as List).length,
                      (index) {
                    var reply = ticket['replies'][index];
                    bool isMe = reply['sender'] == 'support';

                    return Align(
                      alignment: isMe
                          ? Alignment.centerLeft
                          : Alignment.centerRight,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: isMe
                              ? Colors.green.withOpacity(0.15)
                              : Colors.purple.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                            '${isMe ? "أنت (الدعم):" : "الزبون:"}\n${reply['text']}',
                            style: TextStyle(
                                fontSize: 13,
                                color: context
                                    .read<ThemeProvider>()
                                    .adaptiveTextColor)),
                      ),
                    );
                  }),
                const Divider(),
                if (isClosed)
                  const Text('لقد قمت بإغلاق هذه التذكرة.',
                      style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold))
                else
                  TextField(
                    controller: replyController,
                    decoration: InputDecoration(
                      hintText: 'اكتب ردك للزبون هنا...',
                      suffixIcon: IconButton(
                        icon:
                            const Icon(Icons.send, color: Colors.purple),
                        onPressed: () async {
                          if (replyController.text.isEmpty) return;
                          context.read<UiProvider>().playSound('click');

                          WriteBatch batch = _db.batch();
                          batch.update(
                              _db
                                  .collection('support_tickets')
                                  .doc(docId),
                              {
                                'status': 'قيد المعالجة',
                                'replies': FieldValue.arrayUnion([
                                  {
                                    'text': replyController.text,
                                    'isInternal': false,
                                    'sender': 'support',
                                    'timestamp': DateTime.now()
                                        .toIso8601String()
                                  }
                                ])
                              });

                          if (customerPhone.isNotEmpty) {
                            batch.set(
                                _db.collection('notifications').doc(),
                                {
                                  'targetPhones': [customerPhone],
                                  'title': 'رد من وكيل الشبكة 💬',
                                  'body':
                                      'قام وكيل الشبكة بالرد على شكواك.',
                                  'timestamp':
                                      FieldValue.serverTimestamp(),
                                  'isRead': false,
                                  'readBy': [],
                                });
                          }
                          await batch.commit();
                          if (mounted) Navigator.pop(ctx);
                        },
                      ),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15)),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            if (!isClosed)
              TextButton(
                onPressed: () async {
                  context.read<UiProvider>().playSound('click');
                  await _db
                      .collection('support_tickets')
                      .doc(docId)
                      .update({'status': 'مغلقة'});
                  if (mounted) Navigator.pop(ctx);
                  _showSnack('تم إغلاق تذكرة الزبون.');
                },
                child: const Text('إغلاق التذكرة نهائياً',
                    style: TextStyle(color: Colors.red)),
              ),
            TextButton(
                onPressed: () {
                  context.read<UiProvider>().playSound('click');
                  Navigator.pop(ctx);
                },
                child: const Text('رجوع')),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletProvider>();
    final auth = context.watch<AuthProvider>();
    final settings = context.watch<SettingsProvider>();

    final String whatsappLink = settings.socialLinks['whatsapp'] ?? '';
    final String supportNumbers = settings.supportNumbers;
    final String cleanPhone =
        supportNumbers.replaceAll(RegExp(r'[^0-9+]'), '');

    return Scaffold(
      appBar: const CustomHeader(title: 'مركز الدعم والمساعدة'),
      drawer: CustomAgentDrawer(
        agentName: wallet.currentUserName,
        phoneNumber: auth.activeUserPhone ?? '',
        role: 'وكيل معتمد',
        currentBalance: wallet.currentUserBalance,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            Container(
              color: Theme.of(context).cardColor,
              child: TabBar(
                controller: _tabController,
                labelColor: Colors.blueAccent,
                unselectedLabelColor: Colors.grey,
                indicatorColor: Colors.blueAccent,
                indicatorWeight: 3,
                tabs: const [
                  Tab(
                      icon: Icon(Icons.admin_panel_settings),
                      text: 'تذاكري مع الإدارة'),
                  Tab(icon: Icon(Icons.people), text: 'شكاوى زبائني'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildAdminSupportTab(whatsappLink, cleanPhone),
                  _buildCustomerSupportTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminSupportTab(
      String whatsappLink, String cleanPhone) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _launchURL(
                      whatsappLink.isNotEmpty &&
                              !whatsappLink.startsWith('http')
                          ? 'https://wa.me/$whatsappLink'
                          : whatsappLink,
                      'رقم الواتساب للإدارة غير مضاف.'),
                  icon: const Icon(Icons.chat,
                      color: Colors.white, size: 18),
                  label: const Text('واتساب',
                      style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _showCreateTicketDialog,
                  icon: const Icon(Icons.add,
                      color: Colors.white, size: 18),
                  label: const Text('تذكرة للإدارة',
                      style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _db
                .collection('support_tickets')
                .where('agentPhone',
                    isEqualTo: context.read<AuthProvider>().activeUserPhone)
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting)
                return const Center(child: CircularProgressIndicator());
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
                return const Center(
                    child: Text('لا توجد تذاكر مع الإدارة حالياً.',
                        style: TextStyle(color: Colors.grey)));

              var tickets = snapshot.data!.docs;
              return RefreshIndicator(
                onRefresh: () async {
                  await Future.delayed(
                      const Duration(milliseconds: 300));
                  context.read<UiProvider>().playSound('success');
                },
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: tickets.length,
                  itemBuilder: (context, index) {
                    var docId = tickets[index].id;
                    var ticket = tickets[index].data()
                        as Map<String, dynamic>;
                    bool isClosed = ticket['status'] == 'مغلقة';

                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      child: ListTile(
                        onTap: () =>
                            _showAdminTicketChat(ticket, docId),
                        leading: CircleAvatar(
                            backgroundColor: isClosed
                                ? Colors.grey.withOpacity(0.2)
                                : Colors.blue.withOpacity(0.2),
                            child: Icon(Icons.receipt,
                                color: isClosed
                                    ? Colors.grey
                                    : Colors.blue)),
                        title: Text(ticket['subject'] ?? 'بدون عنوان',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14)),
                        subtitle: Text(ticket['status'] ?? '',
                            style: TextStyle(
                                color: isClosed
                                    ? Colors.grey
                                    : Colors.orange,
                                fontSize: 12,
                                fontWeight: FontWeight.bold)),
                        trailing: const Icon(Icons.arrow_forward_ios,
                            size: 14, color: Colors.grey),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCustomerSupportTab() {
    final auth = context.read<AuthProvider>();
    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection('support_tickets')
          .where('targetAgentPhone', isEqualTo: auth.activeUserPhone)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
          return const Center(
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                Icon(Icons.sentiment_very_satisfied,
                    size: 50, color: Colors.grey),
                SizedBox(height: 10),
                Text('لا توجد شكاوى من زبائنك، عمل رائع!',
                    style: TextStyle(color: Colors.grey))
              ]));

        var tickets = snapshot.data!.docs;
        return RefreshIndicator(
          onRefresh: () async {
            await Future.delayed(const Duration(milliseconds: 300));
            context.read<UiProvider>().playSound('success');
          },
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: tickets.length,
            itemBuilder: (context, index) {
              var docId = tickets[index].id;
              var ticket =
                  tickets[index].data() as Map<String, dynamic>;
              bool isClosed = ticket['status'] == 'مغلقة';

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                        color: Colors.purple.withOpacity(0.2))),
                child: ListTile(
                  onTap: () =>
                      _showCustomerTicketChat(ticket, docId),
                  leading: CircleAvatar(
                      backgroundColor: isClosed
                          ? Colors.grey.withOpacity(0.2)
                          : Colors.purple.withOpacity(0.2),
                      child: Icon(Icons.person,
                          color: isClosed
                              ? Colors.grey
                              : Colors.purple)),
                  title: Text(ticket['creatorName'] ?? 'زبون',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Text(
                      '${ticket['subject']}\nالحالة: ${ticket['status']}',
                      style: TextStyle(
                          color: isClosed
                              ? Colors.grey
                              : Colors.orange,
                          fontSize: 12)),
                  isThreeLine: true,
                  trailing: ElevatedButton(
                    onPressed: () =>
                        _showCustomerTicketChat(ticket, docId),
                    style: ElevatedButton.styleFrom(
                        backgroundColor:
                            isClosed ? Colors.grey : Colors.purple,
                        padding:
                            const EdgeInsets.symmetric(horizontal: 10),
                        minimumSize: const Size(60, 30)),
                    child: const Text('رد',
                        style: TextStyle(
                            color: Colors.white, fontSize: 12)),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
