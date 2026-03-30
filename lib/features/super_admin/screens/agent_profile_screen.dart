import 'package:flutter/material.dart';
import '../../../core/widgets/custom_header.dart'; // استدعاء الترويسة الموحدة

class AgentProfileScreen extends StatefulWidget {
  final Map<String, dynamic> agentData; // استقبال بيانات الوكيل من الشاشة السابقة

  const AgentProfileScreen({super.key, required this.agentData});

  @override
  State<AgentProfileScreen> createState() => _AgentProfileScreenState();
}

// استخدام SingleTickerProviderStateMixin ضروري جداً لعمل حركات التبويبات (Animations)
class _AgentProfileScreenState extends State<AgentProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // 1. بيانات المبيعات العامة (تجريبية لعرض التصميم)
  final Map<String, dynamic> _salesData = {
    'totalCardsSold': 1250,
    'totalSalesValue': '1,250,000 ريال',
    'agentDirectSales': '450,000 ريال',
    'posTotalSales': '800,000 ريال',
    'profitRate': '5%',
    'totalAvailableCards': 3400, 
  };

  // 2. بيانات الفئات والمخزون للوكيل (تجريبية)
  final List<Map<String, dynamic>> _categories = [
    {'name': 'يمن موبايل - فئة 1000', 'available': 1500, 'sold': 450, 'color': Colors.blue},
    {'name': 'سبأفون - فئة 1000', 'available': 800, 'sold': 300, 'color': Colors.orange},
    {'name': 'يو (YOU) - فئة 500', 'available': 1100, 'sold': 500, 'color': Colors.green},
  ];

  // 3. بيانات نقاط البيع (البقالات) المعقدة (تجريبية)
  final List<Map<String, dynamic>> _posDetails = [
    {
      'name': 'بقالة الأمانة',
      'location': 'شارع جمال',
      'totalSales': '350,000 ريال',
      'inventory': [
        {'cat': 'يمن موبايل 1000', 'available': 200, 'sold': 150},
        {'cat': 'سبأفون 1000', 'available': 50, 'sold': 80},
      ]
    },
    {
      'name': 'ميدالية التوفيق',
      'location': 'الحصب',
      'totalSales': '450,000 ريال',
      'inventory': [
        {'cat': 'يمن موبايل 1000', 'available': 100, 'sold': 220},
        {'cat': 'يو (YOU) 500', 'available': 300, 'sold': 400},
      ]
    },
  ];

  @override
  void initState() {
    super.initState();
    // تهيئة متحكم التبويبات (3 تبويبات)
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    // تنظيف الذاكرة عند إغلاق الشاشة لتجنب تسريب الذاكرة (Memory Leak)
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // 👈 حماية أمان: جلب أول حرف من الاسم، وإذا كان الاسم فارغاً نضع '?' لتجنب انهيار التطبيق
    final String agentName = widget.agentData['name'] ?? 'غير معروف';
    final String nameInitial = agentName.trim().isNotEmpty ? agentName.trim().substring(0, 1) : '?';

    return Scaffold(
      appBar: const CustomHeader(title: 'الملف الشامل للوكيل'),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            // ==========================================
            // بطاقة هوية الوكيل العلوية (ثابتة في كل التبويبات)
            // ==========================================
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade900 : Colors.blue.shade900,
                borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white24,
                    child: Text(nameInitial, style: const TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(agentName, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                        Text('${widget.agentData['network']} | الهاتف: ${widget.agentData['phone']}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            const Icon(Icons.account_balance_wallet, color: Colors.greenAccent, size: 16),
                            const SizedBox(width: 5),
                            Text('الرصيد: ${widget.agentData['balance']} ريال', style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      Chip(
                        label: Text(widget.agentData['status'], style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                        backgroundColor: widget.agentData['status'] == 'نشط' ? Colors.green : Colors.red,
                      ),
                    ],
                  )
                ],
              ),
            ),

            // ==========================================
            // شريط التبويبات القابل للتنقل
            // ==========================================
            Container(
              color: Colors.transparent,
              child: TabBar(
                controller: _tabController,
                labelColor: Colors.blueAccent,
                unselectedLabelColor: Colors.grey,
                indicatorColor: Colors.blueAccent,
                indicatorWeight: 3,
                tabs: const [
                  Tab(icon: Icon(Icons.analytics), text: 'مبيعات'),
                  Tab(icon: Icon(Icons.inventory_2), text: 'مخزون'),
                  Tab(icon: Icon(Icons.store), text: 'بقالات'),
                ],
              ),
            ),

            // ==========================================
            // محتوى التبويبات المتغير
            // ==========================================
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildSalesOverviewTab(),
                  _buildInventoryTab(),
                  _buildPosTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // التبويب الأول: المبيعات والنظرة العامة
  // ==========================================
  Widget _buildSalesOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Colors.blue.shade800, Colors.blue.shade500]),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('إجمالي المبيعات الدقيقة', style: TextStyle(color: Colors.white70, fontSize: 14)),
                    const SizedBox(height: 5),
                    Text('${_salesData['totalCardsSold']} كرت', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  ],
                ),
                const Text('=', style: TextStyle(color: Colors.white54, fontSize: 30)),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('القيمة المالية', style: TextStyle(color: Colors.white70, fontSize: 14)),
                    const SizedBox(height: 5),
                    Text(_salesData['totalSalesValue'], style: const TextStyle(color: Colors.greenAccent, fontSize: 20, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          const Text('تفصيل مصدر المبيعات:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _buildStatCard('مبيعات الوكيل', _salesData['agentDirectSales'], Icons.person, Colors.orange)),
              const SizedBox(width: 10),
              Expanded(child: _buildStatCard('نقاط البيع (${_posDetails.length})', _salesData['posTotalSales'], Icons.storefront, Colors.purple)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
               Expanded(child: _buildStatCard('نسبة العمولة', _salesData['profitRate'], Icons.percent, Colors.green)),
               const SizedBox(width: 10),
               Expanded(child: _buildStatCard('الكروت المتوفرة', '${_salesData['totalAvailableCards']}', Icons.inventory, Colors.blueGrey)),
            ],
          )
        ],
      ),
    );
  }

  // ==========================================
  // التبويب الثاني: المخزون والفئات
  // ==========================================
  Widget _buildInventoryTab() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.blueGrey.withOpacity(0.1),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('إجمالي الكروت في جميع الفئات:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('${_salesData['totalAvailableCards']} كرت', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 16)),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _categories.length,
            itemBuilder: (context, index) {
              final cat = _categories[index];
              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: cat['color'].withOpacity(0.3))),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(cat['name'], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: cat['color'])),
                          Icon(Icons.category, color: cat['color'].withOpacity(0.5)),
                        ],
                      ),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              const Text('المتوفر حالياً', style: TextStyle(color: Colors.grey, fontSize: 12)),
                              Text('${cat['available']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green)),
                            ],
                          ),
                          Container(height: 30, width: 1, color: Colors.grey.withOpacity(0.3)),
                          Column(
                            children: [
                              const Text('المباع', style: TextStyle(color: Colors.grey, fontSize: 12)),
                              Text('${cat['sold']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.orange)),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ==========================================
  // التبويب الثالث: نقاط البيع (البقالات) المعقدة
  // ==========================================
  Widget _buildPosTab() {
    if (_posDetails.isEmpty) {
      return const Center(child: Text('لا توجد نقاط بيع (بقالات) تابعة لهذا الوكيل.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _posDetails.length,
      itemBuilder: (context, index) {
        final pos = _posDetails[index];
        final List inventory = pos['inventory'];

        return Card(
          elevation: 3,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: ExpansionTile( 
            iconColor: Colors.blueAccent,
            collapsedIconColor: Colors.grey,
            title: Text(pos['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            subtitle: Text('الموقع: ${pos['location']} | إجمالي المبيعات: ${pos['totalSales']}', style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
            leading: const CircleAvatar(backgroundColor: Colors.blueAccent, child: Icon(Icons.store, color: Colors.white)),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.black12 : Colors.grey.shade50,
                  borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(15), bottomRight: Radius.circular(15)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('تفاصيل الفئات المتوفرة في هذه النقطة:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 10),
                    // جدول داخلي يعرض بيانات المخزون
                    Table(
                      border: TableBorder.all(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(8)),
                      columnWidths: const {0: FlexColumnWidth(2), 1: FlexColumnWidth(1), 2: FlexColumnWidth(1)},
                      children: [
                        TableRow(
                          decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1)),
                          children: const [
                            Padding(padding: EdgeInsets.all(8.0), child: Text('الفئة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                            Padding(padding: EdgeInsets.all(8.0), child: Text('متوفر', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center)),
                            Padding(padding: EdgeInsets.all(8.0), child: Text('مباع', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center)),
                          ],
                        ),
                        // دمج بيانات المخزون داخل الجدول برمجياً (Spread Operator)
                        ...inventory.map((inv) {
                          return TableRow(
                            children: [
                              Padding(padding: const EdgeInsets.all(8.0), child: Text(inv['cat'], style: const TextStyle(fontSize: 12))),
                              Padding(padding: const EdgeInsets.all(8.0), child: Text('${inv['available']}', style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                              Padding(padding: const EdgeInsets.all(8.0), child: Text('${inv['sold']}', style: const TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                            ],
                          );
                        }).toList(),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // أداة بناء البطاقات الإحصائية الصغيرة بأسلوب نظيف (Clean Code)
  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }
}
