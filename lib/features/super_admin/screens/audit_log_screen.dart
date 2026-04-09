import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; 

import '../../../core/providers/system_provider.dart'; 
import '../../../core/widgets/custom_drawer.dart';
import '../../../core/widgets/custom_header.dart'; 

class AuditLogScreen extends StatefulWidget {
  const AuditLogScreen({super.key});

  @override
  State<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends State<AuditLogScreen> {
  // === متغيرات الفلترة والبحث ===
  String _searchQuery = '';
  String? _selectedActionType; // لحفظ نوع العملية المحدد
  DateTimeRange? _selectedDateRange; // لحفظ نطاق التاريخ المحدد

  // قائمة بأنواع العمليات (يمكنك تعديلها لتطابق ما يأتيك من قاعدة البيانات)
  final List<String> _actionTypes = ['الكل', 'إضافة', 'تعديل', 'حذف', 'تسجيل دخول', 'تغيير صلاحيات'];

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

  // 👈 دالة اختيار نطاق التاريخ
  Future<void> _pickDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020), // أقدم تاريخ ممكن
      lastDate: DateTime.now(),  // لا يمكن اختيار تاريخ في المستقبل
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.blueGrey, // لون الهيدر
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: child!,
          ),
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
      });
    }
  }

  // 👈 دالة اختيار نوع العملية من قائمة منبثقة (Bottom Sheet)
  void _showActionFilterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('تصفية حسب نوع العملية', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Divider(),
                Wrap(
                  spacing: 8.0,
                  children: _actionTypes.map((type) {
                    final isSelected = (_selectedActionType == type) || (_selectedActionType == null && type == 'الكل');
                    return ChoiceChip(
                      label: Text(type),
                      selected: isSelected,
                      selectedColor: Colors.blueGrey.withOpacity(0.3),
                      onSelected: (selected) {
                        setState(() {
                          _selectedActionType = type == 'الكل' ? null : type;
                        });
                        Navigator.pop(context);
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final systemProvider = Provider.of<SystemProvider>(context);
    
    final double adminBalance = systemProvider.adminMainBalance;
    final String userName = systemProvider.currentUserName;
    final String userPhone = systemProvider.currentUserPhone;

    final List<Map<String, dynamic>> realAuditLogs = systemProvider.auditLogs;

    // 👈 3. دالة البحث والفلترة الذكية (النص + النوع + التاريخ)
    final filteredLogs = realAuditLogs.where((log) {
      // أ. فلترة النص
      final query = _searchQuery.toLowerCase();
      final name = (log['name'] ?? '').toString().toLowerCase();
      final phone = (log['phone'] ?? '').toString().toLowerCase();
      final action = (log['action'] ?? '').toString().toLowerCase();
      
      final matchesSearch = name.contains(query) || phone.contains(query) || action.contains(query);

      // ب. فلترة نوع العملية
      bool matchesActionType = true;
      if (_selectedActionType != null) {
        matchesActionType = action.contains(_selectedActionType!.toLowerCase());
      }

      // ج. فلترة التاريخ
      bool matchesDate = true;
      if (_selectedDateRange != null) {
        try {
          final logDate = DateTime.parse(log['datetime'] ?? ''); // يفترض أن التاريخ بصيغة ISO
          // التأكد أن التاريخ يقع ضمن النطاق (مع تجاهل الوقت)
          matchesDate = logDate.isAfter(_selectedDateRange!.start.subtract(const Duration(days: 1))) &&
                        logDate.isBefore(_selectedDateRange!.end.add(const Duration(days: 1)));
        } catch (e) {
          // إذا كان هناك خطأ في صيغة التاريخ في قاعدة البيانات نعرضه افتراضياً
          matchesDate = true; 
        }
      }

      return matchesSearch && matchesActionType && matchesDate;
    }).toList();

    return Scaffold(
      appBar: const CustomHeader(title: 'السجل الأسود للنشاط'),
      
      drawer: CustomDrawer(
        userName: userName,
        phoneNumber: userPhone,
        role: 'مالك النظام (Super Admin)',
        balanceOrPoints: 'أرباح النظام: ${adminBalance.toStringAsFixed(0)} ريال',
      ),
      
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            // === 1. أدوات الفلترة والبحث السريع ===
            Container(
              padding: const EdgeInsets.all(16.0),
              color: Colors.transparent, 
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          onChanged: (value) {
                            setState(() {
                              _searchQuery = value;
                            });
                          },
                          decoration: InputDecoration(
                            hintText: 'ابحث برقم الهاتف، أو الاسم...',
                            prefixIcon: const Icon(Icons.search, color: Colors.blueAccent),
                            filled: true,
                            fillColor: Theme.of(context).cardColor, 
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
                            ),
                            contentPadding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // زر الطباعة (الوحيد الذي تركناه SnackBar مؤقتاً حتى نقوم ببرمجة دالة الـ PDF)
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.blueGrey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.print, color: Colors.blueGrey),
                          tooltip: 'طباعة السجل المنظم',
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('جاري تجهيز السجل للطباعة الرسمية والتوثيق... 🖨️', textDirection: TextDirection.rtl), backgroundColor: Colors.blueGrey)
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      // زر فلترة نوع العملية (تم التفعيل ✅)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showActionFilterSheet(context),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: _selectedActionType != null ? Colors.blue.withOpacity(0.1) : null,
                            side: BorderSide(color: _selectedActionType != null ? Colors.blue : Colors.grey),
                          ),
                          icon: Icon(Icons.filter_list, size: 16, color: _selectedActionType != null ? Colors.blue : null),
                          label: Text(
                            _selectedActionType ?? 'نوع العملية',
                            style: TextStyle(color: _selectedActionType != null ? Colors.blue : null),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // زر فلترة التاريخ (تم التفعيل ✅)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pickDateRange(context),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: _selectedDateRange != null ? Colors.blue.withOpacity(0.1) : null,
                            side: BorderSide(color: _selectedDateRange != null ? Colors.blue : Colors.grey),
                          ),
                          icon: Icon(Icons.date_range, size: 16, color: _selectedDateRange != null ? Colors.blue : null),
                          label: Text(
                            _selectedDateRange != null 
                              ? '${_selectedDateRange!.start.day}/${_selectedDateRange!.start.month} - ${_selectedDateRange!.end.day}/${_selectedDateRange!.end.month}'
                              : 'تاريخ محدد',
                            style: TextStyle(color: _selectedDateRange != null ? Colors.blue : null, fontSize: 12),
                          ),
                        ),
                      ),
                      // زر لمسح الفلاتر إذا كانت مفعلة
                      if (_selectedActionType != null || _selectedDateRange != null)
                        IconButton(
                          icon: const Icon(Icons.clear, color: Colors.red),
                          tooltip: 'إلغاء الفلاتر',
                          onPressed: () {
                            setState(() {
                              _selectedActionType = null;
                              _selectedDateRange = null;
                            });
                          },
                        )
                    ],
                  ),
                ],
              ),
            ),

            // === 2. التنبيه الأمني الصارم (الشريط الأحمر) ===
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              color: Colors.red.withOpacity(0.1),
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

            // === 3. جدول المراقبة الشامل ===
            Expanded(
              child: filteredLogs.isEmpty 
                ? const Center(child: Text('لا توجد سجلات حالياً، أو لا يوجد تطابق للبحث.', style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: filteredLogs.length,
                itemBuilder: (context, index) {
                  final log = filteredLogs[index];
                  final severity = log['severity'] ?? 'normal';
                  final color = _getSeverityColor(severity);
                  final icon = _getSeverityIcon(severity);

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
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Row(
                                          children: [
                                            Icon(icon, color: color, size: 18),
                                            const SizedBox(width: 6),
                                            Expanded(child: Text(log['action'] ?? 'إجراء غير معروف', style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14), overflow: TextOverflow.ellipsis)),
                                          ],
                                        ),
                                      ),
                                      Text(log['datetime'] ?? '', style: const TextStyle(color: Colors.grey, fontSize: 11), textDirection: TextDirection.ltr),
                                    ],
                                  ),
                                  const Divider(height: 16),
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(5)
                                    ),
                                    child: Text(log['details'] ?? 'لا توجد تفاصيل', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('بواسطة: ${log['name'] ?? 'مجهول'}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                          Text('${log['role'] ?? ''} | ${log['phone'] ?? ''}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                        ],
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                                        child: Text('IP: ${log['ip'] ?? 'Cloud'}', style: const TextStyle(fontSize: 11, color: Colors.blueGrey, letterSpacing: 1)),
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
