import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/providers/wallet_provider.dart';
import '../../../core/providers/ui_provider.dart';
import '../../../core/widgets/custom_drawer.dart';
import '../../../core/widgets/custom_header.dart';

class StaffSupportScreen extends StatefulWidget {
  const StaffSupportScreen({super.key});

  @override
  State<StaffSupportScreen> createState() => _StaffSupportScreenState();
}

class _StaffSupportScreenState extends State<StaffSupportScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

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

  // ==========================================
  // 1. نافذة إضافة موظف جديد
  // ==========================================
  void _showAddStaffDialog() {
    context.read<UiProvider>().playSound('click');
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final salaryController = TextEditingController();
    final passwordController = TextEditingController();

    Map<String, bool> permissions = {
      'الرئيسية (غرفة العمليات)': false,
      'إدارة الوكلاء الشاملة': false,
      'المركز المالي والمحافظ': false,
      'التقارير الشاملة': false,
      'إدارة الاشتراكات والباقات': false,
      'الحسابات البنكية': false,
      'إدارة الموظفين والدعم': false,
      'الإعلانات التسويقية': false,
      'بوابة رسائل الـ SMS': false,
      'السجل الأسود للنشاط (للقراءة)': false,
      'الإعدادات العامة': false,
      'النسخ الاحتياطي': false,
    };

    bool selectAll = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) {
          bool isLoading = false;

          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              backgroundColor: Theme.of(context).cardColor,
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              title: const Row(
                children: [
                  Icon(Icons.person_add_alt_1, color: Colors.blue),
                  SizedBox(width: 10),
                  Text('إضافة موظف جديد',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTextField(
                        'الاسم الرباعي', Icons.person, controller: nameController),
                    _buildTextField('رقم الهاتف', Icons.phone,
                        controller: phoneController, isNumber: true),
                    _buildTextField('كلمة المرور الافتراضية', Icons.lock,
                        controller: passwordController),
                    _buildTextField('الراتب الشهري (اختياري)',
                        Icons.monetization_on, controller: salaryController,
                        isNumber: true),
                    const Divider(),
                    const Text('الصلاحيات الممنوحة للموظف:',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blueGrey)),
                    CheckboxListTile(
                      title: const Text('تحديد كافة الصلاحيات ✅',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blueAccent)),
                      value: selectAll,
                      activeColor: Colors.blueAccent,
                      onChanged: (val) {
                        context.read<UiProvider>().playSound('click');
                        setStateDialog(() {
                          selectAll = val!;
                          permissions.updateAll((key, value) => selectAll);
                        });
                      },
                    ),
                    Container(
                      height: 200,
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: Colors.grey.withOpacity(0.3)),
                        borderRadius: BorderRadius.circular(10),
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.black12
                            : Colors.grey.shade50,
                      ),
                      child: ListView(
                        shrinkWrap: true,
                        children: permissions.keys.map((String key) {
                          return CheckboxListTile(
                            title:
                                Text(key, style: const TextStyle(fontSize: 13)),
                            value: permissions[key],
                            activeColor: Colors.green,
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 10),
                            dense: true,
                            onChanged: (val) {
                              context.read<UiProvider>().playSound('click');
                              setStateDialog(() {
                                permissions[key] = val!;
                                if (!val) selectAll = false;
                                if (permissions.values
                                    .every((element) => element == true)) {
                                  selectAll = true;
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                if (!isLoading)
                  TextButton(
                      onPressed: () {
                        context.read<UiProvider>().playSound('click');
                        Navigator.pop(ctx);
                      },
                      child: const Text('إلغاء')),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          if (nameController.text.isNotEmpty &&
                              phoneController.text.isNotEmpty &&
                              passwordController.text.isNotEmpty) {
                            context.read<UiProvider>().playSound('click');
                            setStateDialog(() => isLoading = true);

                            try {
                              await _db
                                  .collection('users')
                                  .doc(phoneController.text.trim())
                                  .set({
                                'id': 'STAFF_${DateTime.now().millisecondsSinceEpoch}',
                                'name': nameController.text.trim(),
                                'phone': phoneController.text.trim(),
                                'password': passwordController.text.trim(),
                                'role': 'staff',
                                'salary': salaryController.text.trim().isNotEmpty
                                    ? '${salaryController.text.trim()} ريال'
                                    : 'غير محدد',
                                'status': 'نشط',
                                'permissions': permissions,
                                'createdAt': FieldValue.serverTimestamp(),
                              });

                              context.read<UiProvider>().playSound('success');
                              if (mounted) {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        'تمت إضافة الموظف وصلاحياته بنجاح! ✅',
                                        textDirection: TextDirection.rtl),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            } catch (e) {
                              setStateDialog(() => isLoading = false);
                              context.read<UiProvider>().playSound('error');
                              if (mounted)
                                ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text('خطأ: $e'),
                                        backgroundColor: Colors.red));
                            }
                          } else {
                            context.read<UiProvider>().playSound('error');
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'يرجى إدخال اسم ورقم هاتف الموظف وكلمة المرور! ❌',
                                    textDirection: TextDirection.rtl),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                  child: isLoading
                      ? const SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('حفظ الموظف'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ==========================================
  // دوال التحكم بالموظفين
  // ==========================================
  void _toggleStaffStatus(Map<String, dynamic> emp) async {
    context.read<UiProvider>().playSound('click');
    try {
      String newStatus = emp['status'] == 'نشط' ? 'موقوف' : 'نشط';
      await _db
          .collection('users')
          .doc(emp['phone'])
          .update({'status': newStatus});
      context.read<UiProvider>().playSound('success');
    } catch (e) {
      context.read<UiProvider>().playSound('error');
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red));
    }
  }

  void _deleteStaff(Map<String, dynamic> emp) {
    context.read<UiProvider>().playSound('click');
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          title: const Text('حذف الموظف 🗑️', style: TextStyle(color: Colors.red)),
          content: const Text(
              'هل أنت متأكد من حذف هذا الموظف؟ سيتم إلغاء وصوله للنظام فوراً.'),
          actions: [
            TextButton(
                onPressed: () {
                  context.read<UiProvider>().playSound('click');
                  Navigator.pop(ctx);
                },
                child: const Text('تراجع')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                context.read<UiProvider>().playSound('click');
                try {
                  await _db.collection('users').doc(emp['phone']).delete();
                  context.read<UiProvider>().playSound('success');
                  if (mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('تم حذف الموظف بنجاح.',
                            textDirection: TextDirection.rtl),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                } catch (e) {
                  context.read<UiProvider>().playSound('error');
                  if (mounted)
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('خطأ: $e'), backgroundColor: Colors.red));
                }
              },
              child: const Text('تأكيد الحذف',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _paySalary(Map<String, dynamic> emp) {
    context.read<UiProvider>().playSound('click');
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          title: const Text('تسليم الراتب 💸',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
          content: Text(
              'هل تقر بتسليم الراتب للموظف "${emp['name']}"؟\n\n(سيقوم النظام آلياً بتسجيل المبلغ كـ "مصروفات تشغيلية" لخصمه من صافي أرباحك في التقارير الختامية).'),
          actions: [
            TextButton(
                onPressed: () {
                  context.read<UiProvider>().playSound('click');
                  Navigator.pop(ctx);
                },
                child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              onPressed: () async {
                context.read<UiProvider>().playSound('click');
                try {
                  String salaryStr = emp['salary']
                      .toString()
                      .replaceAll(RegExp(r'[^0-9]'), '');
                  double amount =
                      salaryStr.isEmpty ? 0 : double.parse(salaryStr);

                  if (amount <= 0) {
                    context.read<UiProvider>().playSound('error');
                    if (mounted)
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('لا يوجد راتب محدد لهذا الموظف.'),
                            backgroundColor: Colors.red),
                      );
                    Navigator.pop(ctx);
                    return;
                  }

                  WriteBatch batch = _db.batch();
                  batch.update(
                      _db.collection('system').doc('main_info'),
                      {'adminMainBalance': FieldValue.increment(-amount)});
                  batch.set(_db.collection('transactions').doc(), {
                    'agentPhone': emp['phone'],
                    'agentName': emp['name'],
                    'type': 'مصروفات تشغيلية (راتب موظف)',
                    'amount': -amount,
                    'timestamp': FieldValue.serverTimestamp(),
                  });
                  await batch.commit();

                  context.read<UiProvider>().playSound('success');
                  if (mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            'تم تسجيل الراتب كمصروفات تشغيلية بنجاح. ✅',
                            textDirection: TextDirection.rtl),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  context.read<UiProvider>().playSound('error');
                  if (mounted)
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('خطأ: $e'), backgroundColor: Colors.red));
                }
              },
              child: const Text('نعم، أقر بالتسليم',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // دوال التبويب الثاني (تذاكر الدعم الفني)
  // ==========================================
  void _showTicketChat(Map<String, dynamic> ticket, String docId) {
    context.read<UiProvider>().playSound('click');
    final replyController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          title: Text(
              'تذكرة ${docId.substring(0, 5).toUpperCase()} - ${ticket['agentName'] ?? ticket['agent'] ?? 'مجهول'}',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 16)),
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
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.blue.shade900
                            : Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(10)),
                    child: Text(
                        'الوكيل: ${ticket['subject']}\n${ticket['description'] ?? ''}',
                        style: const TextStyle(fontSize: 13)),
                  ),
                ),
                if (ticket['replies'] != null)
                  ...List.generate((ticket['replies'] as List).length, (index) {
                    var reply = ticket['replies'][index];
                    bool isInternal = reply['isInternal'] ?? false;
                    bool isAgent = reply['sender'] == 'agent';

                    return Align(
                      alignment: isInternal
                          ? Alignment.center
                          : (isAgent
                              ? Alignment.centerRight
                              : Alignment.centerLeft),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: isInternal
                              ? Colors.amber.shade100
                              : (isAgent
                                  ? (Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.blue.shade900
                                      : Colors.blue.shade50)
                                  : Colors.green.shade100),
                          borderRadius: BorderRadius.circular(10),
                          border: isInternal
                              ? Border.all(color: Colors.amber)
                              : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isInternal)
                              const Icon(Icons.lock,
                                  size: 14, color: Colors.orange),
                            if (isInternal) const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                  '${isInternal ? "ملاحظة سرية:" : (isAgent ? "الوكيل:" : "أنت:")}\n${reply['text']}',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: isInternal
                                          ? Colors.brown
                                          : Colors.black87)),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                const Divider(),
                TextField(
                  controller: replyController,
                  decoration: InputDecoration(
                    hintText: 'اكتب ردك للوكيل هنا...',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.send, color: Colors.blue),
                      onPressed: () async {
                        if (replyController.text.isEmpty) return;
                        context.read<UiProvider>().playSound('click');

                        WriteBatch batch = _db.batch();

                        DocumentReference ticketRef =
                            _db.collection('support_tickets').doc(docId);
                        batch.update(ticketRef, {
                          'status': 'قيد المعالجة',
                          'replies': FieldValue.arrayUnion([
                            {
                              'text': replyController.text,
                              'isInternal': false,
                              'sender': 'admin',
                              'timestamp':
                                  DateTime.now().toIso8601String()
                            }
                          ])
                        });

                        String agentPhone = ticket['agentPhone'] ?? '';
                        if (agentPhone.isNotEmpty) {
                          DocumentReference notifRef =
                              _db.collection('notifications').doc();
                          batch.set(notifRef, {
                            'targetPhones': [agentPhone],
                            'title': 'رد جديد من الدعم الفني 🎧',
                            'body':
                                'تم الرد على تذكرتك: ${docId.substring(0, 5).toUpperCase()}',
                            'timestamp': FieldValue.serverTimestamp(),
                            'isRead': false,
                            'readBy': [],
                          });
                        }

                        await batch.commit();

                        replyController.clear();
                        context.read<UiProvider>().playSound('success');
                        if (mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'تم إرسال الرد للوكيل بنجاح ✉️',
                                  textDirection: TextDirection.rtl),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
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
                _showInternalNoteDialog(docId);
              },
              child: const Text('➕ ملاحظة سرية',
                  style: TextStyle(
                      color: Colors.orange, fontWeight: FontWeight.bold)),
            ),
            TextButton(
                onPressed: () {
                  context.read<UiProvider>().playSound('click');
                  Navigator.pop(ctx);
                },
                child: const Text('إغلاق الدردشة')),
          ],
        ),
      ),
    );
  }

  void _showInternalNoteDialog(String docId) {
    context.read<UiProvider>().playSound('click');
    final noteController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor:
              Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey.shade900
                  : Colors.amber.shade50,
          title: const Text('ملاحظة داخلية سرية 🔒',
              style: TextStyle(
                  color: Colors.orange, fontWeight: FontWeight.bold)),
          content: TextField(
            controller: noteController,
            maxLines: 3,
            decoration: const InputDecoration(
                hintText:
                    'اكتب الملاحظة التي لن يراها الوكيل أبداً...'),
          ),
          actions: [
            TextButton(
                onPressed: () {
                  context.read<UiProvider>().playSound('click');
                  Navigator.pop(ctx);
                },
                child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange),
              onPressed: () async {
                if (noteController.text.isNotEmpty) {
                  context.read<UiProvider>().playSound('click');
                  await _db
                      .collection('support_tickets')
                      .doc(docId)
                      .update({
                    'replies': FieldValue.arrayUnion([
                      {
                        'text': noteController.text,
                        'isInternal': true,
                        'sender': 'admin',
                        'timestamp':
                            DateTime.now().toIso8601String()
                      }
                    ])
                  });
                  context.read<UiProvider>().playSound('success');
                  if (mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            'تم حفظ الملاحظة الداخلية.',
                            textDirection: TextDirection.rtl),
                      ),
                    );
                  }
                }
              },
              child: const Text('حفظ الملاحظة',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showAssignTicketDialog(String docId) {
    context.read<UiProvider>().playSound('click');

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15)),
          title: const Text('إحالة التذكرة ↪️',
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.purple)),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('اختر الموظف الذي تريد تحويل التذكرة إليه:',
                    style: TextStyle(fontSize: 13)),
                const SizedBox(height: 10),
                Expanded(
                  flex: 0,
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _db
                        .collection('users')
                        .where('role', isEqualTo: 'staff')
                        .where('status', isEqualTo: 'نشط')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState ==
                          ConnectionState.waiting)
                        return const Center(
                            child: CircularProgressIndicator());
                      if (!snapshot.hasData ||
                          snapshot.data!.docs.isEmpty)
                        return const Center(
                            child: Text(
                                'لا يوجد موظفين نشطين متاحين حالياً.',
                                style: TextStyle(color: Colors.red)));

                      var staffList = snapshot.data!.docs;

                      return ListView.separated(
                        shrinkWrap: true,
                        itemCount: staffList.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) {
                          var staff = staffList[index].data()
                              as Map<String, dynamic>;
                          return ListTile(
                            title: Text(staff['name'] ?? 'موظف مجهول',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14)),
                            subtitle: Text(
                                'هاتف: ${staff['phone']}',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey)),
                            leading: CircleAvatar(
                              backgroundColor:
                                  Colors.purple.withOpacity(0.1),
                              child: const Icon(Icons.support_agent,
                                  color: Colors.purple),
                            ),
                            onTap: () async {
                              context
                                  .read<UiProvider>()
                                  .playSound('click');
                              Navigator.pop(ctx);

                              try {
                                WriteBatch batch = _db.batch();

                                DocumentReference ticketRef = _db
                                    .collection('support_tickets')
                                    .doc(docId);
                                batch.update(ticketRef, {
                                  'status': 'قيد المعالجة',
                                  'assignedToPhone':
                                      staff['phone'],
                                  'assignedToName':
                                      staff['name'],
                                });

                                DocumentReference notifRef = _db
                                    .collection('notifications')
                                    .doc();
                                batch.set(notifRef, {
                                  'targetPhones': [
                                    staff['phone']
                                  ],
                                  'title':
                                      'تذكرة جديدة محالة إليك 📌',
                                  'body':
                                      'تم إحالة التذكرة رقم ${docId.substring(0, 5).toUpperCase()} إليك لمعالجتها.',
                                  'timestamp':
                                      FieldValue.serverTimestamp(),
                                  'isRead': false,
                                  'readBy': [],
                                });

                                await batch.commit();

                                context
                                    .read<UiProvider>()
                                    .playSound('success');
                                if (mounted) {
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(SnackBar(
                                    content: Text(
                                        'تم إحالة التذكرة إلى ${staff['name']} بنجاح ✅',
                                        textDirection:
                                            TextDirection.rtl),
                                    backgroundColor:
                                        Colors.green,
                                  ));
                                }
                              } catch (e) {
                                context
                                    .read<UiProvider>()
                                    .playSound('error');
                                if (mounted)
                                  ScaffoldMessenger.of(
                                          context)
                                      .showSnackBar(SnackBar(
                                          content: Text(
                                              'حدث خطأ أثناء الإحالة: $e'),
                                          backgroundColor:
                                              Colors.red));
                              }
                            },
                          );
                        },
                      );
                    },
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
                child: const Text('إلغاء')),
          ],
        ),
      ),
    );
  }

  void _closeTicket(String docId, String agentPhone) async {
    context.read<UiProvider>().playSound('click');
    try {
      WriteBatch batch = _db.batch();

      DocumentReference ticketRef =
          _db.collection('support_tickets').doc(docId);
      batch.update(ticketRef, {'status': 'مغلقة'});

      if (agentPhone.isNotEmpty) {
        DocumentReference notifRef =
            _db.collection('notifications').doc();
        batch.set(notifRef, {
          'targetPhones': [agentPhone],
          'title': 'تم إغلاق تذكرتك 🔴',
          'body':
              'تم حل وإغلاق التذكرة رقم ${docId.substring(0, 5).toUpperCase()}',
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
          'readBy': [],
        });
      }

      await batch.commit();

      context.read<UiProvider>().playSound('success');
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إغلاق التذكرة وأرشفتها بنجاح. ✅',
                textDirection: TextDirection.rtl),
            backgroundColor: Colors.blueGrey,
          ),
        );
    } catch (e) {
      context.read<UiProvider>().playSound('error');
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final settings = context.watch<SettingsProvider>();
    final wallet = context.watch<WalletProvider>();

    return Scaffold(
      appBar: const CustomHeader(title: 'إدارة الموظفين والدعم'),
      drawer: CustomDrawer(
        userName: wallet.currentUserName,
        phoneNumber: auth.activeUserPhone ?? '',
        role: 'مالك النظام (Super Admin)',
        balanceOrPoints:
            'أرباح النظام: ${settings.adminMainBalance.toStringAsFixed(0)} ريال',
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            Container(
              color: Colors.transparent,
              child: TabBar(
                controller: _tabController,
                labelColor: Colors.blueAccent,
                unselectedLabelColor: Colors.grey,
                indicatorColor: Colors.blueAccent,
                indicatorWeight: 3,
                labelStyle:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                tabs: const [
                  Tab(
                      icon: Icon(Icons.people_alt),
                      text: 'الموظفين والصلاحيات'),
                  Tab(
                      icon: Icon(Icons.support_agent),
                      text: 'تذاكر الدعم الفني'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildStaffTab(),
                  _buildTicketsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStaffTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            width: double.infinity,
            height: 45,
            child: ElevatedButton.icon(
              onPressed: _showAddStaffDialog,
              icon: const Icon(Icons.person_add, color: Colors.white),
              label: const Text('إضافة موظف جديد',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _db
                .collection('users')
                .where('role', isEqualTo: 'staff')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting)
                return const Center(child: CircularProgressIndicator());
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
                return const Center(
                    child: Text('لا يوجد موظفين حالياً.',
                        style: TextStyle(color: Colors.grey)));

              var staffList = snapshot.data!.docs;

              return RefreshIndicator(
                onRefresh: () async {
                  await Future.delayed(const Duration(milliseconds: 300));
                  context.read<UiProvider>().playSound('success');
                },
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: staffList.length,
                  itemBuilder: (context, index) {
                    var emp =
                        staffList[index].data() as Map<String, dynamic>;
                    final isActive = emp['status'] == 'نشط';

                    return Card(
                      color: Theme.of(context).cardColor,
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                        side: BorderSide(
                            color: isActive
                                ? Colors.transparent
                                : Colors.red.withOpacity(0.3),
                            width: 1.5),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Text('${emp['name']} (موظف مخصص)',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        decoration: isActive
                                            ? TextDecoration.none
                                            : TextDecoration
                                                .lineThrough)),
                                Chip(
                                    label: Text(
                                        emp['status'] ?? 'نشط',
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: Colors.white,
                                            fontWeight:
                                                FontWeight.bold)),
                                    backgroundColor: isActive
                                        ? Colors.green
                                        : Colors.red),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Text('هاتف: ${emp['phone']}',
                                    style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 13)),
                                Text('الراتب: ${emp['salary']}',
                                    style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 13)),
                              ],
                            ),
                            const Divider(),
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildIconButton(
                                    Icons.settings,
                                    'تعديل',
                                    Colors.blue,
                                    () {
                                      context
                                          .read<UiProvider>()
                                          .playSound('click');
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                              'نافذة التعديل ستتوفر قريباً ⚙️',
                                              textDirection:
                                                  TextDirection.rtl),
                                        ),
                                      );
                                    }),
                                _buildIconButton(
                                    isActive
                                        ? Icons.pause_circle
                                        : Icons.play_circle,
                                    isActive ? 'إيقاف' : 'تفعيل',
                                    isActive
                                        ? Colors.orange
                                        : Colors.green,
                                    () =>
                                        _toggleStaffStatus(emp)),
                                _buildIconButton(Icons.delete, 'حذف',
                                    Colors.red, () => _deleteStaff(emp)),
                                _buildIconButton(
                                    Icons.monetization_on,
                                    'تسليم الراتب',
                                    Colors.green,
                                    () => _paySalary(emp)),
                              ],
                            ),
                          ],
                        ),
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

  Widget _buildTicketsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection('support_tickets')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
          return const Center(
              child: Text('لا توجد تذاكر دعم حالياً.',
                  style: TextStyle(color: Colors.grey)));

        var tickets = snapshot.data!.docs;

        return RefreshIndicator(
          onRefresh: () async {
            await Future.delayed(const Duration(milliseconds: 300));
            context.read<UiProvider>().playSound('success');
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: tickets.length,
            itemBuilder: (context, index) {
              var docId = tickets[index].id;
              var ticket =
                  tickets[index].data() as Map<String, dynamic>;
              final isClosed = ticket['status'] == 'مغلقة';
              final String assignedTo =
                  ticket['assignedToName'] ?? 'غير محدد';

              return Card(
                elevation: isClosed ? 0 : 3,
                color: isClosed
                    ? Theme.of(context).cardColor.withOpacity(0.5)
                    : Theme.of(context).cardColor,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                    side: BorderSide(
                        color: isClosed
                            ? Colors.grey.shade300
                            : Colors.transparent)),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                              '${docId.substring(0, 5).toUpperCase()} | ${ticket['agentName'] ?? ticket['agentPhone'] ?? 'مجهول'}',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isClosed
                                      ? Colors.grey
                                      : null)),
                          Text(
                              ticket['priority'] ?? 'عادية',
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(ticket['subject'] ?? 'بدون عنوان',
                          style: TextStyle(
                              fontSize: 14,
                              color: isClosed
                                  ? Colors.grey
                                  : Colors.blueGrey)),
                      if (assignedTo != 'غير محدد')
                        Text('محالة إلى: $assignedTo',
                            style: const TextStyle(
                                fontSize: 11,
                                color: Colors.purple,
                                fontWeight: FontWeight.bold)),
                      const Divider(),
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceAround,
                        children: [
                          _buildIconButton(
                              Icons.chat,
                              'فتح التذكرة',
                              isClosed ? Colors.grey : Colors.blue,
                              () => _showTicketChat(ticket, docId)),
                          _buildIconButton(
                              Icons.lock,
                              'ملاحظة سرية',
                              isClosed ? Colors.grey : Colors.orange,
                              () =>
                                  _showInternalNoteDialog(docId)),
                          if (!isClosed)
                            _buildIconButton(
                                Icons.shortcut,
                                'إحالة إلى..',
                                Colors.purple,
                                () =>
                                    _showAssignTicketDialog(docId)),
                          if (!isClosed)
                            _buildIconButton(
                                Icons.check_circle,
                                'إغلاق',
                                Colors.green,
                                () => _closeTicket(
                                    docId,
                                    ticket['agentPhone'] ?? '')),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildTextField(String label, IconData icon,
      {TextEditingController? controller, bool isNumber = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.blueAccent),
          border:
              OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }

  Widget _buildIconButton(
      IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    color: color,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
