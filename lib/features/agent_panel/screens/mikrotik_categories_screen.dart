import 'package:flutter/material.dart';

class MikrotikCategoriesScreen extends StatefulWidget {
  const MikrotikCategoriesScreen({super.key});

  @override
  State<MikrotikCategoriesScreen> createState() => _MikrotikCategoriesScreenState();
}

class _MikrotikCategoriesScreenState extends State<MikrotikCategoriesScreen> {
  
  // ==========================================
  // دالة نافذة إضافة سيرفر ميكروتك جديد
  // ==========================================
  void _showAddServerBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // ضروري لكي ترتفع النافذة مع لوحة المفاتيح
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom, // تفادي تغطية لوحة المفاتيح
            top: 20, left: 16, right: 16,
          ),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('إضافة سيرفر ميكروتك جديد 📡', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  TextField(decoration: InputDecoration(labelText: 'الاسم (مثال: سيرفر المنطقة الشمالية)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), prefixIcon: const Icon(Icons.dns))),
                  const SizedBox(height: 12),
                  TextField(decoration: InputDecoration(labelText: 'عنوان IP (مثال: 192.168.88.1)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), prefixIcon: const Icon(Icons.wifi))),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: TextField(decoration: InputDecoration(labelText: 'اسم المستخدم', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), prefixIcon: const Icon(Icons.person)))),
                      const SizedBox(width: 10),
                      Expanded(child: TextField(obscureText: true, decoration: InputDecoration(labelText: 'كلمة المرور', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), prefixIcon: const Icon(Icons.lock)))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(decoration: InputDecoration(labelText: 'API Port (الافتراضي: 8728)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), prefixIcon: const Icon(Icons.settings_ethernet))),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade800, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                      onPressed: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت إضافة السيرفر ومحاولة الاتصال بنجاح 🟢'), backgroundColor: Colors.green));
                      },
                      child: const Text('حفظ واتصال', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ==========================================
  // دالة نافذة إضافة فئة كروت جديدة (Profile)
  // ==========================================
  void _showAddCategoryBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 20, left: 16, right: 16,
          ),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('إضافة فئة جديدة (Profile) 🎟️', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  TextField(decoration: InputDecoration(labelText: 'اسم الفئة (مثال: أبو 1000)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), prefixIcon: const Icon(Icons.category))),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: TextField(keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'الوقت (ساعة)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), prefixIcon: const Icon(Icons.timer)))),
                      const SizedBox(width: 10),
                      Expanded(child: TextField(keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'السعة (ميجا)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), prefixIcon: const Icon(Icons.data_usage)))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'سعر البيع للجمهور (ريال)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), prefixIcon: const Icon(Icons.attach_money))),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade700, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                      onPressed: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت إضافة الفئة بنجاح 📋'), backgroundColor: Colors.green));
                      },
                      child: const Text('حفظ الفئة', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4, 
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('إدارة الميكروتك والفئات', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
            backgroundColor: Colors.blue.shade800,
            foregroundColor: Colors.white,
            elevation: 0,
            bottom: const TabBar(
              isScrollable: true,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white54,
              indicatorColor: Colors.orange,
              indicatorWeight: 4,
              labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              tabs: [
                Tab(icon: Icon(Icons.dns), text: 'سيرفرات الربط'),
                Tab(icon: Icon(Icons.category), text: 'إدارة الفئات'),
                Tab(icon: Icon(Icons.local_offer), text: 'شرائح الخصم'),
                Tab(icon: Icon(Icons.autorenew), text: 'توليد الكروت'),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              _buildServersTab(),
              _buildCategoriesTab(),
              _buildDiscountTiersTab(),
              _buildGenerateCardsTab(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildServersTab() {
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            elevation: 3,
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: const CircleAvatar(backgroundColor: Colors.green, child: Icon(Icons.router, color: Colors.white)),
              title: const Text('سيرفر المنطقة الشمالية', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('IP: 192.168.88.1\nالحالة: متصل نشط 🟢'),
              trailing: IconButton(icon: const Icon(Icons.settings, color: Colors.grey), onPressed: () {}),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddServerBottomSheet, // 👇 ربط الزر بالنافذة المنبثقة
        backgroundColor: Colors.blue.shade800,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('إضافة سيرفر', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildCategoriesTab() {
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildCategoryCard('فئة أبو 1000', 'الوقت: 24 ساعة | السعة: 1 جيجا', 'سعر الجمهور: 1000 ريال', Colors.blue),
          _buildCategoryCard('فئة أبو 500', 'الوقت: 12 ساعة | السعة: 500 ميجا', 'سعر الجمهور: 500 ريال', Colors.orange),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddCategoryBottomSheet, // 👇 ربط الزر بالنافذة المنبثقة
        backgroundColor: Colors.orange.shade700,
        icon: const Icon(Icons.add_circle, color: Colors.white),
        label: const Text('إضافة فئة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildCategoryCard(String title, String details, String price, Color color) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: color.withOpacity(0.5))),
      margin: const EdgeInsets.only(bottom: 15),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: color)),
                Row(
                  children: [
                    IconButton(icon: const Icon(Icons.edit, color: Colors.blue, size: 20), onPressed: () {}, constraints: const BoxConstraints(), padding: EdgeInsets.zero),
                    const SizedBox(width: 15),
                    IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 20), onPressed: () {}, constraints: const BoxConstraints(), padding: EdgeInsets.zero),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(details, style: const TextStyle(color: Colors.grey)),
            const Divider(),
            Text(price, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
      ),
    );
  }

  Widget _buildDiscountTiersTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(10)),
          child: const Text('💡 يتم تطبيق هذا الخصم (سعر الجملة) تلقائياً للبقالات بناءً على حجم مسحوباتها.', style: TextStyle(color: Colors.brown, fontWeight: FontWeight.bold, fontSize: 12)),
        ),
        const SizedBox(height: 15),
        _buildTierCard('الشريحة الذهبية 🏆', 'للبقالات التي تسحب أكثر من 70,000 ريال', 'خصم: 30%', Colors.amber.shade700),
        _buildTierCard('الشريحة الفضية 🥈', 'للبقالات التي تسحب أكثر من 50,000 ريال', 'خصم: 20%', Colors.grey.shade600),
        _buildTierCard('الشريحة البرونزية 🥉', 'للبقالات التي تسحب أقل من 30,000 ريال', 'خصم: 10%', Colors.brown.shade400),
      ],
    );
  }

  Widget _buildTierCard(String title, String condition, String discount, Color color) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(Icons.stars, color: color, size: 35),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        subtitle: Text(condition, style: const TextStyle(fontSize: 12)),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
          child: Text(discount, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        ),
      ),
    );
  }

  Widget _buildGenerateCardsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('توليد كروت جديدة وسحبها للنظام', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            decoration: InputDecoration(labelText: 'اختر سيرفر الميكروتك', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
            items: const [DropdownMenuItem(value: '1', child: Text('سيرفر المنطقة الشمالية'))],
            onChanged: (value) {},
          ),
          const SizedBox(height: 15),
          DropdownButtonFormField<String>(
            decoration: InputDecoration(labelText: 'اختر الفئة (Profile)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
            items: const [
              DropdownMenuItem(value: '1', child: Text('فئة أبو 1000')),
              DropdownMenuItem(value: '2', child: Text('فئة أبو 500')),
            ],
            onChanged: (value) {},
          ),
          const SizedBox(height: 15),
          TextField(
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: 'الكمية المطلوب توليدها (مثال: 500)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), prefixIcon: const Icon(Icons.format_list_numbered)),
          ),
          const SizedBox(height: 30),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.autorenew, color: Colors.white),
              label: const Text('بدء التوليد والسحب', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            ),
          ),
        ],
      ),
    );
  }
}
