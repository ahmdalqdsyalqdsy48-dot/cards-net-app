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
  
  // 👈 إضافة قائمة السجل الأسود (الصندوق الأسود)
  List<Map<String, dynamic>> _auditLogs = []; 

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

    // 👈 الاستماع للسجل الأسود (نجلب أحدث 50 حركة فقط للحفاظ على سرعة النظام)
    _db.collection('audit_logs')
       .orderBy('timestamp', descending: true)
       .limit(50)
       .snapshots().listen((snapshot) {
      _auditLogs = snapshot.docs.map((doc) => {'docId': doc.id, ...doc.data()}).toList();
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
  
  // 👈 دالة قراءة السجل الأسود لتصديره للشاشة
  List<Map<String, dynamic>> get auditLogs => _auditLogs;

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
  // 🛡️ دالة التسجيل الصامت (الصندوق الأسود)
  // ==========================================
  Future<void> logAction({required String action, required String details, required String severity}) async {
    if (_activeUserPhone == null) return; // لا تسجل إذا لم يكن هناك شخص مسجل دخوله

    // نجلب بيانات الشخص الذي قام بالحركة
    final user = _usersDatabase.firstWhere((u) => u['phone'] == _activeUserPhone, orElse: () => {'name': 'غير معروف', 'role': 'Unknown'});
    
    // تنسيق التاريخ والوقت
    final now = DateTime.now();
    final formattedDate = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    try {
      await _db.collection('audit_logs').add({
        'name': user['name'] ?? 'غير معروف',
        'phone': _activeUserPhone,
        'role': user['role'] ?? 'Unknown',
        'action': action,
        'details': details,
        'datetime': formattedDate,
        'timestamp': FieldValue.serverTimestamp(), // للترتيب السحابي
        'ip': 'Cloud System', 
        'severity': severity, // 'normal', 'medium', 'critical'
      });
    } catch (e) {
      // نتجاهل الخطأ لكي لا تتعطل العملية الأصلية
    }
  }

  // ==========================================
  // 5. دوال الإدارة والتحكم 🚀
  // ==========================================
  
  Future<void> updateNewsSpeed(double newSpeed) async {
    try {
      await _db.collection('system').doc('main_info').update({'newsScrollSpeed': newSpeed});
    } catch (e) {}
  }

  Future<bool> checkUserExists(String phone) async {
    try {
      final doc = await _db.collection('users').doc(phone).get().timeout(const Duration(seconds: 5));
      return doc.exists;
    } catch (e) {
      return false; 
    }
  }

  Future<Map<String, dynamic>?> loginUser(String phone, String password) async {
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
      
      try {
        _db.collection('users').doc('774578241').set(superAdminData);
        _db.collection('system').doc('main_info').set({
          'adminMainBalance': 10000000.0,
          'totalSystemCards': 5000,
          'announcements': ['أهلاً بك في شبكة كروت نت...'],
          'newsScrollSpeed': 40.0,
        });
      } catch (e) {}
      
      _activeUserPhone = phone;
      notifyListeners();
      
      // 👈 تسجيل الدخول في السجل
      logAction(action: 'تسجيل دخول', details: 'تم تسجيل الدخول بنجاح لمالك النظام', severity: 'normal');
      
      return superAdminData; 
    }

    try {
      final doc = await _db.collection('users').doc(phone).get().timeout(const Duration(seconds: 7));
      if (doc.exists) {
        final userData = doc.data() as Map<String, dynamic>;
        if (userData['password'] == password) {
          _activeUserPhone = phone;
          notifyListeners();
          
          logAction(action: 'تسجيل دخول', details: 'تم تسجيل الدخول بواسطة: ${userData['name']}', severity: 'normal');
          return userData;
        }
      }
      return null; 
    } catch (e) {
      return null; 
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
      
      // 👈 تسجيل الحدث
      logAction(action: 'إضافة وكيل جديد', details: 'تم إضافة وكيل جديد باسم "$name" ورقم $phone', severity: 'medium');
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
      
      // 👈 تسجيل الحدث
      logAction(action: 'تعديل بيانات وكيل', details: 'تم تعديل بيانات الوكيل صاحب الرقم $oldPhone', severity: 'medium');
    }
  }

  void toggleUserStatus(String phone, String currentStatus) {
    String newStatus = currentStatus == 'نشط' ? 'مجمد' : 'نشط';
    _db.collection('users').doc(phone).update({'status': newStatus});
    
    // 👈 تسجيل الحدث
    logAction(action: 'تغيير حالة حساب', details: 'تم تغيير حالة الحساب $phone إلى [$newStatus]', severity: 'critical');
  }

  void deleteAgent(String phone) {
    _db.collection('users').doc(phone).delete();
    // 👈 تسجيل الحدث
    logAction(action: 'حذف وكيل', details: 'تم حذف الوكيل $phone نهائياً من النظام', severity: 'critical');
  }

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
      
      // 👈 تسجيل الحدث للوكيل
      logAction(action: 'شراء كرت', details: 'تم سحب كرت $cardName بسعر $price ريال', severity: 'normal');
      return true;
    }
    return false;
  }

  Future<void> updateDangerLimit(String phone, double newLimit) async {
    await _db.collection('users').doc(phone).update({'dangerLimit': newLimit});
    logAction(action: 'تعديل حد الخطر', details: 'تم تعديل حد الخطر للرقم $phone ليصبح $newLimit ريال', severity: 'medium');
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
    
    // 👈 تسجيل الحدث
    logAction(action: 'موافقة على شحن', details: 'تم قبول طلب شحن وإضافة $amount ريال للوكيل $agentName', severity: 'normal');
  }

  Future<void> rejectRechargeRequest(String requestId, String reason) async {
    await _db.collection('recharge_requests').doc(requestId).update({
      'status': 'مرفوض',
      'rejectReason': reason,
    });
    logAction(action: 'رفض طلب شحن', details: 'تم رفض طلب شحن. السبب: $reason', severity: 'medium');
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
    
    // 👈 تسجيل الحدث
    String actionType = amount > 0 ? "إضافة" : "خصم";
    logAction(action: 'تسوية مالية يدوية ($actionType)', details: 'تم $actionType مبلغ $amount للوكيل $agentName. السبب: $reason', severity: 'critical');
  }

  // ==========================================
  // 7. إعدادات الأمان
  // ==========================================
  bool changeUserPassword(String oldPassword, String newPassword) {
    if (_activeUserPhone == null) return false;
    final user = _usersDatabase.firstWhere((u) => u['phone'] == _activeUserPhone);
    if (user['password'] == oldPassword) {
      _db.collection('users').doc(_activeUserPhone).update({'password': newPassword});
      logAction(action: 'تغيير كلمة المرور', details: 'تم تغيير كلمة المرور بنجاح', severity: 'medium');
      return true; 
    }
    return false; 
  }

  void toggleBiometric(bool isEnabled) {
    if (_activeUserPhone == null) return;
    _db.collection('users').doc(_activeUserPhone).update({'isBiometricEnabled': isEnabled});
  }
}
