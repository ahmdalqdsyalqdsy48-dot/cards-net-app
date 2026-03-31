import 'package:flutter/material.dart';

// هذا الكلاس يمثل "العقل المدبر وقاعدة البيانات الحقيقية" الذي يربط جميع لوحات التحكم
class SystemProvider extends ChangeNotifier {
  // ==========================================
  // 1. بيانات مالك النظام (الخزينة المركزية)
  // ==========================================
  double _adminMainBalance = 10000000.0; // رصيد النظام الكلي (مثال: 10 مليون ريال كبداية)
  int _totalSystemCards = 5000; // إجمالي الكروت المتوفرة في المخزن المركزي

  // ==========================================
  // 2. قاعدة البيانات المركزية الحقيقية (Users Database)
  // ==========================================
  // هذه القائمة تمثل جدول قاعدة البيانات في الخادم.
  // تبدأ فارغة تماماً من الوكلاء والزبائن (لا يوجد أرقام تجريبية).
  final List<Map<String, dynamic>> _usersDatabase = [
    // مالك النظام مضاف افتراضياً لضمان الدخول وإدارة النظام
    {
      'id': 'SUPER_ADMIN_01',
      'name': 'مالك النظام',
      'phone': '774578241',
      'password': '75486958aaa',
      'role': 'super_admin',
      'balance': 0.0,
      'status': 'نشط'
    }
  ];

  // ==========================================
  // 3. دوال القراءة (Getters) لعرض البيانات
  // ==========================================
  double get adminMainBalance => _adminMainBalance;
  int get totalSystemCards => _totalSystemCards;

  // دالة لجلب قائمة "الوكلاء" فقط من قاعدة البيانات
  List<Map<String, dynamic>> get agentsList => 
      _usersDatabase.where((user) => user['role'] == 'agent').toList();

  // دالة لجلب قائمة "المستخدمين النهائيين" فقط من قاعدة البيانات
  List<Map<String, dynamic>> get usersList => 
      _usersDatabase.where((user) => user['role'] == 'user').toList();

  // ==========================================
  // 4. دوال المصادقة وتسجيل الدخول (المرتبطة بشاشة الدخول)
  // ==========================================

  /// فحص هل رقم الهاتف مسجل مسبقاً في النظام؟
  bool checkUserExists(String phone) {
    return _usersDatabase.any((user) => user['phone'] == phone);
  }

  /// دالة تسجيل الدخول (تبحث عن التطابق بين الرقم وكلمة المرور)
  Map<String, dynamic>? loginUser(String phone, String password) {
    try {
      // البحث عن أول مستخدم تتطابق بياناته
      return _usersDatabase.firstWhere(
        (user) => user['phone'] == phone && user['password'] == password,
      );
    } catch (e) {
      // إذا لم يتم العثور على المستخدم، نرجع قيمة فارغة (null)
      return null; 
    }
  }

  /// دالة تسجيل حساب جديد للمستخدم النهائي (من شاشة تسجيل الدخول)
  void registerNewUser({
    required String name,
    required String phone,
    required String password,
    required String role,
  }) {
    _usersDatabase.add({
      'id': 'USER_${DateTime.now().millisecondsSinceEpoch}', // توليد ID فريد بناءً على الوقت
      'name': name,
      'phone': phone,
      'password': password,
      'role': role,
      'balance': 0.0, // الرصيد يبدأ بصفر دائماً
      'status': 'نشط',
      'purchasedCards': [], // سجل مشتريات فارغ
    });
    notifyListeners(); // إشعار جميع الشاشات بتحديث قاعدة البيانات
  }

  /// دالة لمالك النظام لإضافة "وكيل حقيقي" (تُستخدم لاحقاً في لوحة المالك)
  void addAgent({
    required String name,
    required String phone,
    required String password,
  }) {
    // التأكد من عدم تكرار الرقم قبل إضافة الوكيل
    if (!checkUserExists(phone)) {
      _usersDatabase.add({
        'id': 'AGENT_${DateTime.now().millisecondsSinceEpoch}',
        'name': name,
        'phone': phone,
        'password': password,
        'role': 'agent',
        'balance': 0.0,
        'status': 'نشط',
      });
      notifyListeners();
    }
  }

  // ==========================================
  // 5. الوظائف التشغيلية والمالية بين اللوحات
  // ==========================================

  /// تحويل رصيد من مالك النظام إلى أحد الوكلاء
  bool transferFromAdminToAgent(String agentPhone, double amount) {
    if (_adminMainBalance >= amount) {
      // البحث عن الوكيل في قاعدة البيانات بناءً على رقم هاتفه
      for (var user in _usersDatabase) {
        if (user['phone'] == agentPhone && user['role'] == 'agent') {
          _adminMainBalance -= amount; // خصم من الإدارة
          user['balance'] += amount; // إضافة لمحفظة الوكيل
          notifyListeners(); // تحديث الشاشات
          return true; // نجحت العملية
        }
      }
    }
    return false; // فشلت العملية (لا يوجد رصيد أو الوكيل غير موجود)
  }

  /// وظيفة للمستخدم: شراء كرت (سيتم تطويرها وربطها لاحقاً بلوحة المستخدم)
  bool userBuyCard(String userPhone, double price, String cardName) {
    for (var user in _usersDatabase) {
      if (user['phone'] == userPhone && user['role'] == 'user') {
        if (user['balance'] >= price && _totalSystemCards > 0) {
          user['balance'] -= price; // خصم من المستخدم
          _totalSystemCards -= 1; // سحب كرت من مخزن النظام
          
          if (user['purchasedCards'] == null) {
            user['purchasedCards'] = [];
          }
          user['purchasedCards'].add(cardName); // إضافة الكرت لملف المستخدم
          
          notifyListeners();
          return true;
        }
      }
    }
    return false;
  }
}
