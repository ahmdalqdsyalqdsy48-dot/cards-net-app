import 'package:flutter/material.dart';
import '../../../core/widgets/custom_drawer.dart';

class AuditLogScreen extends StatefulWidget {
  const AuditLogScreen({super.key});

  @override
  State<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends State<AuditLogScreen> {
  // قاعدة بيانات وهمية للسجل الأسود (غير قابلة للحذف)
  final List<Map<String, dynamic>> _auditLogs = [
    {
      'name': 'مالك النظام',
      'phone': '774578241',
      'role': 'Super Admin',
      'action': 'تعديل رصيد محفظة يدوياً',
      'details': 'القيمة السابقة: 10,000 ريال ⬅️ القيمة الجديدة: 15,000 ريال',
      'datetime': '2026-03-23 14:30:15',
      'ip': '192.168.1.5',
      'severity': 'critical', // أحمر
    },
    {
      'name': 'محمود المالي',
      'phone': '771122334',
      'role': 'محاسب',
      'action': 'إضافة وكيل جديد',
      'details': 'تم إضافة وكيل باسم "شبكة التميز"',
      'datetime': '2026-03-23 10:15:00',
      'ip': '10.0.0.12',
      'severity': 'medium', // أصفر
    },
    {
      'name': 'النظام الآلي',
      'phone': 'Auto',
      'role': 'System Bot',
      'action': 'خصم عمولة وتجديد اشتراك',
      'details': 'تم خصم 2,500 ريال من محفظة "وكالة النور"',
      'datetime': '2026-03-23 00:01:05',
      'ip': 'Localhost',
      'severity': 'normal', // أخضر
    },
  ];

  // دالة لتحديد لون الخطورة بناءً على نوع العملية
  Color _getSeverityColor(String severity) {
    switch (severity) {
      case 'critical': return Colors.red;
      case 'medium': return Colors.orange;
      case 'normal': default: return Colors.green;
    }
  }

  // دالة لتحديد أيقونة الخطورة
  IconData _getSeverityIcon(String severity) {
    switch (severity) {
      case 'critical': return Icons.warning_rounded;
      case 'medium': return Icons.info_outline;
      case 'normal': default: return Icons.check_circle_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('السجل الأسود للنشاط', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 2,
        iconTheme: const IconThemeData(color: Colors.blueAccent),
        actions: [
          // زر الطباعة الرسمي
          IconButton(
            icon: const Icon(Icons.print, color: Colors.blueGrey),
            tooltip: 'طباعة السجل المنظم',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('جاري تجهيز السجل للطباعة الرسمية والتوثيق...'), backgroundColor: Colors.blueGrey)
              );
            },
          ),
        ],
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
            // === 1. أدوات الفلترة والبحث السريع ===
            Container(
              padding: const EdgeInsets.all(16.0),
              color: Colors.grey.shade50,
              child: Column(
                children: [
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'ابحث برقم الهاتف، أو اسم الموظف / الوكيل...',
                      prefixIcon: const Icon(Icons.search, color: Colors.blueAccent),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.filter_list, size: 16),
                          label: const Text('نوع العملية'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.date_range, size: 16),
                          label: const Text('تاريخ محدد'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // === 2. التنبيه الأمني الصارم (الشريط الأحمر) ===
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              color: Colors.red.shade50,
              child: const Row(
                children: [
                  Icon(Icons.security, color: Colors.red, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'هذا السجل للقراءة والمراقبة فقط. لا يمكن لأي موظف أو مدير تعديل أو حذف هذه السجلات نهائياً.',
                      style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),

            // === 3. جدول المراقبة الشامل (The Immutable Ledger) ===
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _auditLogs.length,
                itemBuilder: (context, index) {
                  final log = _auditLogs[index];
                  final color = _getSeverityColor(log['severity']);
                  final icon = _getSeverityIcon(log['severity']);

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: color.withOpacity(0.5), width: 1),
                    ),
                    child: IntrinsicHeight(
                      child: Row(
                        children: [
                          // شريط اللون الجانبي لبيان الخطورة (أحمر، أصفر، أخضر)
                          Container(
                            width: 8,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: const BorderRadius.horizontal(right: Radius.circular(10)),
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // الرأس: الإجراء والوقت
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(icon, color: color, size: 18),
                                          const SizedBox(width: 6),
                                          Text(log['action'], style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14)),
                                        ],
                                      ),
                                      Text(log['datetime'], style: const TextStyle(color: Colors.grey, fontSize: 11), textDirection: TextDirection.ltr),
                                    ],
                                  ),
                                  const Divider(height: 16),
                                  // تفاصيل القيمة السابقة والجديدة
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    width: double.infinity,
                                    decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(5)),
                                    child: Text(log['details'], style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87)),
                                  ),
                                  const SizedBox(height: 10),
                                  // بيانات المستخدم والـ IP
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('بواسطة: ${log['name']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                          Text('${log['role']} | ${log['phone']}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                        ],
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(4)),
                                        child: Text('IP: ${log['ip']}', style: const TextStyle(fontSize: 11, color: Colors.blueGrey, letterSpacing: 1)),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
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
    );
  }
}
