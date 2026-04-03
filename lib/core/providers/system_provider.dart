import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 

class SystemProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // المتغيرات الأساسية
  double _adminMainBalance = 10000000.0; 
  int _totalSystemCards = 5000; 
  String? _activeUserPhone; 
  double _newsScrollSpeed = 40.0;

  List<Map<String, dynamic>> _usersDatabase = [];
  List<String> _announcements = []; 
  List<Map<String, dynamic>> _rechargeRequests = []; 
  List<Map<String, dynamic>> _transactionsLedger = []; 

  SystemProvider() { _initDatabaseSync(); }

  void _initDatabaseSync() {
    // 1. مزامنة النظام (الخزينة + الأخبار)
    _db.collection('system').doc('main_info').snapshots().listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data()!;
        _adminMainBalance = (data['adminMainBalance'] ?? 10000000.0).toDouble();
        _totalSystemCards = data['totalSystemCards'] ?? 5000;
        _announcements = List<String>.from(data['announcements'] ?? []);
        _newsScrollSpeed = (data['newsScrollSpeed'] ?? 40.0).toDouble();
        notifyListeners();
      }
    });

    // 2. مزامنة المستخدمين
    _db.collection('users').snapshots().listen((snapshot) {
      _usersDatabase = snapshot.docs.map((doc) => doc.data()).toList();
      notifyListeners();
    });

    // 3. مزامنة الطلبات والسجلات
    _db.collection('recharge_requests').where('status', isEqualTo: 'قيد الانتظار').snapshots().listen((snapshot) {
      _rechargeRequests = snapshot.docs.map((doc) => {'docId': doc.id, ...doc.data()}).toList();
      notifyListeners();
    });

    _db.collection('transactions').orderBy('timestamp', descending: true).snapshots().listen((snapshot) {
      _transactionsLedger = snapshot.docs.map((doc) => {'docId': doc.id, ...doc.data()}).toList();
      notifyListeners();
    });
  }

  // --- Getters ---
  double get adminMainBalance => _adminMainBalance;
  int get totalSystemCards => _totalSystemCards;
  List<String> get announcements => _announcements; 
  double get newsScrollSpeed => _newsScrollSpeed;
  List<Map<String, dynamic>> get agentsList => _usersDatabase.where((u) => u['role'] == 'agent').toList();
  List<Map<String, dynamic>> get usersList => _usersDatabase.where((u) => u['role'] == 'user').toList();
  List<Map<String, dynamic>> get pendingRechargeRequests => _rechargeRequests;
  List<Map<String, dynamic>> get transactionsLedger => _transactionsLedger;
  String get currentUserPhone => _activeUserPhone ?? '';
  String get currentUserName => _usersDatabase.firstWhere((u) => u['phone'] == _activeUserPhone, orElse: () => {})['name'] ?? 'غير معروف';
  double get currentUserBalance => (_usersDatabase.firstWhere((u) => u['phone'] == _activeUserPhone, orElse: () => {})['balance'] ?? 0.0).toDouble();
  List<String> get userPurchasedCards => List<String>.from(_usersDatabase.firstWhere((u) => u['phone'] == _activeUserPhone, orElse: () => {})['purchasedCards'] ?? []);
  bool get isBiometricCurrentlyEnabled => _usersDatabase.firstWhere((u) => u['phone'] == _activeUserPhone, orElse: () => {})['isBiometricEnabled'] ?? false;

  // --- دوال الإدارة والتوثيق ---
  bool checkUserExists(String phone) => _usersDatabase.any((u) => u['phone'] == phone);

  Map<String, dynamic>? loginUser(String phone, String password) {
    try {
      final user = _usersDatabase.firstWhere((u) => u['phone'] == phone && u['password'] == password);
      _activeUserPhone = phone;
      notifyListeners();
      return user;
    } catch (e) { return null; }
  }

  Future<void> registerNewUser({required String name, required String phone, required String password, required String role}) async {
    await _db.collection('users').doc(phone).set({
      'id': 'USER_${DateTime.now().millisecondsSinceEpoch}', 'name': name, 'phone': phone,
      'password': password, 'role': role, 'balance': 0.0, 'status': 'نشط', 'purchasedCards': [], 'isBiometricEnabled': false,
    });
  }

  Future<void> changeUserPassword(String oldPassword, String newPassword) async {
    final user = _usersDatabase.firstWhere((u) => u['phone'] == _activeUserPhone);
    if (user['password'] == oldPassword) {
      await _db.collection('users').doc(_activeUserPhone!).update({'password': newPassword});
    } else { throw 'كلمة المرور القديمة خاطئة'; }
  }

  // --- دوال إدارة الوكلاء (المفقودة التي سببت الخطأ) ---
  Future<void> addAgent({required String name, required String phone, required String password, String? networkName, String? profitMargin, String? location}) async {
    await _db.collection('users').doc(phone).set({
      'id': 'AGENT_${DateTime.now().millisecondsSinceEpoch}', 'name': name, 'phone': phone, 'password': password,
      'role': 'agent', 'networkName': networkName ?? '', 'profitMargin': profitMargin ?? '0%', 'location': location ?? '',
      'balance': 0.0, 'dangerLimit': 0.0, 'status': 'نشط', 'purchasedCards': [], 'isBiometricEnabled': false,
    });
  }

  Future<void> updateAgentDetails({required String oldPhone, required String newPhone, required String newName, required String newNetwork, required String newLocation, required String newProfit, required String newPassword}) async {
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

  Future<void> toggleUserStatus(String phone, String currentStatus) async {
    await _db.collection('users').doc(phone).update({'status': currentStatus == 'نشط' ? 'مجمد' : 'نشط'});
  }

  Future<void> deleteAgent(String phone) async {
    await _db.collection('users').doc(phone).delete();
  }

  // --- دوال العمليات المالية ---
  Future<void> updateDangerLimit(String phone, double newLimit) async {
    await _db.collection('users').doc(phone).update({'dangerLimit': newLimit});
  }

  Future<void> acceptRechargeRequest({required String requestId, required String agentPhone, required String agentName, required double amount}) async {
    WriteBatch batch = _db.batch();
    batch.update(_db.collection('users').doc(agentPhone), {'balance': FieldValue.increment(amount)});
    batch.update(_db.collection('recharge_requests').doc(requestId), {'status': 'مقبول'});
    batch.set(_db.collection('transactions').doc(), {'agentPhone': agentPhone, 'agentName': agentName, 'type': 'إيداع حوالة', 'amount': amount, 'timestamp': FieldValue.serverTimestamp()});
    await batch.commit();
  }

  Future<void> rejectRechargeRequest(String requestId, String reason) async {
    await _db.collection('recharge_requests').doc(requestId).update({'status': 'مرفوض', 'rejectReason': reason});
  }

  Future<void> manualSettlement({required String agentPhone, required String agentName, required double amount, required String reason}) async {
    WriteBatch batch = _db.batch();
    batch.update(_db.collection('users').doc(agentPhone), {'balance': FieldValue.increment(amount)});
    batch.set(_db.collection('transactions').doc(), {'agentPhone': agentPhone, 'agentName': agentName, 'type': amount > 0 ? 'إضافة' : 'خصم', 'amount': amount, 'reason': reason, 'timestamp': FieldValue.serverTimestamp()});
    await batch.commit();
  }

  bool userBuyCard(double price, String cardName) {
    if (currentUserBalance >= price && totalSystemCards > 0) {
      _db.collection('system').doc('main_info').update({'totalSystemCards': FieldValue.increment(-1)});
      _db.collection('users').doc(_activeUserPhone!).update({'balance': FieldValue.increment(-price), 'purchasedCards': FieldValue.arrayUnion([cardName])});
      return true;
    }
    return false;
  }

  // --- الإعدادات ---
  Future<void> updateNewsSpeed(double newSpeed) async {
    await _db.collection('system').doc('main_info').update({'newsScrollSpeed': newSpeed});
  }

  void toggleBiometric(bool isEnabled) {
    if (_activeUserPhone != null) _db.collection('users').doc(_activeUserPhone!).update({'isBiometricEnabled': isEnabled});
  }
}
