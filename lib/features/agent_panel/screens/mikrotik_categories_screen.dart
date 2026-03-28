import 'package:flutter/material.dart';
import '../../../core/widgets/custom_header.dart'; // 👈 استدعاء الترويسة المخصصة
import '../widgets/custom_agent_drawer.dart';

class MikrotikCategoriesScreen extends StatefulWidget {
  const MikrotikCategoriesScreen({super.key});

  @override
  State<MikrotikCategoriesScreen> createState() => _MikrotikCategoriesScreenState();
}

class _MikrotikCategoriesScreenState extends State<MikrotikCategoriesScreen> {
  final List<Map<String, dynamic>> _servers = [
    {'id': '1', 'name': 'سيرفر المنطقة الشمالية', 'ip': '192.168.88.1', 'status': 'متصل نشط 🟢'},
  ];

  final List<Map<String, dynamic>> _categories = [
    {'id': '1', 'name': 'فئة أبو 1000', 'time': '24 ساعة', 'capacity': '1 جيجا', 'price': 1000, 'color': Colors.blue, 'stock': 5}, 
    {'id': '2', 'name': 'فئة أبو 500', 'time': '12 ساعة', 'capacity': '500 ميجا', 'price': 500, 'color': Colors.orange, 'stock': 150},
  ];

  String? _selectedServerToGenerate;
  String? _selectedCategoryToGenerate;
  final TextEditingController _generateAmountController = TextEditingController();

