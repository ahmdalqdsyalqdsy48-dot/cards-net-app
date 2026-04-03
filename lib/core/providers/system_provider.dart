import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 

class SystemProvider extends ChangeNotifier {
  // 1. الاتصال المباشر بقاعدة بيانات جوجل
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 2. المتغيرات المحلية 
  double _adminMainBalance = 10000000.0; 
  int _totalSystemCards = 5000; 
  String? _activeUserPhone; 
  double _newsScrollSpeed = 40.0; // سرعة الشريط الإخباري

  List<Map<String, dynamic>> _usersDatabase = [
    {
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
    }
  ];
  
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
    // أ. مزامنة الخزينة والإعلانات وسرعة الشريط
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

    // ب. مزامنة قائمة المستخدمين والوكلاء
    _db.collection('users').snapshots().listen((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        _usersDatabase = snapshot.docs.map((doc) => doc.data()).toList();
      }
      
      if (!_usersDatabase.any((u) => u['role'] == 'super_admin')) {
        _db.collection('users').doc('774578241').set({
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
        });
      }
      notifyListeners();
    });

    // ج. مزامنة طلبات الشحن قيد الانتظار
    _db.collection('recharge_requests')
       .where('status', isEqualTo: 'قيد الانتظار')
       .snapshots().listen((snapshot) {
      _rechargeRequests = snapshot.docs.map((doc) => {'docId': doc.id, ...doc.data()}).toList();
      notifyListeners();
    });

    // د. مزامنة السجل المالي الشامل
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
  // 5. دوال الإدارة والإضافة (تم التصحيح بـ AWAIT 🛡️)
  // ==========================================
  
  // 👈 دالة إضافة الوكيل المصححة (تنتظر السيرفر وتفحص الأخطاء)
  Future<void> addAgent({
    required String name, 
    required String phone, 
    required String password,
    String? networkName, 
    String? profitMargin, 
    String? location,
  }) async {
    try {
      if (!checkUserExists(phone)) {
        // نستخدم await لضمان أن البيانات حُفظت فعلاً قبل إغلاق النافذة
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
        throw 'هذا الرقم مسجل مسبقاً في النظام!';
      }
    } catch (e) {
      throw 'فشل الحفظ في السحابة: $e';
    }
  }

  Future<void> updateNewsSpeed(double newSpeed) async {
    await _db.collection('system').doc('main_info').update({'newsScrollSpeed': newSpeed});
  }

  bool checkUserExists(String phone) => _usersDatabase.any((user) => user['phone'] == phone);

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

  // ==========================================
  // 6. العمليات المالية والمركز المالي
  // ==========================================

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

  Future<void> acceptRechargeRequest({
    required String requestId, 
    required String agentPhone, 
    required String agentName, 
    required double amount
  }) async {
    WriteBatch batch = _db.batch();
    batch.update(_db.collection('users').doc(agentPhone), {'balance': FieldValue.increment(amount)});
    batch.update(_db.collection('recharge_requests').doc(requestId), {'status': 'مقبول'});
    batch.set(_db.collection('transactions').doc(), {
      'agentPhone': agentPhone,
      'agentName': agentName,
      'type': 'إيداع حوالة (موافقة إلكترونية)',
      'amount': amount,
      'timestamp': FieldValue.serverTimestamp(),
    });
    await batch.commit(); 
  }

  Future<void> manualSettlement({
    required String agentPhone,
    required String agentName,
    required double amount, 
    required String reason,
  }) async {
    WriteBatch batch = _db.batch();
    batch.update(_db.collection('users').doc(agentPhone), {'balance': FieldValue.increment(amount)});
    batch.set(_db.collection('transactions').doc(), {
      'agentPhone': agentPhone,
      'agentName': agentName,
      'type': amount > 0 ? 'تسوية يدوية (إضافة)' : 'تسوية يدوية (خصم)',
      'amount': amount,
      'reason': reason,
      'timestamp': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  // (باقي الدوال: updateAgentDetails, deleteAgent, changeUserPassword, toggleBiometric تبقى كما هي)
  // ...
  
  Future<void> updateAgentDetails({
    required String oldPhone,
    required String newPhone,
    required String newName,
    required String newNetwork,
    required String newLocation,
    required String newProfit,
    required String newPassword,
  }) async {
    if (oldPhone == newPhone) {
      await _db.collection('users').doc(oldPhone).update({
        'name': newName,
        'networkName': newNetwork,
        'location': newLocation,
        'profitMargin': newProfit,
        'password': newPassword,
      });
    } else {
      if (checkUserExists(newPhone)) throw Exception('رقم الهاتف الجديد مستخدم بالفعل!');
      final docSnapshot = await _db.collection('users').doc(oldPhone).get();
      if (docSnapshot.exists) {
        Map<String, dynamic> oldData = docSnapshot.data()!;
        oldData['phone'] = newPhone;
        oldData['name'] = newName;
        oldData['networkName'] = newNetwork;
        oldData['location'] = newLocation;
        oldData['profitMargin'] = newProfit;
        oldData['password'] = newPassword;
        WriteBatch batch = _db.batch();
        batch.set(_db.collection('users').doc(newPhone), oldData); 
        batch.delete(_db.collection('users').doc(oldPhone));       
        await batch.commit(); 
        _activeUserPhone = _activeUserPhone == oldPhone ? newPhone : _activeUserPhone;
      }
    }
  }

  void toggleUserStatus(String phone, String currentStatus) {
    String newStatus = currentStatus == 'نشط' ? 'مجمد' : 'نشط';
    _db.collection('users').doc(phone).update({'status': newStatus});
  }

  void deleteAgent(String phone) => _db.collection('users').doc(phone).delete();

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
