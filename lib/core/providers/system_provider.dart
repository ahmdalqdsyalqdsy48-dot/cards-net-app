import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 

class SystemProvider extends ChangeNotifier {
  // 1. الاتصال المباشر بقاعدة بيانات جوجل
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 2. المتغيرات المحلية 
  double _adminMainBalance = 10000000.0; 
  int _totalSystemCards = 5000; 
  String? _activeUserPhone; 
  
  double _newsScrollSpeed = 40.0; 

  List<Map<String, dynamic>> _usersDatabase = [];
  List<String> _announcements = []; 
  List<Map<String, dynamic>> _rechargeRequests = []; 
  List<Map<String, dynamic>> _transactionsLedger = []; 

  // ==========================================
  // 3. تهيئة النظام (الاستماع للسحابة لحظة بلحظة)
  // ==========================================
  SystemProvider() {
    _initDatabaseSync();
  }

  void _initDatabaseSync() {
    _db.collection('system').doc('main_info').snapshots().listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data()!;
        _adminMainBalance = (data['adminMainBalance'] ?? 10000000.0).toDouble();
        _totalSystemCards = data['totalSystemCards'] ?? 5000;
        _announcements = List<String>.from(data['announcements'] ?? ['أهلاً بك في شبكة كروت نت...']);
        _newsScrollSpeed = (data['newsScrollSpeed'] ?? 40.0).toDouble();
        notifyListeners();
      }
    });

    _db.collection('users').snapshots().listen((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        _usersDatabase = snapshot.docs.map((doc) => doc.data()).toList();
        notifyListeners();
      }
    });

    _db.collection('recharge_requests')
       .where('status', isEqualTo: 'قيد الانتظار')
       .snapshots().listen((snapshot) {
      _rechargeRequests = snapshot.docs.map((doc) => {'docId': doc.id, ...doc.data()}).toList();
      notifyListeners();
    });

    _db.collection('transactions')
       .orderBy('timestamp', descending: true)
       .snapshots().listen((snapshot) {
      _transactionsLedger = snapshot.docs.map((doc) => {'docId': doc.id, ...doc.data()}).toList();
      notifyListeners();
    });
  }

  // ==========================================
  // 4. دوال القراءة
  // ==========================================
  double get adminMainBalance => _adminMainBalance;
  int get totalSystemCards => _totalSystemCards;
  List<String> get announcements => _announcements; 
  double get newsScrollSpeed => _newsScrollSpeed; 

  List<Map<String, dynamic>> get agentsList => 
      _usersDatabase.where((user) => user['role'] == 'agent').toList();

  List<Map<String, dynamic>> get usersList => 
      _usersDatabase.where((user) => user['role'] == 'user').toList();

  List<Map<String, dynamic>> get pendingRechargeRequests => _rechargeRequests;
  List<Map<String, dynamic>> get transactionsLedger => _transactionsLedger;

  String get currentUserName {
    if (_activeUserPhone == null) return 'مستخدم غير معروف';
    final user = _usersDatabase.firstWhere((u) => u['phone'] == _activeUserPhone, orElse: () => {'name': 'مستخدم غير معروف'});
    return user['name'] ?? 'مستخدم غير معروف';
  }

  String get currentUserPhone => _activeUserPhone ?? 'لا يوجد رقم';

  double get currentUserBalance {
    if (_activeUserPhone == null) return 0.0;
    final user = _usersDatabase.firstWhere((u) => u['phone'] == _activeUserPhone, orElse: () => {'balance': 0.0});
    return (user['balance'] ?? 0.0).toDouble();
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
  // 5. دوال الإدارة والتحكم 🚀
  // ==========================================
  
  Future<void> updateNewsSpeed(double newSpeed) async {
    try {
      await _db.collection('system').doc('main_info').update({'newsScrollSpeed': newSpeed});
    } catch (e) {
      // تجاهل
    }
  }

  Future<bool> checkUserExists(String phone) async {
    try {
      final doc = await _db.collection('users').doc(phone).get().timeout(const Duration(seconds: 5));
      return doc.exists;
    } catch (e) {
      return false; // نعتبره غير موجود في حالة الخطأ أو ضعف الإنترنت
    }
  }

  // 🔴 الدالة المحسنة: الدخول الفوري للمالك بدون انتظار (Fire and Forget)
  Future<Map<String, dynamic>?> loginUser(String phone, String password) async {
    
    // 1. فحص بيانات المالك أولاً (دخول لحظي)
    if (phone == '774578241' && password == '75486958aaa') {
      final superAdminData = {
        'id': 'SUPER_ADMIN_01',
        'name': 'مالك النظام',
        'phone': '774578241',
        'password': '75486958aaa',
        'role': 'super_admin',
        'balance': 0.0,
        'dangerLimit': 0.0,
        'status': 'نشط',
        'purchasedCards': [],
        'isBiometricEnabled': false,
      };
      
      // إرسال البيانات للسحابة في الخلفية (تم إزالة await لمنع التعليق)
      try {
        _db.collection('users').doc('774578241').set(superAdminData);
        _db.collection('system').doc('main_info').set({
          'adminMainBalance': 10000000.0,
          'totalSystemCards': 5000,
          'announcements': ['أهلاً بك في شبكة كروت نت...'],
          'newsScrollSpeed': 40.0,
        });
      } catch (e) {
        // تجاهل الأخطاء الصامتة
      }
      
      _activeUserPhone = phone;
      notifyListeners();
      return superAdminData; // الدخول يتم في كسر من الثانية!
    }

    // 2. للوكلاء والمستخدمين: جلب البيانات من السحابة مع صمام أمان زمني (Timeout)
    try {
      final doc = await _db.collection('users').doc(phone).get().timeout(const Duration(seconds: 7));
      if (doc.exists) {
        final userData = doc.data() as Map<String, dynamic>;
        if (userData['password'] == password) {
          _activeUserPhone = phone;
          notifyListeners();
          return userData;
        }
      }
      return null; 
    } catch (e) {
      return null; // يتوقف بعد 7 ثوانٍ ويعطي خطأ بدلاً من التعليق
    }
  }

  Future<void> registerNewUser({required String name, required String phone, required String password, required String role}) async {
    await _db.collection('users').doc(phone).set({
      'id': 'USER_${DateTime.now().millisecondsSinceEpoch}',
      'name': name,
      'phone': phone,
      'password': password,
      'role': role,
      'balance': 0.0,
      'dangerLimit': 0.0,
      'status': 'نشط',
      'purchasedCards': [], 
      'isBiometricEnabled': false,
    });
    _activeUserPhone = phone;
    notifyListeners();
  }

  Future<void> addAgent({
    required String name, 
    required String phone, 
    required String password,
    String? networkName, 
    String? profitMargin, 
    String? location,
  }) async {
    bool exists = await checkUserExists(phone);
    if (!exists) {
      await _db.collection('users').doc(phone).set({
        'id': 'AGENT_${DateTime.now().millisecondsSinceEpoch}',
        'name': name,
        'phone': phone,
        'password': password,
        'role': 'agent',
        'networkName': networkName ?? 'غير محدد',
        'profitMargin': profitMargin ?? 'غير محدد',
        'location': location ?? 'غير محدد',
        'balance': 0.0,
        'dangerLimit': 0.0, 
        'status': 'نشط',
        'purchasedCards': [],
        'isBiometricEnabled': false,
      });
    } else {
      throw 'رقم الهاتف مسجل مسبقاً!';
    }
  }

  Future<void> updateAgentDetails({
    required String oldPhone,
    required String newPhone,
    required String newName,
    required String newNetwork,
    required String newLocation,
    required String newProfit,
    required String newPassword,
  }) async {
    final doc = await _db.collection('users').doc(oldPhone).get();
    if (doc.exists) {
      Map<String, dynamic> data = doc.data()!;
      data.addAll({'phone': newPhone, 'name': newName, 'networkName': newNetwork, 'location': newLocation, 'profitMargin': newProfit, 'password': newPassword});
      WriteBatch batch = _db.batch();
      batch.set(_db.collection('users').doc(newPhone), data);
      if (oldPhone != newPhone) batch.delete(_db.collection('users').doc(oldPhone));
      await batch.commit();
    }
  }

  void toggleUserStatus(String phone, String currentStatus) {
    String newStatus = currentStatus == 'نشط' ? 'مجمد' : 'نشط';
    _db.collection('users').doc(phone).update({'status': newStatus});
  }

  void deleteAgent(String phone) => _db.collection('users').doc(phone).delete();

  // ==========================================
  // 6. العمليات المالية الصارمة
  // ==========================================

  bool userBuyCard(double price, String cardName) {
    if (_activeUserPhone == null) return false;

    final user = _usersDatabase.firstWhere((u) => u['phone'] == _activeUserPhone);
    if (user['balance'] >= price && _totalSystemCards > 0) {
      _db.collection('system').doc('main_info').update({
        'totalSystemCards': FieldValue.increment(-1)
      });
      _db.collection('users').doc(_activeUserPhone).update({
        'balance': FieldValue.increment(-price),
        'purchasedCards': FieldValue.arrayUnion([cardName])
      });
      return true;
    }
    return false;
  }

  Future<void> updateDangerLimit(String phone, double newLimit) async {
    await _db.collection('users').doc(phone).update({'dangerLimit': newLimit});
  }

  Future<void> acceptRechargeRequest({
    required String requestId, 
    required String agentPhone, 
    required String agentName, 
    required double amount
  }) async {
    WriteBatch batch = _db.batch();

    DocumentReference agentRef = _db.collection('users').doc(agentPhone);
    batch.update(agentRef, {'balance': FieldValue.increment(amount)});

    DocumentReference requestRef = _db.collection('recharge_requests').doc(requestId);
    batch.update(requestRef, {'status': 'مقبول'});

    DocumentReference transactionRef = _db.collection('transactions').doc();
    batch.set(transactionRef, {
      'agentPhone': agentPhone,
      'agentName': agentName,
      'type': 'إيداع حوالة (موافقة إلكترونية)',
      'amount': amount,
      'timestamp': FieldValue.serverTimestamp(),
    });

    await batch.commit(); 
  }

  Future<void> rejectRechargeRequest(String requestId, String reason) async {
    await _db.collection('recharge_requests').doc(requestId).update({
      'status': 'مرفوض',
      'rejectReason': reason,
    });
  }

  Future<void> manualSettlement({
    required String agentPhone,
    required String agentName,
    required double amount, 
    required String reason,
  }) async {
    WriteBatch batch = _db.batch();

    DocumentReference agentRef = _db.collection('users').doc(agentPhone);
    batch.update(agentRef, {'balance': FieldValue.increment(amount)});

    DocumentReference transactionRef = _db.collection('transactions').doc();
    batch.set(transactionRef, {
      'agentPhone': agentPhone,
      'agentName': agentName,
      'type': amount > 0 ? 'تسوية يدوية (إضافة)' : 'تسوية يدوية (خصم)',
      'amount': amount,
      'reason': reason,
      'timestamp': FieldValue.serverTimestamp(),
    });

    await batch.commit();
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
