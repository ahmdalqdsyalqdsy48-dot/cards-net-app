import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // 👈 استدعاء مكتبة السحابة

class SystemProvider extends ChangeNotifier {
  // 1. الاتصال المباشر بقاعدة بيانات جوجل
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 2. المتغيرات المحلية (نستخدمها لسرعة عرض الواجهة دون تأخير)
  double _adminMainBalance = 10000000.0; 
  int _totalSystemCards = 5000; 
  String? _activeUserPhone; 
  List<Map<String, dynamic>> _usersDatabase = [];
  List<String> _announcements = []; // 👈 أضفنا قائمة الإعلانات هنا

  // ==========================================
  // 3. تهيئة النظام (الاستماع للسحابة لحظة بلحظة)
  // ==========================================
  SystemProvider() {
    _initDatabaseSync();
  }

  void _initDatabaseSync() {
    // أ. الاستماع لملف "الخزينة المركزية والإعلانات"
    _db.collection('system').doc('main_info').snapshots().listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data()!;
        _adminMainBalance = (data['adminMainBalance'] ?? 10000000.0).toDouble();
        _totalSystemCards = data['totalSystemCards'] ?? 5000;
        _announcements = List<String>.from(data['announcements'] ?? ['أهلاً بك في شبكة كروت نت...']);
        notifyListeners();
      } else {
        // إذا كان التطبيق يُفتح لأول مرة، ننشئ الملف في فايربيس
        _db.collection('system').doc('main_info').set({
          'adminMainBalance': 10000000.0,
          'totalSystemCards': 5000,
          'announcements': ['أهلاً بك في شبكة كروت نت...'],
        });
      }
    });

    // ب. الاستماع لقائمة "المستخدمين" (المالك، الوكلاء، المستخدمين)
    _db.collection('users').snapshots().listen((snapshot) {
      _usersDatabase = snapshot.docs.map((doc) => doc.data()).toList();
      
      // التأكد من وجود حساب المالك، وإذا لم يوجد ننشئه في فايربيس
      if (!_usersDatabase.any((u) => u['role'] == 'super_admin')) {
        _db.collection('users').doc('774578241').set({
          'id': 'SUPER_ADMIN_01',
          'name': 'مالك النظام',
          'phone': '774578241',
          'password': '75486958aaa',
          'role': 'super_admin',
          'balance': 0.0,
          'status': 'نشط',
          'purchasedCards': [],
          'isBiometricEnabled': false,
        });
      }
      notifyListeners();
    });
  }

  // ==========================================
  // 4. دوال القراءة (كما هي تماماً لكي لا تتعطل الشاشات)
  // ==========================================
  double get adminMainBalance => _adminMainBalance;
  int get totalSystemCards => _totalSystemCards;
  List<String> get announcements => _announcements; // 👈 استدعاء الإعلانات

  List<Map<String, dynamic>> get agentsList => 
      _usersDatabase.where((user) => user['role'] == 'agent').toList();

  List<Map<String, dynamic>> get usersList => 
      _usersDatabase.where((user) => user['role'] == 'user').toList();

  String get currentUserName {
    if (_activeUserPhone == null) return 'مستخدم غير معروف';
    final user = _usersDatabase.firstWhere((u) => u['phone'] == _activeUserPhone, orElse: () => {'name': 'مستخدم غير معروف'});
    return user['name'] ?? 'مستخدم غير معروف';
  }

  String get currentUserPhone => _activeUserPhone ?? 'لا يوجد رقم';

  double get currentUserBalance {
    if (_activeUserPhone == null) return 0.0;
    final user = _usersDatabase.firstWhere((u) => u['phone'] == _activeUserPhone, orElse: () => {'balance': 0.0});
    return user['balance'] ?? 0.0;
  }

  List<String> get userPurchasedCards {
    if (_activeUserPhone == null) return [];
    final user = _usersDatabase.firstWhere((u) => u['phone'] == _activeUserPhone, orElse: () => {'purchasedCards': <String>[]});
    return List<String>.from(user['purchasedCards'] ?? []);
  }

  bool get isBiometricCurrentlyEnabled {
    if (_activeUserPhone == null) return false;
    final user = _usersDatabase.firstWhere((u) => u['phone'] == _activeUserPhone, orElse: () => {'isBiometricEnabled': false});
    return user['isBiometricEnabled'] ?? false;
  }

  // ==========================================
  // 5. دوال الإضافة والتعديل (تكتب مباشرة في فايربيس) 🚀
  // ==========================================

  bool checkUserExists(String phone) {
    return _usersDatabase.any((user) => user['phone'] == phone);
  }

  Map<String, dynamic>? loginUser(String phone, String password) {
    try {
      final user = _usersDatabase.firstWhere((user) => user['phone'] == phone && user['password'] == password);
      _activeUserPhone = phone;
      notifyListeners();
      return user;
    } catch (e) {
      return null; 
    }
  }

  void registerNewUser({required String name, required String phone, required String password, required String role}) {
    // 👈 حفظ في فايربيس بدلاً من الذاكرة المؤقتة
    _db.collection('users').doc(phone).set({
      'id': 'USER_${DateTime.now().millisecondsSinceEpoch}',
      'name': name,
      'phone': phone,
      'password': password,
      'role': role,
      'balance': 0.0,
      'status': 'نشط',
      'purchasedCards': [], 
      'isBiometricEnabled': false,
    });
    _activeUserPhone = phone;
  }

  void addAgent({required String name, required String phone, required String password}) {
    if (!checkUserExists(phone)) {
      _db.collection('users').doc(phone).set({
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
    }
  }

  // إضافة إعلان جديد
  void addAnnouncement(String newAd) {
    _db.collection('system').doc('main_info').update({
      'announcements': FieldValue.arrayUnion([newAd]) // إضافة الإعلان للسحابة
    });
  }

  // ==========================================
  // 6. العمليات المالية (آمنة ومباشرة على السحابة)
  // ==========================================

  bool transferFromAdminToAgent(String agentPhone, double amount) {
    if (_adminMainBalance >= amount) {
      // 1. خصم من الخزينة المركزية
      _db.collection('system').doc('main_info').update({
        'adminMainBalance': FieldValue.increment(-amount)
      });
      // 2. إضافة لحساب الوكيل
      _db.collection('users').doc(agentPhone).update({
        'balance': FieldValue.increment(amount)
      });
      return true; 
    }
    return false; 
  }

  bool userBuyCard(double price, String cardName) {
    if (_activeUserPhone == null) return false;

    final user = _usersDatabase.firstWhere((u) => u['phone'] == _activeUserPhone);
    if (user['balance'] >= price && _totalSystemCards > 0) {
      // 1. خصم كرت من النظام
      _db.collection('system').doc('main_info').update({
        'totalSystemCards': FieldValue.increment(-1)
      });
      // 2. خصم الرصيد من المستخدم وإضافة الكرت له
      _db.collection('users').doc(_activeUserPhone).update({
        'balance': FieldValue.increment(-price),
        'purchasedCards': FieldValue.arrayUnion([cardName])
      });
      return true;
    }
    return false;
  }

  // ==========================================
  // 7. إعدادات الأمان
  // ==========================================

  bool changeUserPassword(String oldPassword, String newPassword) {
    if (_activeUserPhone == null) return false;
    
    final user = _usersDatabase.firstWhere((u) => u['phone'] == _activeUserPhone);
    if (user['password'] == oldPassword) {
      _db.collection('users').doc(_activeUserPhone).update({'password': newPassword});
      return true; 
    }
    return false; 
  }

  void toggleBiometric(bool isEnabled) {
    if (_activeUserPhone == null) return;
    _db.collection('users').doc(_activeUserPhone).update({'isBiometricEnabled': isEnabled});
  }
}
