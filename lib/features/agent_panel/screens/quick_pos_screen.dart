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
  
  // 👇 المتغير الجديد الخاص بالكمية المطلوبة
  int _quantity = 1;

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

    int totalPrice = _selectedCategory!['price'] * _quantity;

    showDialog(
      context: context,
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            title: const Text('تأكيد البيع 🛒', style: TextStyle(fontWeight: FontWeight.bold)),
            content: Text(
              'هل أنت متأكد من خصم مبلغ $totalPrice ريال من محفظتك لبيع عدد ($_quantity) كرت من (${_selectedCategory!['name']})؟',
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
                  _processSale(totalPrice); // تنفيذ البيع
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
  // دالة معالجة البيع وعرض نافذة الكروت الجديدة
  // ==========================================
  void _processSale(int totalPrice) {
    setState(() {
      _walletBalance -= totalPrice; // خصم الإجمالي من المحفظة
    });

    // توليد أرقام كروت وهمية بحسب الكمية المطلوبة
    List<String> generatedPins = List.generate(_quantity, (index) => "8472 9102 334${index + 1}");

    showDialog(
      context: context,
      barrierDismissible: false, // لا يمكن إغلاقها بالنقر خارجها
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 50),
                  const SizedBox(height: 10),
                  const Text('تمت عملية البيع بنجاح!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green)),
                  Text('تم إصدار ($_quantity) كرت', style: const TextStyle(color: Colors.grey, fontSize: 14)),
                  const SizedBox(height: 15),
                  
                  // 👇 عرض الكروت المشتراة داخل قائمة قابلة للتمرير (تحسباً للكميات الكبيرة)
                  Flexible(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 250),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: generatedPins.length,
                        itemBuilder: (context, index) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _selectedCategory!['color'].withOpacity(0.05),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: _selectedCategory!['color'].withOpacity(0.3), width: 1.5),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(_selectedCategory!['name'], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _selectedCategory!['color'])),
                                    Text('كرت #${index + 1}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                  ],
                                ),
                                const Divider(),
                                Text(generatedPins[index], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, letterSpacing: 2)),
                                const SizedBox(height: 5),
                                Text('الوقت: ${_selectedCategory!['time']}', style: const TextStyle(fontSize: 11)),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 15),
                  
                  // أزرار المشاركة والطباعة
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildActionButton(Icons.share, 'مشاركة الكل', Colors.blue, () {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('جاري فتح واتساب...')));
                      }),
                      _buildActionButton(Icons.print, 'طباعة الكل', Colors.orange, () {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('جاري الإرسال للطابعة بلوتوث...')));
                      }),
                    ],
                  ),
                  
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      setState(() {
                        _selectedCategory = null; // إعادة التعيين
                        _quantity = 1; // إرجاع الكمية لـ 1
                      });
                    },
                    child: const Text('إغلاق وبدء بيع جديد', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                  )
                ],
              ),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11)),
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
                                _quantity = 1; // إرجاع الكمية إلى 1 عند تغيير الفئة
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
            // 3. قسم البيع السفلي (يظهر فقط عند اختيار فئة)
            // ==========================================
            if (_selectedCategory != null)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade900 : Colors.white,
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  children: [
                    // 👇 صف التحكم بالكمية (+ و -)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('الكمية المطلوبة:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove, color: Colors.red),
                                onPressed: () {
                                  if (_quantity > 1) {
                                    setState(() => _quantity--);
                                  }
                                },
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 15),
                                child: Text('$_quantity', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add, color: Colors.green),
                                onPressed: () {
                                  setState(() => _quantity++);
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 30),
                    
                    // 👇 صف الإجمالي وزر البيع
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('الإجمالي المطلوب:', style: TextStyle(color: Colors.grey, fontSize: 14)),
                              // حساب الإجمالي تلقائياً
                              Text('${_selectedCategory!['price'] * _quantity} ريال', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: Colors.green)),
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
                              label: const Text('بيع الآن', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal.shade700,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                              ),
                            ),
                          ),
                        ),
                      ],
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
