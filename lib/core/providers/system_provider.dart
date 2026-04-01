import 'package:flutter/material.dart';

class SystemProvider extends ChangeNotifier {
  // ==========================================
  // 1. بيانات مالك النظام (الخزينة المركزية)
  // ==========================================
  double _adminMainBalance = 10000000.0; 
  int _totalSystemCards = 5000; 

  // ==========================================
  // 2. الذاكرة النشطة (لمعرفة من يتصفح التطبيق الآن)
  // ==========================================
  String? _activeUserPhone; 

  // ==========================================
  // 3. قاعدة البيانات المركزية الحقيقية (Users Database)
  // ==========================================
  final List<Map<String, dynamic>> _usersDatabase = [
    {
      'id': 'SUPER_ADMIN_01',
      'name': 'مالك النظام',
      'phone': '774578241',
      'password': '75486958aaa',
      'role': 'super_admin',
      'balance': 0.0,
      'status': 'نشط',
      'purchasedCards': [],
      'isBiometricEnabled': false, // متغير البصمة الافتراضي
    }
  ];

  // ==========================================
  // 4. دوال القراءة (Getters) العامة
  // ==========================================
  double get adminMainBalance => _adminMainBalance;
  int get totalSystemCards => _totalSystemCards;

  List<Map<String, dynamic>> get agentsList => 
      _usersDatabase.where((user) => user['role'] == 'agent').toList();

  List<Map<String, dynamic>> get usersList => 
      _usersDatabase.where((user) => user['role'] == 'user').toList();

  // ==========================================
  // 5. دوال القراءة الذكية (للمستخدم النشط حالياً)
  // ==========================================
  
  String get currentUserName {
    if (_activeUserPhone == null) return 'مستخدم غير معروف';
    final user = _usersDatabase.firstWhere(
      (u) => u['phone'] == _activeUserPhone, 
      orElse: () => {'name': 'مستخدم غير معروف'}
    );
    return user['name'] ?? 'مستخدم غير معروف';
  }

  String get currentUserPhone {
    return _activeUserPhone ?? 'لا يوجد رقم';
  }

  double get currentUserBalance {
    if (_activeUserPhone == null) return 0.0;
    final user = _usersDatabase.firstWhere(
      (u) => u['phone'] == _activeUserPhone, 
      orElse: () => {'balance': 0.0}
    );
    return user['balance'] ?? 0.0;
  }

  List<String> get userPurchasedCards {
    if (_activeUserPhone == null) return [];
    final user = _usersDatabase.firstWhere(
      (u) => u['phone'] == _activeUserPhone, 
      orElse: () => {'purchasedCards': <String>[]}
    );
    return List<String>.from(user['purchasedCards'] ?? []);
  }

  // ==========================================
  // 6. دوال المصادقة وتسجيل الدخول
  // ==========================================

  bool checkUserExists(String phone) {
    return _usersDatabase.any((user) => user['phone'] == phone);
  }

  Map<String, dynamic>? loginUser(String phone, String password) {
    try {
      final user = _usersDatabase.firstWhere(
        (user) => user['phone'] == phone && user['password'] == password,
      );
      // حفظ رقم المستخدم النشط في الذاكرة
      _activeUserPhone = phone;
      notifyListeners();
      return user;
    } catch (e) {
      return null; 
    }
  }

  void registerNewUser({
    required String name,
    required String phone,
    required String password,
    required String role,
  }) {
    _usersDatabase.add({
      'id': 'USER_${DateTime.now().millisecondsSinceEpoch}',
      'name': name,
      'phone': phone,
      'password': password,
      'role': role,
      'balance': 0.0,
      'status': 'نشط',
      'purchasedCards': [], 
      'isBiometricEnabled': false, // القيمة الافتراضية للبصمة
    });
    // حفظ رقم المستخدم الجديد كـ "مستخدم نشط" ليدخل مباشرة
    _activeUserPhone = phone;
    notifyListeners(); 
  }

  void addAgent({
    required String name,
    required String phone,
    required String password,
  }) {
    if (!checkUserExists(phone)) {
      _usersDatabase.add({
        'id': 'AGENT_${DateTime.now().millisecondsSinceEpoch}',
        'name': name,
        'phone': phone,
        'password': password,
        'role': 'agent',
        'balance': 0.0,
        'status': 'نشط',
        'purchasedCards': [],
        'isBiometricEnabled': false,
      });
      notifyListeners();
    }
  }

  // ==========================================
  // 7. الوظائف التشغيلية والمالية
  // ==========================================

  bool transferFromAdminToAgent(String agentPhone, double amount) {
    if (_adminMainBalance >= amount) {
      for (var user in _usersDatabase) {
        if (user['phone'] == agentPhone && user['role'] == 'agent') {
          _adminMainBalance -= amount; 
          user['balance'] += amount; 
          notifyListeners(); 
          return true; 
        }
      }
    }
    return false; 
  }

  bool userBuyCard(double price, String cardName) {
    if (_activeUserPhone == null) return false;

    for (var user in _usersDatabase) {
      if (user['phone'] == _activeUserPhone && user['role'] == 'user') {
        if (user['balance'] >= price && _totalSystemCards > 0) {
          user['balance'] -= price; // خصم الرصيد
          _totalSystemCards -= 1; // سحب كرت
          
          if (user['purchasedCards'] == null) {
            user['purchasedCards'] = [];
          }
          user['purchasedCards'].add(cardName); // إضافة الكرت
          
          notifyListeners();
          return true;
        }
      }
    }
    return false;
  }

  // ==========================================
  // 8. إعدادات الأمان والحماية الحقيقية (✨ القسم المفقود لحل الخطأ)
  // ==========================================

  /// دالة تغيير كلمة المرور الفعلية
  bool changeUserPassword(String oldPassword, String newPassword) {
    if (_activeUserPhone == null) return false;
    
    for (var user in _usersDatabase) {
      if (user['phone'] == _activeUserPhone) {
        // التحقق من أن كلمة المرور القديمة صحيحة قبل تغييرها
        if (user['password'] == oldPassword) {
          user['password'] = newPassword; 
          notifyListeners();
          return true; // تمت العملية بنجاح
        }
      }
    }
    return false; // فشلت العملية (كلمة المرور القديمة خاطئة)
  }

  /// دالة تفعيل أو إلغاء البصمة للمستخدم الحالي
  void toggleBiometric(bool isEnabled) {
    if (_activeUserPhone == null) return;
    
    for (var user in _usersDatabase) {
      if (user['phone'] == _activeUserPhone) {
        user['isBiometricEnabled'] = isEnabled; // حفظ الحالة الجديدة في قاعدة البيانات
        notifyListeners();
        break;
      }
    }
  }

  /// قراءة حالة البصمة للمستخدم الحالي (لإظهارها في الشاشة)
  bool get isBiometricCurrentlyEnabled {
    if (_activeUserPhone == null) return false;
    
    final user = _usersDatabase.firstWhere(
      (u) => u['phone'] == _activeUserPhone, 
      orElse: () => {'isBiometricEnabled': false}
    );
    return user['isBiometricEnabled'] ?? false;
  }
}
