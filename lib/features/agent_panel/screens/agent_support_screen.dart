import 'package:flutter/material.dart';
// استدعاء الترويسة العلوية والقائمة الجانبية للوكيل
import '../../../core/widgets/custom_header.dart';
import '../widgets/custom_agent_drawer.dart';

class AgentSupportScreen extends StatefulWidget {
  const AgentSupportScreen({super.key});

  @override
  State<AgentSupportScreen> createState() => _AgentSupportScreenState();
}

class _AgentSupportScreenState extends State<AgentSupportScreen> {
  // قاعدة بيانات وهمية لتذاكر الدعم الفني السابقة
  final List<Map<String, dynamic>> _supportTickets = [
    {'id': '#1045', 'subject': 'تأخر وصول رصيد محفظة جوالي', 'date': '2026-03-23', 'status': 'مفتوحة 🟢', 'color': Colors.green},
    {'id': '#0982', 'subject': 'استفسار عن عمولة الباقات الجديدة', 'date': '2026-03-20', 'status': 'قيد المعالجة 🟠', 'color': Colors.orange},
    {'id': '#0850', 'subject': 'مشكلة في طباعة كرت ميكروتك', 'date': '2026-03-15', 'status': 'مغلقة 🔴', 'color': Colors.grey},
  ];

  // ==========================================
  // نافذة فتح تذكرة دعم جديدة 🎫
  // ==========================================
  void _showCreateTicketDialog() {
    String subject = '';
    String description = '';

    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Row(
            children: [
              Icon(Icons.support_agent, color: Colors.blueAccent),
              SizedBox(width: 8),
              Text('فتح تذكرة دعم جديدة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('اشرح مشكلتك بوضوح وسيقوم فريق الدعم بالرد عليك في أقرب وقت.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 15),
                // حقل عنوان المشكلة
                TextField(
                  onChanged: (val) => subject = val,
                  decoration: InputDecoration(
                    labelText: 'عنوان المشكلة (مختصر)',
                    prefixIcon: const Icon(Icons.title),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 12),
                // حقل تفاصيل المشكلة
                TextField(
                  onChanged: (val) => description = val,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: 'تفاصيل المشكلة',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), 
              child: const Text('إلغاء', style: TextStyle(color: Colors.red))
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                if (subject.isNotEmpty && description.isNotEmpty) {
                  // إضافة التذكرة الجديدة إلى القائمة
                  setState(() {
                    _supportTickets.insert(0, {
                      'id': '#1046', // محاكاة لرقم تذكرة جديد
                      'subject': subject,
                      'date': 'الآن',
                      'status': 'مفتوحة 🟢',
                      'color': Colors.green,
                    });
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم إرسال تذكرتك بنجاح! سنتواصل معك قريباً.'), backgroundColor: Colors.green)
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('يرجى تعبئة جميع الحقول!'), backgroundColor: Colors.red)
                  );
                }
              },
              child: const Text('إرسال التذكرة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: const CustomHeader(title: 'الدعم الفني الموحد'),
      drawer: const CustomAgentDrawer(
        agentName: 'شبكة الصقر للواي فاي',
        phoneNumber: '777777777',
        role: 'وكيل معتمد (Agent)',
        currentBalance: 125000.0,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            // 1. بطاقات التواصل السريع (اتصال / واتساب)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade900 : Colors.blue.shade50,
                borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  const Text('نحن هنا لمساعدتك! تواصل معنا عبر:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('جاري فتح واتساب الدعم الفني...')));
                          },
                          icon: const Icon(Icons.chat, color: Colors.white),
                          label: const Text('واتساب', style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, padding: const EdgeInsets.symmetric(vertical: 12)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('جاري الاتصال بخدمة العملاء...')));
                          },
                          icon: const Icon(Icons.phone, color: Colors.white),
                          label: const Text('اتصال مباشر', style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, padding: const EdgeInsets.symmetric(vertical: 12)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),

            // 2. زر إضافة تذكرة جديدة
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _showCreateTicketDialog,
                  icon: const Icon(Icons.add_circle_outline, color: Colors.blueAccent),
                  label: const Text('فتح تذكرة دعم جديدة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blueAccent)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    side: const BorderSide(color: Colors.blueAccent, width: 2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),
            
            // 3. قائمة التذاكر السابقة
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text('سجل التذاكر السابقة:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blueGrey)),
              ),
            ),
            
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _supportTickets.length,
                itemBuilder: (context, index) {
                  final ticket = _supportTickets[index];
                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(12),
                      leading: CircleAvatar(
                        backgroundColor: ticket['color'].withOpacity(0.1),
                        child: Icon(Icons.receipt_long, color: ticket['color']),
                      ),
                      title: Text(ticket['subject'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('رقم التذكرة: ${ticket['id']}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                            Text(ticket['date'], style: const TextStyle(color: Colors.grey, fontSize: 12)),
                          ],
                        ),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: ticket['color'].withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(ticket['status'], style: TextStyle(color: ticket['color'], fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
