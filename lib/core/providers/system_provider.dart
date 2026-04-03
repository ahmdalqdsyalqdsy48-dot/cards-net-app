import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 

class SystemProvider extends ChangeNotifier {
  // 1. الاتصال بقاعدة البيانات
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 2. المتغيرات المحلية
  double _adminMainBalance = 10000000.0; 
  int _totalSystemCards = 5000; 
  String? _activeUserPhone; 
  double _newsScrollSpeed = 40.0; // سرعة الشريط الإخباري

  List<Map<String, dynamic>> _usersDatabase = [];
  List<String> _announcements = []; 
  List<Map<String, dynamic>> _rechargeRequests = []; 
  List<Map<String, dynamic>> _transactionsLedger = []; 

  // ==========================================
  // 3. تهيئة النظام والمزامنة اللحظية
  // ==========================================
  SystemProvider() {
    _initDatabaseSync();
  }

  void _initDatabaseSync() {
    // مزامنة معلومات النظام والإعلانات والسرعة
    _db.collection('system').doc('main_info').snapshots().listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data()!;
        _adminMainBalance = (data['adminMainBalance'] ?? 10000000.0).toDouble();
        _totalSystemCards = data['totalSystemCards'] ?? 5000;
        _announcements = List<String>.from(data['announcements'] ?? ['أهلاً بك في شبكة كروت نت...']);
        _newsScrollSpeed = (data['newsScrollSpeed'] ?? 40.0).toDouble();
        notifyListeners();
      } else {
        _db.collection('system').doc('main_info').set({
          'adminMainBalance': 10000000.0,
          'totalSystemCards': 5000,
          'announcements': ['أهلاً بك في شبكة كروت نت...'],
          'newsScrollSpeed': 40.0,
        });
      }
    });

    // مزامنة المستخدمين
    _db.collection('users').snapshots().listen((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        _usersDatabase = snapshot.docs.map((doc) => doc.data()).toList();
      }
      notifyListeners();
    });

    // مزامنة طلبات الشحن
    _db.collection('recharge_requests')
       .where('status', isEqualTo: 'قيد الانتظار')
       .snapshots().listen((snapshot) {
      _rechargeRequests = snapshot.docs.map((doc) => {'docId': doc.id, ...doc.data()}).toList();
      notifyListeners();
    });

    // مزامنة السجل المالي
    _db.collection('transactions')
       .orderBy('timestamp', descending: true)
       .snapshots().listen((snapshot) {
      _transactionsLedger = snapshot.docs.map((doc) => {'docId': doc.id, ...doc.data()}).toList();
      notifyListeners();
    });
  }

  // ==========================================
  // 4. دوال القراءة (Getters)
  // ==========================================
  double get adminMainBalance => _adminMainBalance;
  int get totalSystemCards => _totalSystemCards;
  List<String> get announcements => _announcements; 
  double get newsScrollSpeed => _newsScrollSpeed;

  List<Map<String, dynamic>> get agentsList => _usersDatabase.where((u) => u['role'] == 'agent').toList();
  List<Map<String, dynamic>> get usersList => _usersDatabase.where((u) => u['role'] == 'user').toList();
  List<Map<String, dynamic>> get pendingRechargeRequests => _rechargeRequests;
  List<Map<String, dynamic>> get transactionsLedger => _transactionsLedger;

  String get currentUserName {
    final user = _usersDatabase.firstWhere((u) => u['phone'] == _activeUserPhone, orElse: () => {});
    return user['name'] ?? 'مستخدم غير معروف';
  }

  String get currentUserPhone => _activeUserPhone ?? 'لا يوجد';

  double get currentUserBalance {
    final user = _usersDatabase.firstWhere((u) => u['phone'] == _activeUserPhone, orElse: () => {});
    return (user['balance'] ?? 0.0).toDouble();
  }

  List<String> get userPurchasedCards {
    final user = _usersDatabase.firstWhere((u) => u['phone'] == _activeUserPhone, orElse: () => {});
    return List<String>.from(user['purchasedCards'] ?? []);
  }

  bool get isBiometricCurrentlyEnabled {
    final user = _usersDatabase.firstWhere((u) => u['phone'] == _activeUserPhone, orElse: () => {});
    return user['isBiometricEnabled'] ?? false;
  }

  // ==========================================
  // 5. دوال الإدارة والتوثيق (Auth & Users)
  // ==========================================
  
  bool checkUserExists(String phone) => _usersDatabase.any((u) => u['phone'] == phone);

  Map<String, dynamic>? loginUser(String phone, String password) {
    try {
      final user = _usersDatabase.firstWhere((u) => u['phone'] == phone && u['password'] == password);
      _activeUserPhone = phone;
      notifyListeners();
      return user;
    } catch (e) { return null; }
  }

  // 👈 استعادة دالة تسجيل المستخدم الجديد (المفقودة)
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
  }

  // ==========================================
  // 6. دوال الوكلاء والعمليات المالية
  // ==========================================

  Future<void> addAgent({required String name, required String phone, required String password, String? networkName, String? profitMargin, String? location}) async {
    await _db.collection('users').doc(phone).set({
      'id': 'AGENT_${DateTime.now().millisecondsSinceEpoch}',
      'name': name, 'phone': phone, 'password': password, 'role': 'agent',
      'networkName': networkName ?? 'غير محدد', 'profitMargin': profitMargin ?? '0%',
      'location': location ?? 'غير محدد', 'balance': 0.0, 'dangerLimit': 0.0,
      'status': 'نشط', 'purchasedCards': [], 'isBiometricEnabled': false,
    });
  }

  // 👈 استعادة دالة تحديث حد الخطر (المفقودة)
  Future<void> updateDangerLimit(String phone, double newLimit) async {
    await _db.collection('users').doc(phone).update({'dangerLimit': newLimit});
  }

  Future<void> acceptRechargeRequest({required String requestId, required String agentPhone, required String agentName, required double amount}) async {
    WriteBatch batch = _db.batch();
    batch.update(_db.collection('users').doc(agentPhone), {'balance': FieldValue.increment(amount)});
    batch.update(_db.collection('recharge_requests').doc(requestId), {'status': 'مقبول'});
    batch.set(_db.collection('transactions').doc(), {
      'agentPhone': agentPhone, 'agentName': agentName, 'type': 'إيداع حوالة',
      'amount': amount, 'timestamp': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  // 👈 استعادة دالة رفض طلب الشحن (المفقودة)
  Future<void> rejectRechargeRequest(String requestId, String reason) async {
    await _db.collection('recharge_requests').doc(requestId).update({
      'status': 'مرفوض',
      'rejectReason': reason,
    });
  }

  Future<void> manualSettlement({required String agentPhone, required String agentName, required double amount, required String reason}) async {
    WriteBatch batch = _db.batch();
    batch.update(_db.collection('users').doc(agentPhone), {'balance': FieldValue.increment(amount)});
    batch.set(_db.collection('transactions').doc(), {
      'agentPhone': agentPhone, 'agentName': agentName, 'type': amount > 0 ? 'إضافة يدوية' : 'خصم يدوي',
      'amount': amount, 'reason': reason, 'timestamp': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  bool userBuyCard(double price, String cardName) {
    if (_activeUserPhone == null) return false;
    final user = _usersDatabase.firstWhere((u) => u['phone'] == _activeUserPhone);
    if (user['balance'] >= price && _totalSystemCards > 0) {
      _db.collection('system').doc('main_info').update({'totalSystemCards': FieldValue.increment(-1)});
      _db.collection('users').doc(_activeUserPhone).update({
        'balance': FieldValue.increment(-price),
        'purchasedCards': FieldValue.arrayUnion([cardName])
      });
      return true;
    }
    return false;
  }

  // ==========================================
  // 7. الإعدادات والأمان
  // ==========================================
  Future<void> updateNewsSpeed(double newSpeed) async {
    await _db.collection('system').doc('main_info').update({'newsScrollSpeed': newSpeed});
  }

  void toggleBiometric(bool isEnabled) {
    if (_activeUserPhone != null) _db.collection('users').doc(_activeUserPhone).update({'isBiometricEnabled': isEnabled});
  }
}
