import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // 👈 استدعاء قاعدة البيانات الحقيقية

import '../../../core/providers/system_provider.dart';
import '../../../core/widgets/custom_drawer.dart';
import '../../../core/widgets/custom_header.dart'; 

class BannersScreen extends StatefulWidget {
  const BannersScreen({super.key});

  @override
  State<BannersScreen> createState() => _BannersScreenState();
}

class _BannersScreenState extends State<BannersScreen> {
  // 👈 الإشارة المرجعية لمجموعة الإعلانات في فايربيس
  final CollectionReference _bannersCollection = FirebaseFirestore.instance.collection('banners');

  // ==========================================
  // 1. إضافة إعلان جديد إلى فايربيس ➕
  // ==========================================
  void _showAddBannerDialog() {
    int adType = 1; 
    int sendChannel = 1; 
    
    bool targetEndUsers = true;
    bool targetMainAgents = true;
    bool targetSubAgents = false;
    bool targetStaff = false;

    final TextEditingController titleController = TextEditingController();

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
                      Expanded(child: RadioListTile(title: const Text('صورة', style: TextStyle(fontSize: 12)), value: 1, groupValue: adType, onChanged: (val) => setStateDialog(() => adType = val as int))),
                      Expanded(child: RadioListTile(title: const Text('شريط إخباري', style: TextStyle(fontSize: 12)), value: 2, groupValue: adType, onChanged: (val) => setStateDialog(() => adType = val as int))),
                    ],
                  ),
                  
                  _buildTextField(
                    adType == 1 ? 'عنوان العرض التسويقي' : 'نص الشريط الإخباري', 
                    Icons.title,
                    controller: titleController,
                  ),
                  
                  if (adType == 1) ...[
                    ElevatedButton.icon(onPressed: (){}, icon: const Icon(Icons.upload_file), label: const Text('رفع الصورة المدمجة (قريباً)')),
                    const SizedBox(height: 10),
                    _buildTextField('نص زر الإجراء (CTA)', Icons.smart_button),
                  ],
                  _buildTextField('الرابط عند النقر', Icons.link),
                  
                  const Divider(),
                  const Text('الاستهداف:', style: TextStyle(fontWeight: FontWeight.bold)),
                  CheckboxListTile(title: const Text('المستخدمين النهائيين'), value: targetEndUsers, onChanged: (val) => setStateDialog(() => targetEndUsers = val!)),
                  CheckboxListTile(title: const Text('الوكلاء'), value: targetMainAgents, onChanged: (val) => setStateDialog(() => targetMainAgents = val!)),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
              ElevatedButton(
                onPressed: () async {
                  if (titleController.text.trim().isNotEmpty) {
                    // 👈 رفع البيانات الحقيقية إلى Firestore
                    await _bannersCollection.add({
                      'title': titleController.text,
                      'type': adType == 1 ? 'صورة بانر' : 'شريط إخباري',
                      'target': targetEndUsers ? 'الكل' : 'مخصص',
                      'status': 'نشط',
                      'views': 0, // الأرقام الحقيقية تبدأ من صفر
                      'clicksApp': 0,
                      'clicksEmail': 0,
                      'colorValue': Colors.blue.value, // حفظ اللون كرقم
                      'createdAt': FieldValue.serverTimestamp(), // وقت الإنشاء الحقيقي
                    });

                    if(mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إطلاق الحملة التسويقية بنجاح! 🚀', textDirection: TextDirection.rtl), backgroundColor: Colors.green));
                    }
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
  // تعديل إعلان موجود في فايربيس ✏️
  // ==========================================
  void _showEditBannerDialog(String docId, String currentTitle) {
    final titleController = TextEditingController(text: currentTitle);
    
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تعديل الإعلان', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          content: _buildTextField('عنوان الإعلان', Icons.edit, controller: titleController),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              onPressed: () async {
                if (titleController.text.isNotEmpty) {
                  // 👈 تحديث الوثيقة في السيرفر
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
  // تغيير حالة الإعلان في فايربيس (نشط/موقوف)
  // ==========================================
  void _toggleBannerStatus(String docId, String currentStatus) async {
    String newStatus = currentStatus == 'نشط' ? 'موقوف مؤقتاً' : 'نشط';
    int newColor = newStatus == 'نشط' ? Colors.green.value : Colors.grey.value;

    await _bannersCollection.doc(docId).update({
      'status': newStatus,
      'colorValue': newColor,
    });
  }

  // ==========================================
  // حذف إعلان نهائياً من فايربيس 🗑️
  // ==========================================
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
                await _bannersCollection.doc(docId).delete(); // 👈 أمر الحذف من السيرفر
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

            // 👈 المستمع الحي لقاعدة البيانات (StreamBuilder)
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
                      final docId = doc.id; // معرف الوثيقة الفريد

                      final isExpired = bannerData['status'] == 'منتهي';
                      // استرجاع اللون من الرقم المحفوظ
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
                                    label: Text(bannerData['status'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
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
