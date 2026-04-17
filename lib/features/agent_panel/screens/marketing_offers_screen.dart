import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart' as intl;
import 'package:share_plus/share_plus.dart';

import '../../../core/providers/system_provider.dart';
import '../../../core/providers/ui_provider.dart';
import '../../../core/widgets/custom_header.dart';
import '../widgets/custom_agent_drawer.dart';

class MarketingOffersScreen extends StatefulWidget {
  const MarketingOffersScreen({super.key});

  @override
  State<MarketingOffersScreen> createState() => _MarketingOffersScreenState();
}

class _MarketingOffersScreenState extends State<MarketingOffersScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  void _play(String type) => Provider.of<UiProvider>(context, listen: false).playSound(type);

  // ==========================================
  // 🎟️ نافذة إنشاء عرض / كوبون جديد (مكتملة ومربوطة)
  // ==========================================
  void _showCreateOfferDialog(SystemProvider sys) {
    _play('click');
    final formKey = GlobalKey<FormState>();
    
    String newCode = '';
    String discountType = 'percent'; // percent, fixed, combo
    double discountValue = 0.0;
    String comboDesc = '';
    int maxUsage = 50;
    String targetPhone = '';
    
    DateTime expiryDate = DateTime.now().add(const Duration(days: 7));
    bool isHappyHour = false;
    TimeOfDay startTime = const TimeOfDay(hour: 2, minute: 0);
    TimeOfDay endTime = const TimeOfDay(hour: 8, minute: 0);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                title: const Row(
                  children: [
                    Icon(Icons.campaign, color: Colors.blueAccent),
                    SizedBox(width: 10),
                    Text('إنشاء عرض تسويقي جديد', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ],
                ),
                content: SizedBox(
                  width: double.maxFinite,
                  child: SingleChildScrollView(
                    child: Form(
                      key: formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 1. كود الكوبون
                          TextFormField(
                            decoration: InputDecoration(labelText: 'كود الكوبون (مثال: VIP26)', prefixIcon: const Icon(Icons.local_offer, color: Colors.blueAccent), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                            textCapitalization: TextCapitalization.characters,
                            validator: (val) {
                              if (val == null || val.isEmpty) return 'يرجى إدخال الكود';
                              if (val.contains(' ')) return 'يجب ألا يحتوي على مسافات';
                              return null;
                            },
                            onSaved: (val) => newCode = val!.toUpperCase().trim(),
                          ),
                          const SizedBox(height: 12),

                          // 2. نوع الخصم
                          DropdownButtonFormField<String>(
                            value: discountType,
                            decoration: InputDecoration(labelText: 'نوع الخصم', prefixIcon: const Icon(Icons.discount, color: Colors.green), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                            items: const [
                              DropdownMenuItem(value: 'percent', child: Text('نسبة مئوية (%)')),
                              DropdownMenuItem(value: 'fixed', child: Text('مبلغ مالي ثابت (ريال)')),
                              DropdownMenuItem(value: 'combo', child: Text('عرض باقة (اشتر X واحصل على Y)')),
                            ],
                            onChanged: (val) => setStateDialog(() => discountType = val!),
                          ),
                          const SizedBox(height: 12),

                          // 3. قيمة الخصم أو تفاصيل الباقة
                          if (discountType == 'combo')
                            TextFormField(
                              decoration: InputDecoration(labelText: 'تفاصيل الباقة (مثال: اشتر 10 واحصل على 1 مجاناً)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                              validator: (val) => val!.isEmpty ? 'يرجى كتابة التفاصيل' : null,
                              onSaved: (val) => comboDesc = val!,
                            )
                          else
                            TextFormField(
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(labelText: discountType == 'percent' ? 'النسبة (مثال: 15)' : 'المبلغ (مثال: 1000)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                              validator: (val) => val!.isEmpty ? 'يرجى إدخال القيمة' : null,
                              onSaved: (val) => discountValue = double.tryParse(val!) ?? 0.0,
                            ),
                          const SizedBox(height: 12),

                          // 4. الفئة المستهدفة
                          TextFormField(
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(labelText: 'رقم هاتف بقالة محددة (اختياري - اتركه فارغاً للجميع)', prefixIcon: const Icon(Icons.phone, color: Colors.orange), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                            onSaved: (val) => targetPhone = val?.trim() ?? '',
                          ),
                          const SizedBox(height: 12),

                          // 5. الحد الأقصى للاستخدام
                          TextFormField(
                            initialValue: '50',
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(labelText: 'الحد الأقصى لعدد الاستخدامات', prefixIcon: const Icon(Icons.people, color: Colors.teal), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                            onSaved: (val) => maxUsage = int.tryParse(val!) ?? 50,
                          ),
                          const Divider(height: 25),

                          // 6. تاريخ الانتهاء
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.calendar_month, color: Colors.redAccent),
                            title: const Text('تاريخ انتهاء العرض', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            subtitle: Text(intl.DateFormat('yyyy-MM-dd').format(expiryDate)),
                            trailing: ElevatedButton(
                              onPressed: () async {
                                DateTime? picked = await showDatePicker(context: context, initialDate: expiryDate, firstDate: DateTime.now(), lastDate: DateTime(2030));
                                if (picked != null) setStateDialog(() => expiryDate = picked);
                              },
                              child: const Text('تغيير'),
                            ),
                          ),
                          const Divider(height: 10),

                          // 7. الساعات السعيدة (Happy Hour)
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('تفعيل الساعات السعيدة ⏳', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            subtitle: const Text('يعمل الكوبون فقط في أوقات الركود', style: TextStyle(fontSize: 11)),
                            value: isHappyHour,
                            onChanged: (val) => setStateDialog(() => isHappyHour = val),
                          ),
                          if (isHappyHour)
                            Row(
                              children: [
                                Expanded(child: OutlinedButton(onPressed: () async { TimeOfDay? t = await showTimePicker(context: context, initialTime: startTime); if (t != null) setStateDialog(() => startTime = t); }, child: Text('من: ${startTime.format(context)}'))),
                                const SizedBox(width: 10),
                                Expanded(child: OutlinedButton(onPressed: () async { TimeOfDay? t = await showTimePicker(context: context, initialTime: endTime); if (t != null) setStateDialog(() => endTime = t); }, child: Text('إلى: ${endTime.format(context)}'))),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                actions: [
                  TextButton(onPressed: () { _play('click'); Navigator.pop(context); }, child: const Text('إلغاء', style: TextStyle(color: Colors.red))),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                    onPressed: () async {
                      if (formKey.currentState!.validate()) {
                        formKey.currentState!.save();
                        
                        // حفظ في الفايربيز
                        _play('click');
                        showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator()));
                        
                        try {
                          // التحقق من عدم وجود كود مكرر للوكيل نفسه
                          var check = await _db.collection('offers').where('agentPhone', isEqualTo: sys.currentUserPhone).where('code', isEqualTo: newCode).get();
                          if (check.docs.isNotEmpty) {
                            Navigator.pop(context); // إغلاق التحميل
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('عفواً، هذا الكود موجود مسبقاً لديك!'), backgroundColor: Colors.red));
                            return;
                          }

                          await _db.collection('offers').add({
                            'agentPhone': sys.currentUserPhone,
                            'code': newCode,
                            'discountType': discountType,
                            'discountValue': discountValue,
                            'comboDesc': comboDesc,
                            'maxUsage': maxUsage,
                            'currentUsage': 0,
                            'expiryDate': Timestamp.fromDate(expiryDate),
                            'isHappyHour': isHappyHour,
                            'startTime': '${startTime.hour}:${startTime.minute}',
                            'endTime': '${endTime.hour}:${endTime.minute}',
                            'targetPhone': targetPhone,
                            'isActive': true,
                            'createdAt': FieldValue.serverTimestamp(),
                          });

                          Navigator.pop(context); // إغلاق التحميل
                          Navigator.pop(context); // إغلاق النافذة
                          _play('success');
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إطلاق الحملة التسويقية بنجاح! 🚀'), backgroundColor: Colors.green));
                        } catch (e) {
                          Navigator.pop(context);
                          _play('error');
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red));
                        }
                      }
                    },
                    child: const Text('إطلاق العرض', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          }
        );
      },
    );
  }

  // ==========================================
  // 📲 وظائف المشاركة والإشعارات والحذف
  // ==========================================
  void _shareOffer(Map<String, dynamic> offer) {
    _play('click');
    String msg = "🎉 *عـرض خـاص وحـصـري!* 🎉\n\n";
    
    if (offer['discountType'] == 'percent') {
      msg += "استخدم الكود: *${offer['code']}*\nواحصل على خصم *${offer['discountValue']}%* على مشترياتك!\n";
    } else if (offer['discountType'] == 'fixed') {
      msg += "استخدم الكود: *${offer['code']}*\nواحصل على خصم *${offer['discountValue']} ريال*!\n";
    } else {
      msg += "استخدم الكود: *${offer['code']}*\nواستفد من العرض: *${offer['comboDesc']}*\n";
    }

    if (offer['isHappyHour'] == true) {
      msg += "⏳ *ملاحظة:* العرض يعمل فقط خلال الساعات السعيدة.\n";
    }

    String exp = intl.DateFormat('yyyy-MM-dd').format((offer['expiryDate'] as Timestamp).toDate());
    msg += "\n⚠️ العرض ساري حتى: $exp\nأو حتى نفاذ الكمية.\n\nسارع الآن وقم بزيادة أرباحك! 🚀";

    Share.share(msg);
  }

  Future<void> _deleteOffer(String docId) async {
    _play('warning');
    bool confirm = await showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تأكيد الحذف'),
          content: const Text('هل أنت متأكد من رغبتك في إيقاف وحذف هذا العرض نهائياً؟'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(context, true), 
              child: const Text('حذف', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    ) ?? false;

    if (confirm) {
      await _db.collection('offers').doc(docId).delete();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حذف العرض بنجاح.'), backgroundColor: Colors.green));
    }
  }

  Future<void> _broadcastNotification(Map<String, dynamic> offer, SystemProvider sys) async {
    _play('click');
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('جاري إرسال إشعار للبقالات... 🔔'), backgroundColor: Colors.teal));
    
    // محاكاة إرسال إشعار عبر حفظه في قاعدة البيانات ليظهر للبقالات التابعة للوكيل
    await _db.collection('notifications').add({
      'agentPhone': sys.currentUserPhone,
      'title': 'عرض حصري جديد! 🎉',
      'body': 'تم إطلاق كود الخصم ${offer['code']}. افتح التطبيق للتفاصيل!',
      'createdAt': FieldValue.serverTimestamp(),
    });
    
    await Future.delayed(const Duration(seconds: 1));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم بث الإشعار لجميع زبائنك بنجاح! ✅'), backgroundColor: Colors.green));
  }

  // ==========================================
  // واجهة المستخدم الأساسية (UI)
  // ==========================================
  @override
  Widget build(BuildContext context) {
    final sys = Provider.of<SystemProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: const CustomHeader(title: 'التسويق والعروض'),
      drawer: CustomAgentDrawer(
        agentName: sys.currentUserName,
        phoneNumber: sys.currentUserPhone,
        role: 'وكيل معتمد (Agent)',
        currentBalance: sys.currentUserBalance,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            // 1. البانر الترحيبي وزر الإضافة والإحصائيات
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade900 : Colors.blue.shade900,
                borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('ضاعف مبيعاتك! 🚀', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 5),
                  const Text('قم بإنشاء كوبونات وعروض خاصة لزبائنك لزيادة الولاء وتحفيز السحب المستمر.', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 15),
                  
                  // الإحصائيات الحية
                  StreamBuilder<QuerySnapshot>(
                    stream: _db.collection('offers').where('agentPhone', isEqualTo: sys.currentUserPhone).snapshots(),
                    builder: (context, snapshot) {
                      int activeCount = 0;
                      int totalUses = 0;
                      if (snapshot.hasData) {
                        for (var doc in snapshot.data!.docs) {
                          var data = doc.data() as Map<String, dynamic>;
                          totalUses += (data['currentUsage'] as int? ?? 0);
                          DateTime exp = (data['expiryDate'] as Timestamp).toDate();
                          if (data['isActive'] == true && exp.isAfter(DateTime.now()) && (data['currentUsage'] < data['maxUsage'])) {
                            activeCount++;
                          }
                        }
                      }
                      return Row(
                        children: [
                          Expanded(child: _buildStatBox('العروض النشطة', '$activeCount', Colors.green)),
                          const SizedBox(width: 10),
                          Expanded(child: _buildStatBox('إجمالي الاستخدام', '$totalUses', Colors.orange)),
                        ],
                      );
                    }
                  ),
                  const SizedBox(height: 15),

                  SizedBox(
                    width: double.infinity,
                    height: 45,
                    child: ElevatedButton.icon(
                      onPressed: () => _showCreateOfferDialog(sys),
                      icon: const Icon(Icons.add_shopping_cart, color: Colors.blue),
                      label: const Text('إنشاء عرض جديد الآن', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 16)),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 10),
            
            // 2. عنوان القائمة
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text('حملاتك التسويقية الحالية:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blueGrey)),
              ),
            ),

            // 3. جلب وعرض الكوبونات من الفايربيز
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _db.collection('offers').where('agentPhone', isEqualTo: sys.currentUserPhone).orderBy('createdAt', descending: true).snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) return Center(child: Text('خطأ: ${snapshot.error}'));
                  if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text('لا توجد عروض حالياً. ابدأ بإنشاء عرضك الأول!', style: TextStyle(color: Colors.grey)));
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      var doc = snapshot.data!.docs[index];
                      var offer = doc.data() as Map<String, dynamic>;
                      
                      // الحساب الذكي لحالة الكوبون
                      DateTime expiry = (offer['expiryDate'] as Timestamp).toDate();
                      int current = offer['currentUsage'] ?? 0;
                      int max = offer['maxUsage'] ?? 1;
                      
                      String statusText = 'نشط 🟢';
                      Color statusColor = Colors.green;

                      if (offer['isActive'] == false) {
                        statusText = 'متوقف ⚪'; statusColor = Colors.grey;
                      } else if (current >= max) {
                        statusText = 'مستنفد 🔴'; statusColor = Colors.red;
                      } else if (expiry.isBefore(DateTime.now())) {
                        statusText = 'منتهي 🔴'; statusColor = Colors.red;
                      } else if (expiry.difference(DateTime.now()).inDays <= 2) {
                        statusText = 'ينتهي قريباً 🟠'; statusColor = Colors.orange;
                      }

                      // توليد نص الخصم
                      String discountStr = '';
                      if (offer['discountType'] == 'percent') discountStr = 'خصم ${offer['discountValue']}%';
                      else if (offer['discountType'] == 'fixed') discountStr = 'خصم ${offer['discountValue']} ريال';
                      else discountStr = offer['comboDesc'];

                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.only(bottom: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                          side: BorderSide(color: statusColor.withOpacity(0.5), width: 1.5),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(15.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: statusColor.withOpacity(0.5))),
                                    child: Text(offer['code'], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: statusColor, letterSpacing: 2)),
                                  ),
                                  Text(statusText, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: statusColor)),
                                ],
                              ),
                              if (offer['targetPhone'] != '')
                                Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text('🎯 مخصص للرقم: ${offer['targetPhone']}', style: const TextStyle(color: Colors.blue, fontSize: 11, fontWeight: FontWeight.bold)),
                                ),
                              const Divider(height: 25),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(discountStr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                      const SizedBox(height: 4),
                                      Text('الاستخدام: $current / $max | الانتهاء: ${intl.DateFormat('yyyy-MM-dd').format(expiry)}', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                                      if (offer['isHappyHour'] == true)
                                        Text('⏳ يعمل فقط من ${offer['startTime']} إلى ${offer['endTime']}', style: const TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              // أزرار التحكم
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  IconButton(onPressed: () => _shareOffer(offer), icon: const Icon(Icons.share, color: Colors.blue), tooltip: 'مشاركة واتساب', style: IconButton.styleFrom(backgroundColor: Colors.blue.withOpacity(0.1))),
                                  IconButton(onPressed: () => _broadcastNotification(offer, sys), icon: const Icon(Icons.notifications_active, color: Colors.orange), tooltip: 'بث إشعار للزبائن', style: IconButton.styleFrom(backgroundColor: Colors.orange.withOpacity(0.1))),
                                  IconButton(onPressed: () => _deleteOffer(doc.id), icon: const Icon(Icons.delete_outline, color: Colors.red), tooltip: 'حذف العرض', style: IconButton.styleFrom(backgroundColor: Colors.red.withOpacity(0.1))),
                                ],
                              )
                            ],
                          ),
                        ),
                      );
                    },
                  );
                }
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatBox(String title, String val, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white24)),
      child: Column(
        children: [
          Text(title, style: const TextStyle(color: Colors.white70, fontSize: 11)),
          Text(val, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18)),
        ],
      ),
    );
  }
}