  void _showAddServerBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, top: 20, left: 16, right: 16),
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

  void _showAddCategoryBottomSheet() {
    String newName = '';
    String newTime = '';
    String newCapacity = '';
    String newPrice = '';
    Color selectedColor = Colors.blue;
    final List<Color> colorOptions = [Colors.blue, Colors.orange, Colors.green, Colors.purple, Colors.red, Colors.teal];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, top: 20, left: 16, right: 16),
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('إضافة فئة جديدة (Profile) 🎟️', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 20),
                      TextField(
                        onChanged: (val) => newName = val,
                        decoration: InputDecoration(labelText: 'اسم الفئة (مثال: أبو 1000)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), prefixIcon: const Icon(Icons.category))
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: TextField(
                            onChanged: (val) => newTime = val,
                            decoration: InputDecoration(labelText: 'الوقت (ساعة/يوم)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), prefixIcon: const Icon(Icons.timer))
                          )),
                          const SizedBox(width: 10),
                          Expanded(child: TextField(
                            onChanged: (val) => newCapacity = val,
                            decoration: InputDecoration(labelText: 'السعة (ميجا/جيجا)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), prefixIcon: const Icon(Icons.data_usage))
                          )),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        onChanged: (val) => newPrice = val,
                        keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'سعر البيع للجمهور (ريال)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), prefixIcon: const Icon(Icons.attach_money))
                      ),
                      const SizedBox(height: 15),
                      const Align(alignment: Alignment.centerRight, child: Text('اختر لون الفئة:', style: TextStyle(fontWeight: FontWeight.bold))),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: colorOptions.map((color) {
                          return GestureDetector(
                            onTap: () {
                              setModalState(() => selectedColor = color);
                            },
                            child: CircleAvatar(
                              backgroundColor: color,
                              radius: 20,
                              child: selectedColor == color ? const Icon(Icons.check, color: Colors.white) : null,
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: selectedColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                          onPressed: () {
                            if (newName.isNotEmpty && newPrice.isNotEmpty) {
                              setState(() {
                                _categories.add({
                                  'id': DateTime.now().toString(),
                                  'name': newName,
                                  'time': newTime.isNotEmpty ? newTime : 'غير محدد',
                                  'capacity': newCapacity.isNotEmpty ? newCapacity : 'مفتوح',
                                  'price': int.tryParse(newPrice) ?? 0,
                                  'color': selectedColor,
                                  'stock': 0, 
                                });
                              });
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت إضافة الفئة بنجاح 📋'), backgroundColor: Colors.green));
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء إدخال الاسم والسعر!'), backgroundColor: Colors.red));
                            }
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DefaultTabController(
      length: 4, 
      // 👇 التعديل الجذري: الـ Scaffold هو الحاوي الخارجي ليحفظ اتجاه القائمة الجانبية (Drawer)
      child: Scaffold(
        appBar: const CustomHeader(title: 'إدارة الميكروتك والفئات'),
        drawer: const CustomAgentDrawer(
          agentName: 'شبكة الصقر للواي فاي',
          phoneNumber: '777777777',
          role: 'وكيل معتمد (Agent)',
          currentBalance: 125000.0,
        ),
        // 👇 الأمر الخاص باللغة العربية تم نقله ليغطي المحتوى الداخلي فقط
        body: Directionality(
          textDirection: TextDirection.rtl,
          child: Column(
            children: [
              // الحاوية العلوية المنحنية وبداخلها التبويبات
              Container(
                width: double.infinity,
                padding: const EdgeInsets.only(bottom: 5, top: 5),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade900 : Colors.blue.shade800,
                  borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
                ),
                child: const TabBar(
                  isScrollable: true,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white54,
                  indicatorColor: Colors.orange,
                  indicatorWeight: 4,
                  labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  tabs: [
                    Tab(icon: Icon(Icons.dns), text: 'سيرفرات الربط'),
                    Tab(icon: Icon(Icons.category), text: 'المخزون والفئات'),
                    Tab(icon: Icon(Icons.local_offer), text: 'شرائح الخصم'),
                    Tab(icon: Icon(Icons.autorenew), text: 'توليد الكروت'),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildServersTab(),
                    _buildCategoriesTab(),
                    _buildDiscountTiersTab(),
                    _buildGenerateCardsTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildServersTab() {
    return Scaffold(
      backgroundColor: Colors.transparent, // لجعل الخلفية تتناسب مع ثيم التطبيق
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _servers.length,
        itemBuilder: (context, index) {
          final server = _servers[index];
          return Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            elevation: 3,
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: const CircleAvatar(backgroundColor: Colors.green, child: Icon(Icons.router, color: Colors.white)),
              title: Text(server['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('IP: ${server['ip']}\nالحالة: ${server['status']}'),
              trailing: IconButton(icon: const Icon(Icons.settings, color: Colors.grey), onPressed: () {}),
            ),
          );
        }
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddServerBottomSheet,
        backgroundColor: Colors.blue.shade800,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('إضافة سيرفر', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildCategoriesTab() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _categories.isEmpty 
        ? const Center(child: Text('لا توجد فئات حالياً، قم بإضافة فئة جديدة.'))
        : ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _categories.length,
          itemBuilder: (context, index) {
            final category = _categories[index];
            return _buildCategoryCard(category);
          }
        ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddCategoryBottomSheet,
        backgroundColor: Colors.orange.shade700,
        icon: const Icon(Icons.add_circle, color: Colors.white),
        label: const Text('إضافة فئة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildCategoryCard(Map<String, dynamic> category) {
    bool isLowStock = category['stock'] < 10;
    
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: category['color'].withOpacity(0.5))),
      margin: const EdgeInsets.only(bottom: 15),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(category['name'], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: category['color'])),
                Row(
                  children: [
                    IconButton(icon: const Icon(Icons.edit, color: Colors.blue, size: 20), onPressed: () {}, constraints: const BoxConstraints(), padding: EdgeInsets.zero),
                    const SizedBox(width: 15),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red, size: 20), 
                      onPressed: () {
                        setState(() { _categories.remove(category); });
                      }, 
                      constraints: const BoxConstraints(), padding: EdgeInsets.zero
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('الوقت: ${category['time']} | السعة: ${category['capacity']}', style: const TextStyle(color: Colors.grey)),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('سعر الجمهور: ${category['price']} ريال', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isLowStock ? Colors.red.shade100 : Colors.green.shade100,
                    borderRadius: BorderRadius.circular(10)
                  ),
                  child: Text(
                    'المخزون: ${category['stock']} كرت', 
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isLowStock ? Colors.red : Colors.green.shade800)
                  ),
                ),
              ],
            ),
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
            value: _selectedServerToGenerate,
            items: _servers.map((s) => DropdownMenuItem(value: s['id'] as String, child: Text(s['name']))).toList(),
            onChanged: (value) => setState(() => _selectedServerToGenerate = value),
          ),
          const SizedBox(height: 15),
          DropdownButtonFormField<String>(
            decoration: InputDecoration(labelText: 'اختر الفئة (Profile)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
            value: _selectedCategoryToGenerate,
            items: _categories.map((c) => DropdownMenuItem(value: c['id'] as String, child: Text(c['name']))).toList(),
            onChanged: (value) => setState(() => _selectedCategoryToGenerate = value),
          ),
          const SizedBox(height: 15),
          TextField(
            controller: _generateAmountController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: 'الكمية المطلوب توليدها (مثال: 100)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), prefixIcon: const Icon(Icons.format_list_numbered)),
          ),
          const SizedBox(height: 30),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () {
                if (_selectedCategoryToGenerate != null && _generateAmountController.text.isNotEmpty) {
                  int amount = int.tryParse(_generateAmountController.text) ?? 0;
                  if (amount > 0) {
                    setState(() {
                      var category = _categories.firstWhere((c) => c['id'] == _selectedCategoryToGenerate);
                      category['stock'] += amount;
                    });
                    _generateAmountController.clear();
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم توليد وإضافة $amount كرت بنجاح! ✅'), backgroundColor: Colors.green));
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء اختيار الفئة وإدخال الكمية'), backgroundColor: Colors.red));
                }
              },
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
