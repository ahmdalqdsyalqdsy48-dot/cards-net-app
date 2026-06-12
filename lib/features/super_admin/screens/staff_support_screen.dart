import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/providers/wallet_provider.dart';
import '../../../core/providers/ui_provider.dart';
import '../../../core/widgets/custom_drawer.dart';
import '../../../core/widgets/custom_header.dart';

class StaffSupportScreen extends StatefulWidget {
  const StaffSupportScreen({super.key});

  @override
  State<StaffSupportScreen> createState() => _StaffSupportScreenState();
}

class _StaffSupportScreenState extends State<StaffSupportScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        context.read<UiProvider>().playSound('click');
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  bool _can(String permission) {
    final auth = context.read<AuthProvider>();
    return auth.currentUserRole == 'super_admin' || auth.hasPermission(permission);
  }

  // ==========================================
  // 1. نافذة إضافة/تعديل موظف (سلوك التحديد الجديد)
  // ==========================================
  void _showStaffDialog({Map<String, dynamic>? existingData}) {
    context.read<UiProvider>().playSound('click');

    final nameController = TextEditingController(text: existingData?['name'] ?? '');
    final phoneController = TextEditingController(text: existingData?['phone'] ?? '');
    final salaryController = TextEditingController(
      text: existingData?['salary']?.toString().replaceAll(' ريال', '') ?? '',
    );
    final passwordController = TextEditingController();

    final Map<String, dynamic> sections = {
      'الرئيسية (غرفة العمليات)': {
        'icon': Icons.dashboard,
        'tabs': {
          'عام': {
            'الرئيسية (غرفة العمليات)': 'الرئيسية (غرفة العمليات)',
          }
        }
      },
      'إدارة الوكلاء': {
        'icon': Icons.people_alt,
        'tabs': {
          'الوكلاء': {
            'عرض الوكلاء': 'عرض الوكلاء',
            'إضافة وكيل': 'إضافة وكيل',
            'تعديل وكيل': 'تعديل وكيل',
            'حذف وكيل': 'حذف وكيل',
            'تجميد/تنشيط وكيل': 'تجميد/تنشيط وكيل',
          }
        }
      },
      'إدارة الاشتراكات': {
        'icon': Icons.event_available,
        'tabs': {
          'الاشتراكات': {
            'عرض الاشتراكات': 'عرض الاشتراكات',
            'تعديل الاشتراكات': 'تعديل الاشتراكات',
          }
        }
      },
      'المركز المالي والمحافظ': {
        'icon': Icons.account_balance_wallet,
        'tabs': {
          'المالية': {
            'عرض الأرصدة': 'عرض الأرصدة',
            'تسوية رصيد': 'تسوية رصيد',
            'عرض المعاملات': 'عرض المعاملات',
          }
        }
      },
      'الحسابات البنكية': {
        'icon': Icons.account_balance,
        'tabs': {
          'الحسابات': {
            'عرض الحسابات': 'عرض الحسابات',
            'إضافة حساب': 'إضافة حساب',
            'تعديل حساب': 'تعديل حساب',
            'حذف حساب': 'حذف حساب',
          }
        }
      },
      'إدارة أرقام الحسابات والحظر': {
        'icon': Icons.credit_card,
        'tabs': {
          'الحسابات': {
            'عرض الحسابات': 'عرض الحسابات',
            'تعديل رقم حساب': 'تعديل رقم حساب',
            'حظر/فك حظر': 'حظر/فك حظر',
            'إعادة تعيين PIN': 'إعادة تعيين PIN',
          }
        }
      },
      'التقارير الشاملة': {
        'icon': Icons.analytics,
        'tabs': {
          'التقارير': {
            'عرض التقارير': 'عرض التقارير',
          }
        }
      },
      'إدارة بوابات النظام': {
        'icon': Icons.important_devices,
        'tabs': {
          'البوابات': {
            'عرض البوابات': 'عرض البوابات',
            'تعديل البوابات': 'تعديل البوابات',
          }
        }
      },
      'إدارة الموظفين والدعم': {
        'icon': Icons.support_agent,
        'tabs': {
          'الموظفين والصلاحيات': {
            'عرض الموظفين': 'عرض الموظفين',
            'إضافة موظف': 'إضافة موظف',
            'تعديل موظف': 'تعديل موظف',
            'حذف موظف': 'حذف موظف',
            'تجميد/تنشيط موظف': 'تجميد/تنشيط موظف',
            'عرض الرواتب': 'عرض الرواتب',
            'تعديل الرواتب': 'تعديل الرواتب',
            'تسليم راتب': 'تسليم راتب',
          },
          'تذاكر الدعم الفني': {
            'عرض التذاكر': 'عرض التذاكر',
            'الرد على التذاكر': 'الرد على التذاكر',
            'إحالة التذاكر': 'إحالة التذاكر',
            'إغلاق التذاكر': 'إغلاق التذاكر',
          }
        }
      },
      'الإعلانات والبنرات': {
        'icon': Icons.campaign,
        'tabs': {
          'الإعلانات': {
            'عرض الإعلانات': 'عرض الإعلانات',
            'إضافة إعلان': 'إضافة إعلان',
            'تعديل إعلان': 'تعديل إعلان',
            'حذف إعلان': 'حذف إعلان',
          }
        }
      },
      'بوابة رسائل SMS': {
        'icon': Icons.sms,
        'tabs': {
          'الرسائل': {
            'عرض SMS': 'عرض SMS',
            'إرسال SMS': 'إرسال SMS',
          }
        }
      },
      'السجل الأسود للنشاط': {
        'icon': Icons.security,
        'tabs': {
          'السجل': {
            'عرض السجل': 'عرض السجل',
          }
        }
      },
      'التحكم الشامل (إعادة التهيئة)': {
        'icon': Icons.cleaning_services,
        'tabs': {
          'التحكم': {
            'التحكم الشامل (إعادة التهيئة)': 'التحكم الشامل (إعادة التهيئة)',
          }
        }
      },
      'الإعدادات العامة': {
        'icon': Icons.settings,
        'tabs': {
          'الإعدادات': {
            'عرض الإعدادات': 'عرض الإعدادات',
            'تعديل الإعدادات': 'تعديل الإعدادات',
          }
        }
      },
      'النسخ الاحتياطي': {
        'icon': Icons.save,
        'tabs': {
          'النسخ': {
            'عرض النسخ': 'عرض النسخ',
            'أخذ نسخة': 'أخذ نسخة',
            'حذف نسخة': 'حذف نسخة',
          }
        }
      },
    };

    Map<String, bool> permissions = {};
    for (var section in sections.values) {
      for (var tab in (section['tabs'] as Map<String, dynamic>).values) {
        for (var key in (tab as Map<String, String>).values) {
          permissions[key] = existingData?['permissions']?[key] ?? false;
        }
      }
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          bool isSubmitting = false;

          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              backgroundColor: Theme.of(context).colorScheme.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              title: Row(
                children: [
                  Icon(existingData != null ? Icons.edit : Icons.person_add_alt_1, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 10),
                  Text(existingData != null ? 'تعديل بيانات الموظف' : 'إضافة موظف جديد',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Theme.of(context).colorScheme.onSurface)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTextField('الاسم الرباعي', Icons.person, controller: nameController),
                    if (existingData == null)
                      _buildTextField('رقم الهاتف', Icons.phone, controller: phoneController, isNumber: true),
                    if (existingData == null)
                      _buildTextField('كلمة المرور الافتراضية', Icons.lock, controller: passwordController),
                    _buildTextField('الراتب الشهري (اختياري)', Icons.monetization_on,
                        controller: salaryController, isNumber: true, enabled: _can('تعديل الرواتب')),
                    const Divider(),
                    Text('الصلاحيات الممنوحة للموظف:',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
                    const SizedBox(height: 8),
                    ...sections.entries.map((sectionEntry) {
                      final sectionName = sectionEntry.key;
                      final sectionData = sectionEntry.value as Map<String, dynamic>;
                      final tabs = sectionData['tabs'] as Map<String, dynamic>;

                      int totalPerms = 0;
                      int selectedPerms = 0;
                      for (var tab in tabs.values) {
                        for (var permKey in (tab as Map<String, String>).values) {
                          totalPerms++;
                          if (permissions[permKey] == true) selectedPerms++;
                        }
                      }
                      final someSelected = selectedPerms > 0;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        child: ListTile(
                          leading: Icon(sectionData['icon'] as IconData?, color: Theme.of(context).colorScheme.primary),
                          title: Text(sectionName, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('$totalPerms صلاحية',
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (someSelected)
                                Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary, size: 20),
                              Icon(Icons.arrow_forward_ios, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
                            ],
                          ),
                          onTap: () {
                            context.read<UiProvider>().playSound('click');
                            _showSectionPermissionsDialog(
                              ctx: ctx,
                              sectionName: sectionName,
                              sectionData: sectionData,
                              permissions: permissions,
                              setDialogState: setDialogState,
                            );
                          },
                        ),
                      );
                    }),
                  ],
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () {
                      context.read<UiProvider>().playSound('click');
                      Navigator.pop(ctx);
                    },
                    child: const Text('إلغاء')),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (nameController.text.isNotEmpty && phoneController.text.isNotEmpty) {
                            context.read<UiProvider>().playSound('click');
                            setDialogState(() => isSubmitting = true);
                            Navigator.pop(ctx);
                            _showSnackBar('جاري حفظ بيانات الموظف... ⏳');

                            try {
                              if (existingData != null) {
                                await _db.collection('users').doc(existingData['phone']).update({
                                  'name': nameController.text.trim(),
                                  'salary': salaryController.text.trim().isNotEmpty
                                      ? '${salaryController.text.trim()} ريال'
                                      : 'غير محدد',
                                  'permissions': permissions,
                                });
                              } else {
                                await _db.collection('users').doc(phoneController.text.trim()).set({
                                  'id': 'STAFF_${DateTime.now().millisecondsSinceEpoch}',
                                  'name': nameController.text.trim(),
                                  'phone': phoneController.text.trim(),
                                  'password': passwordController.text.trim().isNotEmpty
                                      ? passwordController.text.trim()
                                      : '123456',
                                  'role': 'staff',
                                  'salary': salaryController.text.trim().isNotEmpty
                                      ? '${salaryController.text.trim()} ريال'
                                      : 'غير محدد',
                                  'status': 'نشط',
                                  'permissions': permissions,
                                  'createdAt': FieldValue.serverTimestamp(),
                                });
                              }
                              context.read<UiProvider>().playSound('success');
                              if (mounted) {
                                setState(() {});
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        existingData != null ? 'تم تحديث بيانات الموظف بنجاح! ✅' : 'تمت إضافة الموظف وصلاحياته بنجاح! ✅',
                                        textDirection: TextDirection.rtl),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            } catch (e) {
                              context.read<UiProvider>().playSound('error');
                              if (mounted)
                                ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red));
                            }
                          } else {
                            context.read<UiProvider>().playSound('error');
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('يرجى إدخال اسم ورقم هاتف الموظف! ❌',
                                    textDirection: TextDirection.rtl),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                  child: Text(existingData != null ? 'تحديث' : 'حفظ الموظف'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // نافذة التبويبات الخاصة بقسم
  void _showSectionPermissionsDialog({
    required BuildContext ctx,
    required String sectionName,
    required Map<String, dynamic> sectionData,
    required Map<String, bool> permissions,
    required StateSetter setDialogState,
  }) {
    final tabs = sectionData['tabs'] as Map<String, dynamic>;

    showDialog(
      context: ctx,
      builder: (subCtx) => StatefulBuilder(
        builder: (subCtx, setSubDialogState) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              backgroundColor: Theme.of(context).colorScheme.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              title: Text('تبويبات $sectionName',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: tabs.entries.map((tabEntry) {
                    final tabName = tabEntry.key;
                    final tabPerms = tabEntry.value as Map<String, String>;
                    final allSelected = tabPerms.values.every((p) => permissions[p] == true);
                    final someSelected = tabPerms.values.any((p) => permissions[p] == true) && !allSelected;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      child: ListTile(
                        title: Text(tabName, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${tabPerms.length} صلاحية',
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
                        leading: Checkbox(
                          value: allSelected,
                          tristate: someSelected,
                          activeColor: Theme.of(context).colorScheme.primary,
                          onChanged: (val) {
                            context.read<UiProvider>().playSound('click');
                            setSubDialogState(() {
                              setDialogState(() {
                                for (var permKey in tabPerms.values) {
                                  permissions[permKey] = val ?? false;
                                }
                              });
                            });
                          },
                        ),
                        trailing: Icon(Icons.arrow_forward_ios, size: 14,
                            color: Theme.of(context).colorScheme.onSurfaceVariant),
                        onTap: () {
                          context.read<UiProvider>().playSound('click');
                          Navigator.pop(subCtx);
                          _showTabPermissionsDialog(
                            ctx: ctx,
                            sectionName: sectionName,
                            tabName: tabName,
                            tabPerms: tabPerms,
                            permissions: permissions,
                            setDialogState: setDialogState,
                          );
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(subCtx),
                  child: const Text('تم'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // نافذة الصلاحيات التفصيلية لتبويب
  void _showTabPermissionsDialog({
    required BuildContext ctx,
    required String sectionName,
    required String tabName,
    required Map<String, String> tabPerms,
    required Map<String, bool> permissions,
    required StateSetter setDialogState,
  }) {
    showDialog(
      context: ctx,
      builder: (subSubCtx) => StatefulBuilder(
        builder: (subSubCtx, setSubSubDialogState) {
          final allSelected = tabPerms.values.every((p) => permissions[p] == true);
          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              backgroundColor: Theme.of(context).colorScheme.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              title: Text('$sectionName - $tabName',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CheckboxListTile(
                      title: const Text('تحديد الكل', style: TextStyle(fontWeight: FontWeight.bold)),
                      value: allSelected,
                      activeColor: Theme.of(context).colorScheme.primary,
                      onChanged: (val) {
                        context.read<UiProvider>().playSound('click');
                        setSubSubDialogState(() {
                          setDialogState(() {
                            for (var permKey in tabPerms.values) {
                              permissions[permKey] = val ?? false;
                            }
                          });
                        });
                      },
                    ),
                    const Divider(),
                    ...tabPerms.entries.map((entry) {
                      return CheckboxListTile(
                        title: Text(entry.key, style: const TextStyle(fontSize: 14)),
                        value: permissions[entry.value] ?? false,
                        activeColor: Theme.of(context).colorScheme.primary,
                        onChanged: (val) {
                          context.read<UiProvider>().playSound('click');
                          setSubSubDialogState(() {
                            setDialogState(() {
                              permissions[entry.value] = val ?? false;
                            });
                          });
                        },
                      );
                    }),
                  ],
                ),
              ),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(subSubCtx),
                  child: const Text('تم'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ==========================================
  // دوال التحكم بالموظفين (محمية بالصلاحيات)
  // ==========================================
  void _toggleStaffStatus(Map<String, dynamic> emp) async {
    if (!_can('تجميد/تنشيط موظف')) return;
    context.read<UiProvider>().playSound('click');
    try {
      String newStatus = emp['status'] == 'نشط' ? 'موقوف' : 'نشط';
      await _db.collection('users').doc(emp['phone']).update({'status': newStatus});
      context.read<UiProvider>().playSound('success');
      if (mounted) setState(() {});
    } catch (e) {
      context.read<UiProvider>().playSound('error');
      if (mounted) _showSnackBar('خطأ: $e', error: true);
    }
  }

  void _deleteStaff(Map<String, dynamic> emp) {
    if (!_can('حذف موظف')) return;
    context.read<UiProvider>().playSound('click');
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: const Text('حذف الموظف 🗑️', style: TextStyle(color: Colors.red)),
          content: const Text('هل أنت متأكد من حذف هذا الموظف؟ سيتم إلغاء وصوله للنظام فوراً.'),
          actions: [
            TextButton(
                onPressed: () {
                  context.read<UiProvider>().playSound('click');
                  Navigator.pop(ctx);
                },
                child: const Text('تراجع')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                context.read<UiProvider>().playSound('click');
                try {
                  await _db.collection('users').doc(emp['phone']).delete();
                  context.read<UiProvider>().playSound('success');
                  if (mounted) {
                    Navigator.pop(ctx);
                    setState(() {});
                    _showSnackBar('تم حذف الموظف بنجاح.');
                  }
                } catch (e) {
                  context.read<UiProvider>().playSound('error');
                  if (mounted) _showSnackBar('خطأ: $e', error: true);
                }
              },
              child: const Text('تأكيد الحذف', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _paySalary(Map<String, dynamic> emp) {
    if (!_can('تسليم راتب')) return;
    context.read<UiProvider>().playSound('click');
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: const Text('تسليم الراتب 💸',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
          content: Text('هل تقر بتسليم الراتب للموظف "${emp['name']}"؟\n\n(سيقوم النظام آلياً بتسجيل المبلغ كـ "مصروفات تشغيلية").'),
          actions: [
            TextButton(
                onPressed: () {
                  context.read<UiProvider>().playSound('click');
                  Navigator.pop(ctx);
                },
                child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              onPressed: () async {
                context.read<UiProvider>().playSound('click');
                try {
                  String salaryStr = emp['salary'].toString().replaceAll(RegExp(r'[^0-9]'), '');
                  double amount = salaryStr.isEmpty ? 0 : double.parse(salaryStr);
                  if (amount <= 0) {
                    context.read<UiProvider>().playSound('error');
                    if (mounted) _showSnackBar('لا يوجد راتب محدد لهذا الموظف.', error: true);
                    Navigator.pop(ctx);
                    return;
                  }
                  WriteBatch batch = _db.batch();
                  batch.update(_db.collection('system').doc('main_info'),
                      {'adminMainBalance': FieldValue.increment(-amount)});
                  batch.set(_db.collection('transactions').doc(), {
                    'agentPhone': emp['phone'],
                    'agentName': emp['name'],
                    'type': 'مصروفات تشغيلية (راتب موظف)',
                    'amount': -amount,
                    'timestamp': FieldValue.serverTimestamp(),
                  });
                  await batch.commit();
                  context.read<UiProvider>().playSound('success');
                  if (mounted) {
                    Navigator.pop(ctx);
                    _showSnackBar('تم تسجيل الراتب كمصروفات تشغيلية بنجاح. ✅');
                  }
                } catch (e) {
                  context.read<UiProvider>().playSound('error');
                  if (mounted) _showSnackBar('خطأ: $e', error: true);
                }
              },
              child: const Text('نعم، أقر بالتسليم', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // دوال التبويب الثاني (تذاكر الدعم الفني) - محمية
  // ==========================================
  void _showTicketChat(Map<String, dynamic> ticket, String docId) {
    if (!_can('الرد على التذاكر')) return;
    context.read<UiProvider>().playSound('click');
    final replyController = TextEditingController();
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: colorScheme.surface,
          title: Text('تذكرة ${docId.substring(0, 5).toUpperCase()} - ${ticket['agentName'] ?? ticket['agent'] ?? 'مجهول'}',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: colorScheme.onSurface)),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                        color: isDark ? Colors.blue.shade900 : Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(10)),
                    child: Text('الوكيل: ${ticket['subject']}\n${ticket['description'] ?? ''}',
                        style: TextStyle(fontSize: 13, color: colorScheme.onSurface)),
                  ),
                ),
                if (ticket['replies'] != null)
                  ...List.generate((ticket['replies'] as List).length, (index) {
                    var reply = ticket['replies'][index];
                    bool isInternal = reply['isInternal'] ?? false;
                    bool isAgent = reply['sender'] == 'agent';
                    return Align(
                      alignment: isInternal ? Alignment.center : (isAgent ? Alignment.centerRight : Alignment.centerLeft),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: isInternal
                              ? Colors.amber.shade100
                              : (isAgent ? (isDark ? Colors.blue.shade900 : Colors.blue.shade50) : Colors.green.shade100),
                          borderRadius: BorderRadius.circular(10),
                          border: isInternal ? Border.all(color: Colors.amber) : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isInternal) const Icon(Icons.lock, size: 14, color: Colors.orange),
                            if (isInternal) const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                  '${isInternal ? "ملاحظة سرية:" : (isAgent ? "الوكيل:" : "أنت:")}\n${reply['text']}',
                                  style: TextStyle(fontSize: 12, color: isInternal ? Colors.brown : colorScheme.onSurface)),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                const Divider(),
                TextField(
                  controller: replyController,
                  decoration: InputDecoration(
                    hintText: 'اكتب ردك للوكيل هنا...',
                    suffixIcon: IconButton(
                      icon: Icon(Icons.send, color: colorScheme.primary),
                      onPressed: () async {
                        if (replyController.text.isEmpty) return;
                        context.read<UiProvider>().playSound('click');
                        WriteBatch batch = _db.batch();
                        DocumentReference ticketRef = _db.collection('support_tickets').doc(docId);
                        batch.update(ticketRef, {
                          'status': 'قيد المعالجة',
                          'replies': FieldValue.arrayUnion([
                            {'text': replyController.text, 'isInternal': false, 'sender': 'admin', 'timestamp': DateTime.now().toIso8601String()}
                          ])
                        });
                        String agentPhone = ticket['agentPhone'] ?? '';
                        if (agentPhone.isNotEmpty) {
                          DocumentReference notifRef = _db.collection('notifications').doc();
                          batch.set(notifRef, {
                            'targetPhones': [agentPhone],
                            'title': 'رد جديد من الدعم الفني 🎧',
                            'body': 'تم الرد على تذكرتك: ${docId.substring(0, 5).toUpperCase()}',
                            'timestamp': FieldValue.serverTimestamp(),
                            'isRead': false,
                            'readBy': [],
                          });
                        }
                        await batch.commit();
                        replyController.clear();
                        context.read<UiProvider>().playSound('success');
                        if (mounted) {
                          Navigator.pop(ctx);
                          _showSnackBar('تم إرسال الرد للوكيل بنجاح ✉️');
                        }
                      },
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                context.read<UiProvider>().playSound('click');
                Navigator.pop(ctx);
                _showInternalNoteDialog(docId);
              },
              child: const Text('➕ ملاحظة سرية', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
            ),
            TextButton(
                onPressed: () {
                  context.read<UiProvider>().playSound('click');
                  Navigator.pop(ctx);
                },
                child: Text('إغلاق الدردشة', style: TextStyle(color: colorScheme.onSurface))),
          ],
        ),
      ),
    );
  }

  void _showInternalNoteDialog(String docId) {
    if (!_can('الرد على التذاكر')) return;
    context.read<UiProvider>().playSound('click');
    final noteController = TextEditingController();
    final colorScheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade900 : Colors.amber.shade50,
          title: const Text('ملاحظة داخلية سرية 🔒', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
          content: TextField(
            controller: noteController,
            maxLines: 3,
            decoration: const InputDecoration(hintText: 'اكتب الملاحظة التي لن يراها الوكيل أبداً...'),
          ),
          actions: [
            TextButton(
                onPressed: () {
                  context.read<UiProvider>().playSound('click');
                  Navigator.pop(ctx);
                },
                child: Text('إلغاء', style: TextStyle(color: colorScheme.onSurface))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              onPressed: () async {
                if (noteController.text.isNotEmpty) {
                  context.read<UiProvider>().playSound('click');
                  await _db.collection('support_tickets').doc(docId).update({
                    'replies': FieldValue.arrayUnion([
                      {'text': noteController.text, 'isInternal': true, 'sender': 'admin', 'timestamp': DateTime.now().toIso8601String()}
                    ])
                  });
                  context.read<UiProvider>().playSound('success');
                  if (mounted) {
                    Navigator.pop(ctx);
                    _showSnackBar('تم حفظ الملاحظة الداخلية.');
                  }
                }
              },
              child: const Text('حفظ الملاحظة', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showAssignTicketDialog(String docId) {
    if (!_can('إحالة التذاكر')) return;
    context.read<UiProvider>().playSound('click');
    final colorScheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: colorScheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Text('إحالة التذكرة ↪️', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.purple)),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('اختر الموظف الذي تريد تحويل التذكرة إليه:', style: TextStyle(fontSize: 13)),
                const SizedBox(height: 10),
                Expanded(
                  flex: 0,
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _db.collection('users').where('role', isEqualTo: 'staff').where('status', isEqualTo: 'نشط').snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
                        return const Center(child: Text('لا يوجد موظفين نشطين متاحين حالياً.', style: TextStyle(color: Colors.red)));
                      var staffList = snapshot.data!.docs;
                      return ListView.separated(
                        shrinkWrap: true,
                        itemCount: staffList.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          var staff = staffList[index].data() as Map<String, dynamic>;
                          return ListTile(
                            title: Text(staff['name'] ?? 'موظف مجهول', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            subtitle: Text('هاتف: ${staff['phone']}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            leading: CircleAvatar(
                              backgroundColor: Colors.purple.withOpacity(0.1),
                              child: const Icon(Icons.support_agent, color: Colors.purple),
                            ),
                            onTap: () async {
                              context.read<UiProvider>().playSound('click');
                              Navigator.pop(ctx);
                              try {
                                WriteBatch batch = _db.batch();
                                DocumentReference ticketRef = _db.collection('support_tickets').doc(docId);
                                batch.update(ticketRef, {'status': 'قيد المعالجة', 'assignedToPhone': staff['phone'], 'assignedToName': staff['name']});
                                DocumentReference notifRef = _db.collection('notifications').doc();
                                batch.set(notifRef, {
                                  'targetPhones': [staff['phone']],
                                  'title': 'تذكرة جديدة محالة إليك 📌',
                                  'body': 'تم إحالة التذكرة رقم ${docId.substring(0, 5).toUpperCase()} إليك لمعالجتها.',
                                  'timestamp': FieldValue.serverTimestamp(),
                                  'isRead': false,
                                  'readBy': [],
                                });
                                await batch.commit();
                                context.read<UiProvider>().playSound('success');
                                if (mounted) _showSnackBar('تم إحالة التذكرة إلى ${staff['name']} بنجاح ✅');
                              } catch (e) {
                                context.read<UiProvider>().playSound('error');
                                if (mounted) _showSnackBar('حدث خطأ أثناء الإحالة: $e', error: true);
                              }
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () {
                  context.read<UiProvider>().playSound('click');
                  Navigator.pop(ctx);
                },
                child: Text('إلغاء', style: TextStyle(color: colorScheme.onSurface))),
          ],
        ),
      ),
    );
  }

  void _closeTicket(String docId, String agentPhone) async {
    if (!_can('إغلاق التذاكر')) return;
    context.read<UiProvider>().playSound('click');
    try {
      WriteBatch batch = _db.batch();
      DocumentReference ticketRef = _db.collection('support_tickets').doc(docId);
      batch.update(ticketRef, {'status': 'مغلقة'});
      if (agentPhone.isNotEmpty) {
        DocumentReference notifRef = _db.collection('notifications').doc();
        batch.set(notifRef, {
          'targetPhones': [agentPhone],
          'title': 'تم إغلاق تذكرتك 🔴',
          'body': 'تم حل وإغلاق التذكرة رقم ${docId.substring(0, 5).toUpperCase()}',
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
          'readBy': [],
        });
      }
      await batch.commit();
      context.read<UiProvider>().playSound('success');
      if (mounted) _showSnackBar('تم إغلاق التذكرة وأرشفتها بنجاح. ✅');
    } catch (e) {
      context.read<UiProvider>().playSound('error');
      if (mounted) _showSnackBar('خطأ: $e', error: true);
    }
  }

  void _showSnackBar(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, textDirection: TextDirection.rtl),
        backgroundColor: error ? Colors.red.shade800 : Colors.green.shade800,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final settings = context.watch<SettingsProvider>();
    final wallet = context.watch<WalletProvider>();
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: const CustomHeader(title: 'إدارة الموظفين والدعم'),
      drawer: CustomDrawer(
        userName: wallet.currentUserName,
        phoneNumber: auth.activeUserPhone ?? '',
        role: auth.currentUserRole == 'super_admin' ? 'مالك النظام' : 'موظف مخصص',
        balanceOrPoints: 'أرباح النظام: ${settings.adminMainBalance.toStringAsFixed(0)} ريال',
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverAppBarDelegate(
                TabBar(
                  controller: _tabController,
                  labelColor: colorScheme.primary,
                  unselectedLabelColor: colorScheme.onSurfaceVariant,
                  indicatorColor: colorScheme.primary,
                  indicatorWeight: 3,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  tabs: [
                    if (_can('عرض الموظفين'))
                      const Tab(icon: Icon(Icons.people_alt), text: 'الموظفين والصلاحيات'),
                    if (_can('عرض التذاكر'))
                      const Tab(icon: Icon(Icons.support_agent), text: 'تذاكر الدعم الفني'),
                  ],
                ),
                color: colorScheme.surface,
              ),
            ),
          ],
          body: TabBarView(
            controller: _tabController,
            children: [
              if (_can('عرض الموظفين')) _buildStaffTab(),
              if (_can('عرض التذاكر')) _buildTicketsTab(),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- تبويب الموظفين (محمي) ----------
  Widget _buildStaffTab() {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        if (_can('إضافة موظف'))
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              height: 45,
              child: ElevatedButton.icon(
                onPressed: () => _showStaffDialog(),
                icon: const Icon(Icons.person_add, color: Colors.white),
                label: const Text('إضافة موظف جديد',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              ),
            ),
          ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _db.collection('users').where('role', isEqualTo: 'staff').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting)
                return const Center(child: CircularProgressIndicator());
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
                return const Center(child: Text('لا يوجد موظفين حالياً.', style: TextStyle(color: Colors.grey)));

              var staffList = snapshot.data!.docs;

              return RefreshIndicator(
                onRefresh: () async {
                  await Future.delayed(const Duration(milliseconds: 300));
                  context.read<UiProvider>().playSound('success');
                  if (mounted) _showSnackBar('تم تحديث الصفحة بنجاح ✅');
                },
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: staffList.length,
                  itemBuilder: (context, index) {
                    var emp = staffList[index].data() as Map<String, dynamic>;
                    final isActive = emp['status'] == 'نشط';
                    final bool canSeeSalary = _can('عرض الرواتب');

                    return Card(
                      color: colorScheme.surface,
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                        side: BorderSide(color: isActive ? Colors.transparent : colorScheme.error.withOpacity(0.3), width: 1.5),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('${emp['name']} (موظف مخصص)',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: colorScheme.onSurface,
                                        decoration: isActive ? TextDecoration.none : TextDecoration.lineThrough)),
                                Chip(
                                    label: Text(emp['status'] ?? 'نشط',
                                        style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
                                    backgroundColor: isActive ? Colors.green : Colors.red),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('هاتف: ${emp['phone']}', style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13)),
                                if (canSeeSalary)
                                  Text('الراتب: ${emp['salary']}', style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13))
                                else
                                  Text('الراتب: ****', style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13)),
                              ],
                            ),
                            const Divider(),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                if (_can('تعديل موظف'))
                                  _buildIconButton(Icons.settings, 'تعديل', Colors.blue, () {
                                    _showStaffDialog(existingData: emp);
                                  }),
                                if (_can('تجميد/تنشيط موظف'))
                                  _buildIconButton(
                                      isActive ? Icons.pause_circle : Icons.play_circle,
                                      isActive ? 'إيقاف' : 'تفعيل',
                                      isActive ? Colors.orange : Colors.green,
                                      () => _toggleStaffStatus(emp)),
                                if (_can('حذف موظف'))
                                  _buildIconButton(Icons.delete, 'حذف', Colors.red, () => _deleteStaff(emp)),
                                if (_can('تسليم راتب'))
                                  _buildIconButton(Icons.monetization_on, 'تسليم الراتب', Colors.green, () => _paySalary(emp)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ---------- تبويب التذاكر (محمي) ----------
  Widget _buildTicketsTab() {
    final colorScheme = Theme.of(context).colorScheme;
    return StreamBuilder<QuerySnapshot>(
      stream: _db.collection('support_tickets').orderBy('timestamp', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
          return const Center(child: Text('لا توجد تذاكر دعم حالياً.', style: TextStyle(color: Colors.grey)));

        var tickets = snapshot.data!.docs;

        return RefreshIndicator(
          onRefresh: () async {
            await Future.delayed(const Duration(milliseconds: 300));
            context.read<UiProvider>().playSound('success');
            if (mounted) _showSnackBar('تم تحديث الصفحة بنجاح ✅');
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: tickets.length,
            itemBuilder: (context, index) {
              var docId = tickets[index].id;
              var ticket = tickets[index].data() as Map<String, dynamic>;
              final isClosed = ticket['status'] == 'مغلقة';
              final String assignedTo = ticket['assignedToName'] ?? 'غير محدد';

              return Card(
                elevation: isClosed ? 0 : 3,
                color: isClosed ? colorScheme.surface.withOpacity(0.5) : colorScheme.surface,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                    side: BorderSide(color: isClosed ? colorScheme.outlineVariant : Colors.transparent)),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('${docId.substring(0, 5).toUpperCase()} | ${ticket['agentName'] ?? ticket['agentPhone'] ?? 'مجهول'}',
                              style: TextStyle(fontWeight: FontWeight.bold, color: isClosed ? Colors.grey : colorScheme.onSurface)),
                          Text(ticket['priority'] ?? 'عادية', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(ticket['subject'] ?? 'بدون عنوان',
                          style: TextStyle(fontSize: 14, color: isClosed ? Colors.grey : colorScheme.onSurfaceVariant)),
                      if (assignedTo != 'غير محدد')
                        Text('محالة إلى: $assignedTo', style: const TextStyle(fontSize: 11, color: Colors.purple, fontWeight: FontWeight.bold)),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          if (_can('الرد على التذاكر'))
                            _buildIconButton(Icons.chat, 'فتح التذكرة', isClosed ? Colors.grey : Colors.blue,
                                () => _showTicketChat(ticket, docId)),
                          if (_can('الرد على التذاكر'))
                            _buildIconButton(Icons.lock, 'ملاحظة سرية', isClosed ? Colors.grey : Colors.orange,
                                () => _showInternalNoteDialog(docId)),
                          if (!isClosed && _can('إحالة التذاكر'))
                            _buildIconButton(Icons.shortcut, 'إحالة إلى..', Colors.purple,
                                () => _showAssignTicketDialog(docId)),
                          if (!isClosed && _can('إغلاق التذاكر'))
                            _buildIconButton(Icons.check_circle, 'إغلاق', Colors.green,
                                () => _closeTicket(docId, ticket['agentPhone'] ?? '')),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildTextField(String label, IconData icon,
      {TextEditingController? controller, bool isNumber = false, bool enabled = true}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextField(
        controller: controller,
        enabled: enabled,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Theme.of(context).colorScheme.primary),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }

  Widget _buildIconButton(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;
  final Color color;
  _SliverAppBarDelegate(this._tabBar, {required this.color});
  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;
  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) =>
      Container(color: color, child: _tabBar);
  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}
