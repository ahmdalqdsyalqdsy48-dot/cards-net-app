import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart' as intl;
import 'package:share_plus/share_plus.dart';

import '../../../core/providers/system_provider.dart';
import '../../../core/providers/ui_provider.dart';
import '../../../core/providers/theme_provider.dart';
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
  void _showCreateOfferDialog(SystemProvider sys, ThemeProvider theme) {
    _play('click');
    final formKey = GlobalKey<FormState>();
    
    String newCode = '';
    String discountType = 'percent'; // percent, fixed, combo, referral
    double discountValue = 0.0;
    String comboDesc = '';
    double referrerReward = 0.0;
    double refereeReward = 0.0;
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
                title: Row(
                  children: [
                    Icon(Icons.campaign, color: theme.primaryColor == Colors.white ? Colors.blue : theme.primaryColor),
                    const SizedBox(width: 10),
                    const Text('إنشاء عرض تسويقي جديد', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
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
                            decoration: InputDecoration(labelText: 'كود الكوبون (مثال: VIP26)', prefixIcon: Icon(Icons.local_offer, color: theme.primaryColor == Colors.white ? Colors.blue : theme.primaryColor), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                            textCapitalization: TextCapitalization.characters,
                            validator: (val) {
                              if (val == null || val.isEmpty) return 'يرجى إدخال الكود';
                              if (val.contains(' ')) return 'يجب ألا يحتوي على مسافات';
                              return null;
                            },
                            onSaved: (val) => newCode = val!.toUpperCase().trim(),
                          ),
                          const SizedBox(height: 12),

                          // 2. نوع الخصم المطور (تم إضافة الإحالة)
                          DropdownButtonFormField<String>(
                            value: discountType,
                            decoration: InputDecoration(labelText: 'نوع الخصم', prefixIcon: const Icon(Icons.discount, color: Colors.green), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                            items: const [
                              DropdownMenuItem(value: 'percent', child: Text('نسبة مئوية (%)')),
                              DropdownMenuItem(value: 'fixed', child: Text('مبلغ مالي ثابت (ريال)')),
                              DropdownMenuItem(value: 'combo', child: Text('عرض باقة (اشتر X واحصل على Y)')),
                              DropdownMenuItem(value: 'referral', child: Text('كوبون إحالة (دعوة بقالة جديدة)')),
                            ],
                            onChanged: (val) => setStateDialog(() => discountType = val!),
                          ),
                          const SizedBox(height: 12),

                          // 3. المدخلات الديناميكية بناءً على نوع الخصم
                          if (discountType == 'combo')
                            TextFormField(
                              decoration: InputDecoration(labelText: 'تفاصيل الباقة (مثال: اشتر 10 واحصل على 1 مجاناً)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                              validator: (val) => val!.isEmpty ? 'يرجى كتابة التفاصيل' : null,
                              onSaved: (val) => comboDesc = val!,
                            )
                          else if (discountType == 'referral')
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(labelText: 'مكافأة الداعي (ريال)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                                    validator: (val) => val!.isEmpty ? 'مطلوب' : null,
                                    onSaved: (val) => referrerReward = double.tryParse(val!) ?? 0.0,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextFormField(
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(labelText: 'مكافأة المدعو (ريال)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                                    validator: (val) => val!.isEmpty ? 'مطلوب' : null,
                                    onSaved: (val) => refereeReward = double.tryParse(val!) ?? 0.0,
                                  ),
                                ),
                              ],
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
                          if (discountType != 'referral')
                            TextFormField(
                              keyboardType: TextInputType.phone,
                              decoration: InputDecoration(labelText: 'رقم هاتف بقالة محددة (اختياري)', prefixIcon: const Icon(Icons.phone, color: Colors.orange), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                              onSaved: (val) => targetPhone = val?.trim() ?? '',
                            ),
                          if (discountType != 'referral') const SizedBox(height: 12),

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
                            onChanged: discountType == 'referral' ? null : (val) => setStateDialog(() => isHappyHour = val),
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
                    style: ElevatedButton.styleFrom(backgroundColor: theme.primaryColor == Colors.white ? Colors.blueAccent : theme.primaryColor),
                    onPressed: () async {
                      if (formKey.currentState!.validate()) {
                        formKey.currentState!.save();
                        
                        _play('click');
                        showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator()));
                        
                        try {
                          // التأكد من عدم تكرار الكود (تم التغيير إلى coupons ليتوافق مع SystemProvider)
                          var check = await _db.collection('coupons').where('agentPhone', isEqualTo: sys.currentUserPhone).where('code', isEqualTo: newCode).get();
                          if (check.docs.isNotEmpty) {
                            Navigator.pop(context); 
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('عفواً، هذا الكود موجود مسبقاً لديك!'), backgroundColor: Colors.red));
                            return;
                          }

                          await _db.collection('coupons').add({
                            'agentPhone': sys.currentUserPhone,
                            'code': newCode,
                            'discountType': discountType,
                            'discountValue': discountValue,
                            'comboDesc': comboDesc,
                            'referrerReward': referrerReward,
                            'refereeReward': refereeReward,
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

                          Navigator.pop(context); 
                          Navigator.pop(context); 
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
  // 📲 وظائف المشاركة المتقدمة (نص + صورة بوستر)
  // ==========================================
  void _showSharePosterDialog(Map<String, dynamic> offer, ThemeProvider theme) {
    _play('click');
    final GlobalKey posterKey = GlobalKey();

    String discountTitle = '';
    String subTitle = '';
    
    if (offer['discountType'] == 'percent') {
      discountTitle = 'خصم ${offer['discountValue']}%';
      subTitle = 'على مشترياتك من الكروت';
    } else if (offer['discountType'] == 'fixed') {
      discountTitle = 'خصم ${offer['discountValue']} ريال';
      subTitle = 'مباشرة على فاتورتك';
    } else if (offer['discountType'] == 'referral') {
      discountTitle = 'عرض دعوة الأصدقاء';
      subTitle = 'سجل وستحصل على ${offer['refereeReward']} ريال';
    } else {
      discountTitle = 'عرض خاص ومميز';
      subTitle = offer['comboDesc'] ?? '';
    }

    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          contentPadding: const EdgeInsets.all(0),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 🖼️ البوستر (الذي سيتم التقاطه كصورة)
              RepaintBoundary(
                key: posterKey,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [theme.primaryColor == Colors.white ? Colors.blue.shade900 : theme.primaryColor, Colors.black87],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
                  ),
                  child: Column(
                    children: [
                      const Text('🎉 عرض حصري 🎉', style: TextStyle(color: Colors.amber, fontSize: 24, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      Text(discountTitle, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 5),
                      Text(subTitle, style: const TextStyle(color: Colors.white70, fontSize: 16), textAlign: TextAlign.center),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                        child: Text(offer['code'], style: const TextStyle(color: Colors.black, fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: 3)),
                      ),
                      const SizedBox(height: 15),
                      Text('ينتهي العرض في: ${intl.DateFormat('yyyy-MM-dd').format((offer['expiryDate'] as Timestamp).toDate())}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                      if (offer['isHappyHour'] == true)
                        Text('ساعات العمل: ${offer['startTime']} إلى ${offer['endTime']}', style: const TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              // أزرار المشاركة
              Padding(
                padding: const EdgeInsets.all(15.0),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.text_fields),
                        label: const Text('كنص'),
                        onPressed: () {
                          Navigator.pop(context);
                          _shareText(offer);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                        icon: const Icon(Icons.image, color: Colors.white),
                        label: const Text('كصورة', style: TextStyle(color: Colors.white)),
                        onPressed: () async {
                          Navigator.pop(context);
                          await _sharePosterImage(posterKey, offer['code']);
                        },
                      ),
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  void _shareText(Map<String, dynamic> offer) {
    _play('click');
    String msg = "🎉 *عـرض خـاص وحـصـري!* 🎉\n\n";
    if (offer['discountType'] == 'percent') {
      msg += "استخدم الكود: *${offer['code']}*\nواحصل على خصم *${offer['discountValue']}%* على مشترياتك!\n";
    } else if (offer['discountType'] == 'fixed') {
      msg += "استخدم الكود: *${offer['code']}*\nواحصل على خصم *${offer['discountValue']} ريال*!\n";
    } else if (offer['discountType'] == 'referral') {
      msg += "استخدم كود الدعوة: *${offer['code']}*\nسجل معنا واحصل على رصيد مجاني *${offer['refereeReward']} ريال*!\n";
    } else {
      msg += "استخدم الكود: *${offer['code']}*\nواستفد من العرض: *${offer['comboDesc']}*\n";
    }

    if (offer['isHappyHour'] == true) msg += "⏳ *ملاحظة:* العرض يعمل فقط خلال الساعات السعيدة.\n";
    
    String exp = intl.DateFormat('yyyy-MM-dd').format((offer['expiryDate'] as Timestamp).toDate());
    msg += "\n⚠️ العرض ساري حتى: $exp\nسارع الآن وقم بزيادة أرباحك! 🚀";

    Share.share(msg);
  }

  Future<void> _sharePosterImage(GlobalKey posterKey, String code) async {
    _play('click');
    showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator()));
    try {
      RenderRepaintBoundary boundary = posterKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData != null) {
        Uint8List pngBytes = byteData.buffer.asUint8List();
        Navigator.pop(context); // إغلاق التحميل
        await Share.shareXFiles([XFile.fromData(pngBytes, mimeType: 'image/png', name: 'coupon_$code.png')], text: 'استخدم هذا الكود الآن! 🎉');
      }
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('عذراً، المتصفح لا يدعم توليد الصور، يرجى استخدام مشاركة النص.'), backgroundColor: Colors.red));
    }
  }

  Future<void> _deleteOffer(String docId) async {
    _play('error');
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
      await _db.collection('coupons').doc(docId).delete();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حذف العرض بنجاح.'), backgroundColor: Colors.green));
    }
  }

  Future<void> _broadcastNotification(Map<String, dynamic> offer, SystemProvider sys) async {
    _play('click');
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('جاري إرسال إشعار للبقالات... 🔔'), backgroundColor: Colors.teal));
    
    await _db.collection('notifications').add({
      'targetUserId': 'all', // لجميع مستخدمي الوكيل
      'agentPhone': sys.currentUserPhone,
      'title': 'عرض حصري جديد! 🎉',
      'body': 'تم إطلاق كود الخصم ${offer['code']}. افتح التطبيق للتفاصيل!',
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false
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
    final theme = Provider.of<ThemeProvider>(context);
    final isDark = theme.isDarkMode;
    final mainColor = theme.primaryColor == Colors.white ? Colors.blue.shade900 : theme.primaryColor;

    return Scaffold(
      backgroundColor: isDark ? Colors.black87 : Colors.grey.shade50,
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
                color: isDark ? Colors.grey.shade900 : mainColor,
                borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('ضاعف مبيعاتك! 🚀', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 5),
                  const Text('قم بإنشاء كوبونات وبطاقات إحالة لزيادة الولاء وتوسيع شبكتك.', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 15),
                  
                  // الإحصائيات الحية
                  StreamBuilder<QuerySnapshot>(
                    stream: _db.collection('coupons').where('agentPhone', isEqualTo: sys.currentUserPhone).snapshots(),
                    builder: (context, snapshot) {
                      int activeCount = 0;
                      int totalUses = 0;
                      if (snapshot.hasData) {
                        for (var doc in snapshot.data!.docs) {
                          var data = doc.data() as Map<String, dynamic>;
                          totalUses += (data['currentUsage'] as int? ?? 0);
                          DateTime exp = (data['expiryDate'] as Timestamp).toDate();
                          if (data['isActive'] == true && exp.isAfter(DateTime.now()) && ((data['currentUsage'] ?? 0) < (data['maxUsage'] ?? 1))) {
                            activeCount++;
                          }
                        }
                      }
                      return Row(
                        children: [
                          Expanded(child: _buildStatBox('العروض النشطة', '$activeCount', Colors.greenAccent)),
                          const SizedBox(width: 10),
                          Expanded(child: _buildStatBox('إجمالي الاستخدام', '$totalUses', Colors.amberAccent)),
                        ],
                      );
                    }
                  ),
                  const SizedBox(height: 15),

                  SizedBox(
                    width: double.infinity,
                    height: 45,
                    child: ElevatedButton.icon(
                      onPressed: () => _showCreateOfferDialog(sys, theme),
                      icon: Icon(Icons.add_shopping_cart, color: mainColor),
                      label: Text('إنشاء عرض جديد الآن', style: TextStyle(color: mainColor, fontWeight: FontWeight.bold, fontSize: 16)),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 10),
            
            // 2. عنوان القائمة
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text('حملاتك التسويقية الحالية:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white70 : Colors.blueGrey)),
              ),
            ),

            // 3. جلب وعرض الكوبونات (Coupons)
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _db.collection('coupons').where('agentPhone', isEqualTo: sys.currentUserPhone).orderBy('createdAt', descending: true).snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) return Center(child: Text('خطأ: ${snapshot.error}', style: TextStyle(color: isDark ? Colors.white : Colors.black)));
                  if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(child: Text('لا توجد عروض حالياً. ابدأ بإنشاء عرضك الأول!', style: TextStyle(color: isDark ? Colors.white54 : Colors.grey)));
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
                      else if (offer['discountType'] == 'referral') discountStr = 'إحالة: (الداعي ${offer['referrerReward']} / المدعو ${offer['refereeReward']})';
                      else discountStr = offer['comboDesc'] ?? '';

                      return Card(
                        elevation: 2,
                        color: isDark ? Colors.grey.shade800 : Colors.white,
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
                              if (offer['targetPhone'] != null && offer['targetPhone'] != '')
                                Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text('🎯 مخصص للرقم: ${offer['targetPhone']}', style: const TextStyle(color: Colors.blueAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                                ),
                              const Divider(height: 25),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(discountStr, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87)),
                                        const SizedBox(height: 4),
                                        Text('الاستخدام: $current / $max | الانتهاء: ${intl.DateFormat('yyyy-MM-dd').format(expiry)}', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                                        if (offer['isHappyHour'] == true)
                                          Text('⏳ يعمل فقط من ${offer['startTime']} إلى ${offer['endTime']}', style: const TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              // أزرار التحكم
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  IconButton(onPressed: () => _showSharePosterDialog(offer, theme), icon: const Icon(Icons.share, color: Colors.blue), tooltip: 'مشاركة (بوستر)', style: IconButton.styleFrom(backgroundColor: Colors.blue.withOpacity(0.1))),
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
