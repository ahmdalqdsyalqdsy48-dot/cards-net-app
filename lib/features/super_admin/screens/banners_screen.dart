import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; 
import 'package:cloud_firestore/cloud_firestore.dart'; // 👈 استدعاء قاعدة البيانات

import '../../../core/providers/system_provider.dart'; 
import '../../../core/widgets/custom_drawer.dart';
import '../../../core/widgets/custom_header.dart'; 

class BannersScreen extends StatefulWidget {
  const BannersScreen({super.key});

  @override
  State<BannersScreen> createState() => _BannersScreenState();
}

class _BannersScreenState extends State<BannersScreen> {
  // 👈 الإشارة المرجعية لمجموعة الإعلانات في قاعدة البيانات الحقيقية
  final CollectionReference _bannersCollection = FirebaseFirestore.instance.collection('banners');

  // ==========================================
  // 1. نافذة إنشاء إعلان جديد (مربوطة بقاعدة البيانات) ➕
  // ==========================================
  void _showAddBannerDialog() {
    int adType = 1; 
    int sendChannel = 1; 
    
    bool targetEndUsers = true;
    bool targetMainAgents = true;
    bool targetSubAgents = false;
    bool targetStaff = false;

    // 👈 متحكمات لجميع الحقول لضمان عدم ضياع أي معلومة
    final TextEditingController titleController = TextEditingController();
    final TextEditingController ctaController = TextEditingController();
    final TextEditingController linkController = TextEditingController();
    final TextEditingController startDateController = TextEditingController();
    final TextEditingController endDateController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.campaign, color: Colors.blueAccent),
                SizedBox(width: 8),
                Text('إنشاء حملة إعلانية جديدة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('نوع الإعلان:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Row(
                    children: [
                      Expanded(child: RadioListTile(title: const Text('صورة (Carousel)', style: TextStyle(fontSize: 12)), value: 1, groupValue: adType, onChanged: (val) => setStateDialog(() => adType = val as int))),
                      Expanded(child: RadioListTile(title: const Text('شريط إخباري', style: TextStyle(fontSize: 12)), value: 2, groupValue: adType, onChanged: (val) => setStateDialog(() => adType = val as int))),
                    ],
                  ),
                  
                  // حقل العنوان
                  _buildTextField(
                    adType == 1 ? 'عنوان العرض التسويقي' : 'نص الشريط الإخباري المتحرك', 
                    Icons.title,
                    controller: titleController,
                  ),
                  
                  if (adType == 1) ...[
                    ElevatedButton.icon(onPressed: (){}, icon: const Icon(Icons.upload_file), label: const Text('رفع الصورة المدمجة')),
                    const SizedBox(height: 10),
                    _buildTextField('نص زر الإجراء (CTA) - مثلاً: اغتنم الفرصة', Icons.smart_button, controller: ctaController),
                  ],
                  _buildTextField('الرابط عند النقر (URL أو توجيه داخلي)', Icons.link, controller: linkController),
                  
                  const Divider(),
                  const Text('قناة الإرسال:', style: TextStyle(fontWeight: FontWeight.bold)),
                  DropdownButtonFormField<int>(
                    value: sendChannel,
                    decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10)),
                    items: const [
                      DropdownMenuItem(value: 1, child: Text('الكل (تطبيق + إيميل)')),
                      DropdownMenuItem(value: 2, child: Text('داخل التطبيق فقط')),
                      DropdownMenuItem(value: 3, child: Text('عبر الإيميل فقط')),
                    ],
                    onChanged: (val) => setStateDialog(() => sendChannel = val!),
                  ),
                  
                  const Divider(),
                  const Text('الاستهداف الدقيق لمن يرى الإعلان:', style: TextStyle(fontWeight: FontWeight.bold)),
                  CheckboxListTile(title: const Text('المستخدمين النهائيين (الزبائن)'), value: targetEndUsers, onChanged: (val) => setStateDialog(() => targetEndUsers = val!)),
                  CheckboxListTile(title: const Text('الوكلاء الرئيسيين'), value: targetMainAgents, onChanged: (val) => setStateDialog(() => targetMainAgents = val!)),
                  CheckboxListTile(title: const Text('وكلاء الوكلاء (الفرعيين)'), value: targetSubAgents, onChanged: (val) => setStateDialog(() => targetSubAgents = val!)),
                  CheckboxListTile(title: const Text('الموظفين الداخليين'), value: targetStaff, onChanged: (val) => setStateDialog(() => targetStaff = val!)),
                  
                  const Divider(),
                  const Text('الجدولة الزمنية:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _buildTextField('بداية (YYYY-MM-DD)', Icons.play_arrow, controller: startDateController)),
                      const SizedBox(width: 8),
                      Expanded(child: _buildTextField('نهاية (YYYY-MM-DD)', Icons.stop, controller: endDateController)),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
              ElevatedButton(
                onPressed: () async {
                  if (titleController.text.trim().isNotEmpty) {
                    
                    // تحديد نص الاستهداف بناءً على الخيارات
                    String targetText = 'مخصص';
                    if (targetEndUsers && targetMainAgents && targetSubAgents && targetStaff) {
                      targetText = 'الجميع';
                    } else if (targetEndUsers && !targetMainAgents) {
                      targetText = 'المستخدمين';
                    } else if (!targetEndUsers && targetMainAgents) {
                      targetText = 'الوكلاء';
                    }

                    // تحديد قناة الإرسال كنص
                    String channelText = sendChannel == 1 ? 'تطبيق وإيميل' : (sendChannel == 2 ? 'تطبيق فقط' : 'إيميل فقط');

                    // 👈 رفع جميع التفاصيل لقاعدة البيانات
                    await _bannersCollection.add({
                      'title': titleController.text,
                      'type': adType == 1 ? 'صورة بانر (Carousel)' : 'شريط إخباري (زجاجي)',
                      'target': targetText,
                      'sendChannel': channelText,
                      'ctaText': ctaController.text,
                      'linkUrl': linkController.text,
                      'startDate': startDateController.text,
                      'endDate': endDateController.text,
                      'status': 'نشط',
                      'views': 0, // الإحصائيات تبدأ من صفر
                      'clicksApp': 0,
                      'clicksEmail': 0,
                      'colorValue': Colors.blue.value,
                      'createdAt': FieldValue.serverTimestamp(),
                      'targetConfig': {
                        'endUsers': targetEndUsers,
                        'mainAgents': targetMainAgents,
                        'subAgents': targetSubAgents,
                        'staff': targetStaff,
                      }
                    });

                    if(mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إطلاق الحملة التسويقية بنجاح! 🚀', textDirection: TextDirection.rtl), backgroundColor: Colors.green));
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى كتابة عنوان الإعلان على الأقل! ❌', textDirection: TextDirection.rtl), backgroundColor: Colors.red));
                  }
                },
                child: const Text('اعتماد الإعلان'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // نافذة تعديل إعلان موجود ✏️ (مربوطة بـ Firestore)
  // ==========================================
  void _showEditBannerDialog(String docId, String currentTitle) {
    final titleController = TextEditingController(text: currentTitle);
    
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تعديل عنوان الإعلان', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          content: _buildTextField('عنوان الإعلان', Icons.edit, controller: titleController),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              onPressed: () async {
                if (titleController.text.isNotEmpty) {
                  // 👈 تحديث البيانات في السيرفر
                  await _bannersCollection.doc(docId).update({
                    'title': titleController.text,
                  });
                  if(mounted){
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تعديل الإعلان بنجاح ✏️', textDirection: TextDirection.rtl), backgroundColor: Colors.green));
                  }
                }
              },
              child: const Text('حفظ التعديل', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // دوال التحكم بالإعلانات (إيقاف / تشغيل / حذف) - مربوطة بـ Firestore
  // ==========================================
  void _toggleBannerStatus(String docId, String currentStatus) async {
    String newStatus = currentStatus == 'نشط' ? 'موقوف مؤقتاً' : 'نشط';
    int newColor = newStatus == 'نشط' ? Colors.green.value : Colors.grey.value;

    await _bannersCollection.doc(docId).update({
      'status': newStatus,
      'colorValue': newColor,
    });
  }

  void _deleteBanner(String docId) {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حذف الإعلان 🗑️', style: TextStyle(color: Colors.red)),
          content: const Text('هل أنت متأكد من مسح هذه الحملة الإعلانية نهائياً؟'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('تراجع')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                await _bannersCollection.doc(docId).delete(); // 👈 حذف من السيرفر نهائياً
                if(mounted){
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم الحذف بنجاح.', textDirection: TextDirection.rtl), backgroundColor: Colors.red));
                }
              },
              child: const Text('حذف', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // جلب الأرباح الحقيقية للنظام من العقل المدبر
    final systemProvider = Provider.of<SystemProvider>(context);
    final adminBalance = systemProvider.adminMainBalance;

    return Scaffold(
      appBar: const CustomHeader(title: 'الإعلانات والبنرات'),
      
      drawer: CustomDrawer(
        userName: 'مالك النظام',
        phoneNumber: '774578241',
        role: 'مالك النظام (Super Admin)',
        balanceOrPoints: 'أرباح النظام: ${adminBalance.toStringAsFixed(0)} ريال',
      ),
      
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            // زر إضافة إعلان جديد
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _showAddBannerDialog,
                  icon: const Icon(Icons.campaign, color: Colors.white),
                  label: const Text('إنشاء حملة إعلانية جديدة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ),

            // 👈 المستمع الحي لقاعدة البيانات (جدول المراقبة والإحصائيات)
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _bannersCollection.orderBy('createdAt', descending: true).snapshots(),
                builder: (context, snapshot) {
                  // حالة التحميل
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  
                  // حالة عدم وجود بيانات
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text('لا توجد إعلانات حالياً. ابدأ بإنشاء حملتك الأولى! 🚀', style: TextStyle(color: Colors.grey)));
                  }

                  final bannersDocs = snapshot.data!.docs;

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: bannersDocs.length,
                    itemBuilder: (context, index) {
                      final doc = bannersDocs[index];
                      final bannerData = doc.data() as Map<String, dynamic>;
                      final docId = doc.id; 

                      final isExpired = bannerData['status'] == 'منتهي';
                      final bannerColor = Color(bannerData['colorValue'] ?? Colors.blue.value);

                      return Card(
                        elevation: 3,
                        margin: const EdgeInsets.only(bottom: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                          side: BorderSide(color: bannerColor.withOpacity(0.5), width: 2),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Chip(
                                    label: Text(bannerData['status'] ?? 'غير معروف', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                    backgroundColor: bannerColor,
                                    padding: EdgeInsets.zero,
                                  ),
                                  Text(bannerData['type'] ?? '', style: const TextStyle(color: Colors.blueGrey, fontSize: 12, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const SizedBox(height: 5),
                              Text(bannerData['title'] ?? '', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isExpired ? Colors.grey : null)),
                              Text('الاستهداف: ${bannerData['target'] ?? ''}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                              
                              const Divider(),
                              // الإحصائيات التفصيلية (تقرأ من الداتا بيز الآن)
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).brightness == Brightness.dark ? Colors.black12 : Colors.blue.shade50, 
                                  borderRadius: BorderRadius.circular(10)
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: [
                                    _buildStatColumn(Icons.visibility, 'المشاهدات', '${bannerData['views'] ?? 0}', Colors.blue),
                                    _buildStatColumn(Icons.touch_app, 'نقرات التطبيق', '${bannerData['clicksApp'] ?? 0}', Colors.green),
                                    _buildStatColumn(Icons.mark_email_read, 'نقرات الإيميل', '${bannerData['clicksEmail'] ?? 0}', Colors.orange),
                                  ],
                                ),
                              ),
                              
                              const SizedBox(height: 10),
                              // أزرار التحكم
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  if (!isExpired)
                                    IconButton(
                                      icon: Icon(bannerData['status'] == 'نشط' ? Icons.visibility_off : Icons.visibility, color: bannerData['status'] == 'نشط' ? Colors.orange : Colors.green),
                                      tooltip: 'إيقاف/تشغيل',
                                      onPressed: () => _toggleBannerStatus(docId, bannerData['status']),
                                    ),
                                  IconButton(icon: const Icon(Icons.edit, color: Colors.blue), tooltip: 'تعديل', onPressed: () => _showEditBannerDialog(docId, bannerData['title'])),
                                  IconButton(icon: const Icon(Icons.delete, color: Colors.red), tooltip: 'حذف', onPressed: () => _deleteBanner(docId)),
                                ],
                              ),
                            ],
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

  // أداة بناء حقول النصوص في النافذة 
  Widget _buildTextField(String hint, IconData icon, {TextEditingController? controller}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 12),
          prefixIcon: Icon(icon, color: Colors.blueAccent, size: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }

  // أداة بناء أعمدة الإحصائيات
  Widget _buildStatColumn(IconData icon, String label, String value, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color)),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.blueGrey)),
      ],
    );
  }
}
