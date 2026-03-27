import 'package:flutter/material.dart';

class QuickPosScreen extends StatefulWidget {
  const QuickPosScreen({super.key});

  @override
  State<QuickPosScreen> createState() => _QuickPosScreenState();
}

class _QuickPosScreenState extends State<QuickPosScreen> {
  // رصيد الوكيل الوهمي للتجربة
  double _walletBalance = 125000.0;
  
  // الفئة المحددة حالياً
  Map<String, dynamic>? _selectedCategory;

  // قائمة وهمية للفئات المتاحة للبيع
  final List<Map<String, dynamic>> _categories = [
    {'name': 'فئة أبو 1000', 'price': 1000, 'time': '24 ساعة', 'color': Colors.blue},
    {'name': 'فئة أبو 500', 'price': 500, 'time': '12 ساعة', 'color': Colors.orange},
    {'name': 'فئة أبو 250', 'price': 250, 'time': '6 ساعات', 'color': Colors.green},
    {'name': 'فئة أبو 100', 'price': 100, 'time': 'ساعتين', 'color': Colors.purple},
  ];

  // ==========================================
  // دالة نافذة تأكيد عملية البيع
  // ==========================================
  void _showConfirmSaleDialog() {
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء اختيار فئة أولاً!'), backgroundColor: Colors.red),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            title: const Text('تأكيد البيع 🛒', style: TextStyle(fontWeight: FontWeight.bold)),
            content: Text(
              'هل أنت متأكد من خصم مبلغ ${_selectedCategory!['price']} ريال من محفظتك لبيع كرت (${_selectedCategory!['name']})؟',
              style: const TextStyle(fontSize: 16),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إلغاء', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                onPressed: () {
                  Navigator.pop(context); // إغلاق نافذة التأكيد
                  _processSale(); // تنفيذ البيع
                },
                child: const Text('تأكيد وبيع', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }

  // ==========================================
  // دالة معالجة البيع وعرض نافذة الكرت الجديد
  // ==========================================
  void _processSale() {
    setState(() {
      _walletBalance -= _selectedCategory!['price']; // خصم المبلغ من المحفظة
    });

    // توليد رقم كرت وهمي للتجربة
    String generatedPin = "8472 9102 3341";

    showDialog(
      context: context,
      barrierDismissible: false, // لا يمكن إغلاقها بالنقر خارجها
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 60),
                const SizedBox(height: 15),
                const Text('تمت عملية البيع بنجاح!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green)),
                const SizedBox(height: 20),
                
                // شكل الكرت
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: _selectedCategory!['color'].withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    // 👇 تم إبقاء أمر واحد فقط لتنسيق الإطار (border)
                    border: Border.all(color: _selectedCategory!['color'].withOpacity(0.5), width: 2, style: BorderStyle.solid),
                  ),
                  child: Column(
                    children: [
                      Text(_selectedCategory!['name'], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _selectedCategory!['color'])),
                      const Divider(),
                      const Text('رقم الكرت (PIN)', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      Text(generatedPin, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24, letterSpacing: 2)),
                      const SizedBox(height: 5),
                      Text('الوقت: ${_selectedCategory!['time']}', style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // أزرار المشاركة والطباعة
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildActionButton(Icons.share, 'مشاركة', Colors.blue, () {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('جاري فتح واتساب...')));
                    }),
                    _buildActionButton(Icons.print, 'طباعة', Colors.orange, () {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('جاري الإرسال للطابعة بلوتوث...')));
                    }),
                  ],
                ),
                
                const SizedBox(height: 15),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    setState(() {
                      _selectedCategory = null; // إعادة تعيين التحديد لعملية بيع جديدة
                    });
                  },
                  child: const Text('إغلاق وبدء بيع جديد', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionButton(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
        child: Column(
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 5),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('المتجر السريع (الكاشير)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
          backgroundColor: Colors.teal.shade700,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: Column(
          children: [
            // ==========================================
            // 1. شريط رصيد المحفظة العلوي
            // ==========================================
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.teal.shade700,
                borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('رصيد المحفظة المتاح:', style: TextStyle(color: Colors.white70, fontSize: 16)),
                  Text('${_walletBalance.toStringAsFixed(0)} ريال', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ==========================================
            // 2. شبكة الفئات المتاحة للبيع
            // ==========================================
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('اختر الفئة المطلوبة:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blueGrey)),
                    const SizedBox(height: 15),
                    Expanded(
                      child: GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 15,
                          mainAxisSpacing: 15,
                          childAspectRatio: 1.2,
                        ),
                        itemCount: _categories.length,
                        itemBuilder: (context, index) {
                          final category = _categories[index];
                          final isSelected = _selectedCategory == category;

                          return InkWell(
                            onTap: () {
                              setState(() {
                                _selectedCategory = category;
                              });
                            },
                            borderRadius: BorderRadius.circular(15),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              decoration: BoxDecoration(
                                color: isSelected ? category['color'] : (isDark ? Colors.grey.shade800 : Colors.white),
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(
                                  color: isSelected ? category['color'] : Colors.grey.shade300,
                                  width: isSelected ? 3 : 1,
                                ),
                                boxShadow: [
                                  if (isSelected)
                                    BoxShadow(color: category['color'].withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 5))
                                ],
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.wifi, size: 30, color: isSelected ? Colors.white : category['color']),
                                  const SizedBox(height: 10),
                                  Text(
                                    category['name'],
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isSelected ? Colors.white : (isDark ? Colors.white : Colors.black87)),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    '${category['price']} ريال',
                                    style: TextStyle(fontSize: 14, color: isSelected ? Colors.white70 : Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ==========================================
            // 3. زر البيع السفلي (يظهر فقط عند اختيار فئة)
            // ==========================================
            if (_selectedCategory != null)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade900 : Colors.white,
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('الإجمالي المطلوب:', style: TextStyle(color: Colors.grey, fontSize: 14)),
                          Text('${_selectedCategory!['price']} ريال', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: Colors.green)),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: 55,
                        child: ElevatedButton.icon(
                          onPressed: _showConfirmSaleDialog,
                          icon: const Icon(Icons.point_of_sale, color: Colors.white, size: 24),
                          label: const Text('بيع الكرت الآن', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal.shade700,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
