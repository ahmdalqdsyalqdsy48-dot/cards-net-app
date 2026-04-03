import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 

class SystemProvider extends ChangeNotifier {
  // 1. الاتصال المباشر بقاعدة بيانات جوجل
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 2. المتغيرات المحلية 
  double _adminMainBalance = 10000000.0; 
  int _totalSystemCards = 5000; 
  String? _activeUserPhone; 
  
  List<Map<String, dynamic>> _usersDatabase = [
    {
      'id': 'SUPER_ADMIN_01',
      'name': 'مالك النظام',
      'phone': '774578241',
      'password': '75486958aaa',
      'role': 'super_admin',
      'balance': 0.0,
      'dangerLimit': 0.0, // 👈 إضافة حد الخطر الافتراضي
      'status': 'نشط',
      'purchasedCards': [],
      'isBiometricEnabled': false,
    }
  ];
  
  List<String> _announcements = []; 
  
  // 👈 القوائم المالية الجديدة
  List<Map<String, dynamic>> _rechargeRequests = []; 
  List<Map<String, dynamic>> _transactionsLedger = []; 

  // ==========================================
  // 3. تهيئة النظام (الاستماع للسحابة لحظة بلحظة)
  // ==========================================
  SystemProvider() {
    _initDatabaseSync();
  }

  void _initDatabaseSync() {
    // أ. الاستماع لملف الخزينة
    _db.collection('system').doc('main_info').snapshots().listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data()!;
        _adminMainBalance = (data['adminMainBalance'] ?? 10000000.0).toDouble();
        _totalSystemCards = data['totalSystemCards'] ?? 5000;
        _announcements = List<String>.from(data['announcements'] ?? ['أهلاً بك في شبكة كروت نت...']);
        notifyListeners();
      } else {
        _db.collection('system').doc('main_info').set({
          'adminMainBalance': 10000000.0,
          'totalSystemCards': 5000,
          'announcements': ['أهلاً بك في شبكة كروت نت...'],
        });
      }
    });

    // ب. الاستماع لقائمة المستخدمين
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

    // ج. الاستماع لطلبات الشحن (التي حالتها 'قيد الانتظار' فقط لتخفيف الضغط)
    _db.collection('recharge_requests')
       .where('status', isEqualTo: 'قيد الانتظار')
       .snapshots().listen((snapshot) {
      _rechargeRequests = snapshot.docs.map((doc) => {'docId': doc.id, ...doc.data()}).toList();
      notifyListeners();
    });

    // د. الاستماع للسجل المالي الشامل (مترتبة من الأحدث للأقدم)
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

  // ==========================================
  // 5. دوال الإضافة والتعديل 
  // ==========================================
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

  void registerNewUser({required String name, required String phone, required String password, required String role}) {
    _db.collection('users').doc(phone).set({
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

  void addAgent({
    required String name, 
    required String phone, 
    required String password,
    String? networkName, 
    String? profitMargin, 
    String? location,
  }) {
    if (!checkUserExists(phone)) {
      _db.collection('users').doc(phone).set({
        'id': 'AGENT_${DateTime.now().millisecondsSinceEpoch}',
        'name': name,
        'phone': phone,
        'password': password,
        'role': 'agent',
        'networkName': networkName ?? 'غير محدد',
        'profitMargin': profitMargin ?? 'غير محدد',
        'location': location ?? 'غير محدد',
        'balance': 0.0,
        'dangerLimit': 0.0, // 👈 حد الخطر للوكيل الجديد
        'status': 'نشط',
        'purchasedCards': [],
        'isBiometricEnabled': false,
      });
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
    if (oldPhone == newPhone) {
      await _db.collection('users').doc(oldPhone).update({
        'name': newName,
        'networkName': newNetwork,
        'location': newLocation,
        'profitMargin': newProfit,
        'password': newPassword,
      });
    } else {
      if (checkUserExists(newPhone)) throw Exception('رقم الهاتف الجديد مستخدم بالفعل لوكيل آخر!');

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

  // ==========================================
  // 6. العمليات المالية الصارمة (المركز المالي) 💸
  // ==========================================

  // أ. تحديث حد الخطر للوكيل
  Future<void> updateDangerLimit(String phone, double newLimit) async {
    await _db.collection('users').doc(phone).update({'dangerLimit': newLimit});
  }

  // ب. قبول طلب الشحن (عملية Batch صارمة)
  Future<void> acceptRechargeRequest({
    required String requestId, 
    required String agentPhone, 
    required String agentName, 
    required double amount
  }) async {
    WriteBatch batch = _db.batch();

    // 1. إضافة الرصيد لمحفظة الوكيل
    DocumentReference agentRef = _db.collection('users').doc(agentPhone);
    batch.update(agentRef, {'balance': FieldValue.increment(amount)});

    // 2. تحديث حالة الطلب إلى مقبول
    DocumentReference requestRef = _db.collection('recharge_requests').doc(requestId);
    batch.update(requestRef, {'status': 'مقبول'});

    // 3. تسجيل العملية في السجل الشامل
    DocumentReference transactionRef = _db.collection('transactions').doc();
    batch.set(transactionRef, {
      'agentPhone': agentPhone,
      'agentName': agentName,
      'type': 'إيداع حوالة (موافقة إلكترونية)',
      'amount': amount,
      'timestamp': FieldValue.serverTimestamp(),
    });

    await batch.commit(); // تنفيذ جميع الأوامر أو التراجع عنها معاً
  }

  // ج. رفض طلب الشحن
  Future<void> rejectRechargeRequest(String requestId, String reason) async {
    await _db.collection('recharge_requests').doc(requestId).update({
      'status': 'مرفوض',
      'rejectReason': reason,
    });
  }

  // د. التسوية اليدوية (خصم أو إضافة)
  Future<void> manualSettlement({
    required String agentPhone,
    required String agentName,
    required double amount, // قيمة موجبة للإضافة، وسالبة للخصم
    required String reason,
  }) async {
    WriteBatch batch = _db.batch();

    // 1. تحديث المحفظة
    DocumentReference agentRef = _db.collection('users').doc(agentPhone);
    batch.update(agentRef, {'balance': FieldValue.increment(amount)});

    // 2. تسجيل العملية في السجل مع السبب
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
