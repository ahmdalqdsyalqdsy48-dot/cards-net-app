import 'package:flutter/material.dart';
import '../../../core/widgets/custom_header.dart';
import '../../../core/widgets/custom_drawer.dart';

class FinancialCenterScreen extends StatefulWidget {
  const FinancialCenterScreen({super.key});

  @override
  State<FinancialCenterScreen> createState() => _FinancialCenterScreenState();
}

class _FinancialCenterScreenState extends State<FinancialCenterScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    // إعداد 3 تبويبات للصفحة
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomHeader(
        title: 'المركز المالي والمحافظ',
        isOnline: true,
      ),
      drawer: const CustomDrawer(
        userName: 'مالك النظام',
        phoneNumber: '774578241',
        role: 'مالك النظام (Super Admin)',
        balanceOrPoints: 'أرباح النظام: 5,430,000 ريال',
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            // === شريط التبويبات العلوي ===
            Container(
              color: Theme.of(context).primaryColor.withOpacity(0.05),
              child: TabBar(
                controller: _tabController,
                labelColor: Colors.blueAccent,
                unselectedLabelColor: Colors.grey,
                indicatorColor: Colors.blueAccent,
                indicatorWeight: 3,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                tabs: const [
                  Tab(icon: Icon(Icons.download_rounded), text: 'طلبات الشحن'),
                  Tab(icon: Icon(Icons.account_balance_wallet), text: 'أرصدة المحافظ'),
                  Tab(icon: Icon(Icons.history), text: 'سجل الحركات'),
                ],
              ),
            ),

            // === محتوى التبويبات ===
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildPendingRequestsTab(), // التبويب الأول
                  _buildWalletsBalancesTab(), // التبويب الثاني
                  _buildTransactionsHistoryTab(), // التبويب الثالث
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // 1. التبويب الأول: طلبات الشحن (الحوالات الواردة)
  // ==========================================
  Widget _buildPendingRequestsTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 2, // عدد الطلبات الوهمية
      itemBuilder: (context, index) {
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('الوكيل: شبكة الصقر', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text('منذ 10 دقائق', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                  ],
                ),
                const Divider(),
                const Text('المبلغ المحول: 50,000 ريال', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                const Text('البنك: بنك الكريمي | المرجع: 12345678'),
                const SizedBox(height: 10),
                // أزرار القبول والرفض
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.check_circle, color: Colors.white),
                        label: const Text('تأكيد الشحن', style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.cancel, color: Colors.red),
                        label: const Text('رفض', style: TextStyle(color: Colors.red)),
                        style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        );
      },
    );
  }

  // ==========================================
  // 2. التبويب الثاني: أرصدة المحافظ (مراقبة وتسوية)
  // ==========================================
  Widget _buildWalletsBalancesTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 3,
      itemBuilder: (context, index) {
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          tileColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.grey.shade200)),
          leading: const CircleAvatar(backgroundColor: Colors.blueAccent, child: Icon(Icons.wallet, color: Colors.white)),
          title: Text('وكيل ${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text('الرصيد: ${(index + 1) * 20000} ريال', style: const TextStyle(color: Colors.purple, fontWeight: FontWeight.bold)),
          trailing: IconButton(
            icon: const Icon(Icons.settings_suggest, color: Colors.orange),
            tooltip: 'تسوية يدوية',
            onPressed: () {
              // نافذة التسوية اليدوية تظهر هنا
            },
          ),
        );
      },
    );
  }

  // ==========================================
  // 3. التبويب الثالث: سجل الحركات (Audit Log المالي)
  // ==========================================
  Widget _buildTransactionsHistoryTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text('سجل الحركات المالية يظهر هنا', style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
        ],
      ),
    );
  }
}
