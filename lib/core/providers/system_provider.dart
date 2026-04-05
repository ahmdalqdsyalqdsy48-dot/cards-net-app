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
  List<Map<String, dynamic>> _auditLogs = []; 

  // ==========================================
  // متغيرات النسخ الاحتياطي والحسابات البنكية
  // ==========================================
  bool _isAutoBackupEnabled = true;
  String _backupFrequency = 'يومياً';
  String _backupTime = '04:00 فجراً';
  String _emergencyEmail = '';
  bool _isDriveLinked = false;
  bool _isDropboxLinked = false;
  List<Map<String, dynamic>> _backupsList = [];
  List<Map<String, dynamic>> _bankAccounts = [];

  // ==========================================
  // 🆕 متغيرات الكوبونات والاشتراكات
  // ==========================================
  List<Map<String, dynamic>> _coupons = [];

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

    _db.collection('audit_logs')
       .orderBy('timestamp', descending: true)
       .limit(50)
       .snapshots().listen((snapshot) {
      _auditLogs = snapshot.docs.map((doc) => {'docId': doc.id, ...doc.data()}).toList();
      notifyListeners();
    });

    _db.collection('system').doc('backup_settings').snapshots().listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data()!;
        _isAutoBackupEnabled = data['isAutoBackupEnabled'] ?? true;
        _backupFrequency = data['backupFrequency'] ?? 'يومياً';
        _backupTime = data['backupTime'] ?? '04:00 فجراً';
        _emergencyEmail = data['emergencyEmail'] ?? '';
        _isDriveLinked = data['isDriveLinked'] ?? false;
        _isDropboxLinked = data['isDropboxLinked'] ?? false;
        notifyListeners();
      } else {
        _db.collection('system').doc('backup_settings').set({
          'isAutoBackupEnabled': true,
          'backupFrequency': 'يومياً',
          'backupTime': '04:00 فجراً',
          'emergencyEmail': '',
          'isDriveLinked': false,
          'isDropboxLinked': false,
        });
      }
    });

    _db.collection('backups').orderBy('timestamp', descending: true).snapshots().listen((snapshot) {
      _backupsList = snapshot.docs.map((doc) => {'docId': doc.id, ...doc.data()}).toList();
      notifyListeners();
    });

    _db.collection('bank_accounts').orderBy('order').snapshots().listen((snapshot) {
      _bankAccounts = snapshot.docs.map((doc) => {'docId': doc.id, ...doc.data()}).toList();
      notifyListeners();
    });

    // 👈 🆕 الاستماع للكوبونات الترويجية
    _db.collection('coupons').orderBy('createdAt', descending: true).snapshots().listen((snapshot) {
      _coupons = snapshot.docs.map((doc) => {'docId': doc.id, ...doc.data()}).toList();
      notifyListeners();
    });
  }

  // ==========================================
  // 4. دوال القراءة والإحصائيات
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
  List<Map<String, dynamic>> get auditLogs => _auditLogs;

  bool get isAutoBackupEnabled => _isAutoBackupEnabled;
  String get backupFrequency => _backupFrequency;
  String get backupTime => _backupTime;
  String get emergencyEmail => _emergencyEmail;
  bool get isDriveLinked => _isDriveLinked;
  bool get isDropboxLinked => _isDropboxLinked;
  List<Map<String, dynamic>> get backupsList => _backupsList;
  List<Map<String, dynamic>> get bankAccounts => _bankAccounts;
  
  // قراءة الكوبونات
  List<Map<String, dynamic>> get coupons => _coupons;

  // 👈 🆕 دالة ديناميكية لحساب إحصائيات الرادار (Dashboard)
  Map<String, dynamic> get subscriptionStats {
    int active = 0;
    int expiringSoon = 0;
    int frozen = 0;

    for (var agent in agentsList) {
      String status = agent['subStatus'] ?? 'نشط';
      if (status == 'نشط' || status == 'فترة مجانية') {
        active++;
      } else if (status == 'إنذار') {
        expiringSoon++;
      } else if (status == 'مجمد' || status == 'موقوف مؤقتاً') {
        frozen++;
      }
    }

    // تقدير الأرباح (مثال: كل وكيل نشط يدفع 3000 ريال شهرياً)
    double expectedRevenue = active * 3000.0;

    return {
      'active': active,
      'expiringSoon': expiringSoon,
      'frozen': frozen,
      'expectedRevenue': expectedRevenue,
    };
  }

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
  Future<void> logAction({required String action, required String details, required String severity, String? targetPhone}) async {
    if (_activeUserPhone == null) return; 

    final user = _usersDatabase.firstWhere((u) => u['phone'] == _activeUserPhone, orElse: () => {'name': 'غير معروف', 'role': 'Unknown'});
    
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
        'timestamp': FieldValue.serverTimestamp(), 
        'ip': 'Cloud System', 
        'severity': severity,
        'targetPhone': targetPhone, // 👈 لتسهيل فلترة سجل وكيل معين لاحقاً
      });
    } catch (e) {}
  }

  // ==========================================
  // 5. دوال الإدارة والتحكم السحابية
  // ==========================================
  
  Future<void> updateNewsSpeed(double newSpeed) async {
    try {
      await _db.collection('system').doc('main_info').update({'newsScrollSpeed': newSpeed});
    } catch (e) {
      throw 'خطأ في تحديث السرعة: $e';
    }
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
    try {
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
        'createdAt': FieldValue.serverTimestamp(),
      });
      _activeUserPhone = phone;
      notifyListeners();
    } catch (e) {
      throw 'فشل تسجيل المستخدم: $e';
    }
  }

  Future<void> addAgent({
    required String name, 
    required String phone, 
    required String password,
    String? networkName, 
    String? profitMargin, 
    String? location,
  }) async {
    try {
      bool exists = await checkUserExists(phone);
      if (!exists) {
        // حساب تاريخ انتهاء افتراضي (بعد شهر من الآن) للوكلاء الجدد
        final DateTime nextMonth = DateTime.now().add(const Duration(days: 30));
        final String expiryDate = '${nextMonth.year}-${nextMonth.month.toString().padLeft(2, '0')}-${nextMonth.day.toString().padLeft(2, '0')}';

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
          'subPlan': 'باقة افتراضية', // 👈 حقل الاشتراك الجديد
          'subStatus': 'نشط',       // 👈 حالة الاشتراك
          'subExpiry': expiryDate,  // 👈 تاريخ الانتهاء
          'purchasedCards': [],
          'isBiometricEnabled': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
        
        logAction(action: 'إضافة وكيل جديد', details: 'تم إضافة وكيل جديد باسم "$name" ورقم $phone', severity: 'medium');
      } else {
        throw 'رقم الهاتف مسجل مسبقاً في النظام!';
      }
    } catch (e) {
      throw 'حدث خطأ أثناء إضافة الوكيل السحابية: $e';
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
    try {
      final doc = await _db.collection('users').doc(oldPhone).get();
      if (doc.exists) {
        Map<String, dynamic> data = doc.data()!;
        data.addAll({'phone': newPhone, 'name': newName, 'networkName': newNetwork, 'location': newLocation, 'profitMargin': newProfit, 'password': newPassword});
        WriteBatch batch = _db.batch();
        batch.set(_db.collection('users').doc(newPhone), data);
        if (oldPhone != newPhone) batch.delete(_db.collection('users').doc(oldPhone));
        await batch.commit();
        
        logAction(action: 'تعديل بيانات وكيل', details: 'تم تعديل بيانات الوكيل صاحب الرقم $oldPhone', severity: 'medium');
      }
    } catch (e) {
      throw 'فشل تعديل بيانات الوكيل: $e';
    }
  }

  void toggleUserStatus(String phone, String currentStatus) {
    try {
      String newStatus = currentStatus == 'نشط' ? 'مجمد' : 'نشط';
      _db.collection('users').doc(phone).update({'status': newStatus});
      logAction(action: 'تغيير حالة حساب', details: 'تم تغيير حالة الحساب $phone إلى [$newStatus]', severity: 'critical', targetPhone: phone);
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  void deleteAgent(String phone) {
    try {
      _db.collection('users').doc(phone).delete();
      logAction(action: 'حذف وكيل', details: 'تم حذف الوكيل $phone نهائياً من النظام', severity: 'critical');
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

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
    try {
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
      logAction(action: 'موافقة على شحن', details: 'تم قبول طلب شحن وإضافة $amount ريال للوكيل $agentName', severity: 'normal');
    } catch (e) {
      throw 'فشل في قبول الشحن: $e';
    }
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
    try {
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
      
      String actionType = amount > 0 ? "إضافة" : "خصم";
      logAction(action: 'تسوية مالية يدوية ($actionType)', details: 'تم $actionType مبلغ $amount للوكيل $agentName. السبب: $reason', severity: 'critical');
    } catch (e) {
      throw 'فشل التسوية اليدوية: $e';
    }
  }

  // ==========================================
  // 🆕 دوال الاشتراكات والكوبونات (العمليات الجراحية)
  // ==========================================

  // 1. تطبيق خطة اشتراك جديدة على الوكلاء
  Future<void> applySubscriptionPlan({
    required int targetingFilter, // 1: الكل, 2: وكيل محدد
    required String planName,
    required int durationMonths,
    String? targetAgentPhone,
  }) async {
    try {
      WriteBatch batch = _db.batch();
      
      // حساب تاريخ الانتهاء الجديد
      final DateTime newExpiry = DateTime.now().add(Duration(days: durationMonths * 30));
      final String formattedExpiry = '${newExpiry.year}-${newExpiry.month.toString().padLeft(2, '0')}-${newExpiry.day.toString().padLeft(2, '0')}';

      if (targetingFilter == 1) {
        // تطبيق على كل الوكلاء
        for (var agent in agentsList) {
          DocumentReference ref = _db.collection('users').doc(agent['phone']);
          batch.update(ref, {
            'subPlan': planName,
            'subExpiry': formattedExpiry,
            'subStatus': 'نشط',
          });
        }
        logAction(action: 'تطبيق خطة شاملة', details: 'تم تطبيق خطة [$planName] على جميع الوكلاء', severity: 'critical');
      } else if (targetingFilter == 2 && targetAgentPhone != null) {
        // تطبيق على وكيل واحد
        DocumentReference ref = _db.collection('users').doc(targetAgentPhone);
        batch.update(ref, {
          'subPlan': planName,
          'subExpiry': formattedExpiry,
          'subStatus': 'نشط',
        });
        logAction(action: 'تطبيق خطة مخصصة', details: 'تم تطبيق خطة [$planName] للوكيل $targetAgentPhone', severity: 'medium', targetPhone: targetAgentPhone);
      }

      await batch.commit();
    } catch (e) {
      throw 'حدث خطأ أثناء اعتماد الخطة: $e';
    }
  }

  // 2. توليد كوبون ذكي
  Future<void> createSmartCoupon({
    required String code,
    required String discountDetails,
    required int maxUses,
  }) async {
    try {
      // التحقق من عدم تكرار الكود
      final existing = await _db.collection('coupons').where('code', isEqualTo: code).get();
      if (existing.docs.isNotEmpty) throw 'كود الكوبون مستخدم مسبقاً!';

      await _db.collection('coupons').add({
        'code': code.toUpperCase(),
        'discountDetails': discountDetails,
        'maxUses': maxUses,
        'usedCount': 0,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
      logAction(action: 'إنشاء كوبون', details: 'تم إنشاء كوبون ترويجي [$code]', severity: 'medium');
    } catch (e) {
      throw 'فشل إنشاء الكوبون: $e';
    }
  }

  // 3. تحديث فترة السماح (الرادار) لوكيل
  Future<void> updateAgentGracePeriod(String agentPhone, String newExpiryDate) async {
    try {
      await _db.collection('users').doc(agentPhone).update({
        'subExpiry': newExpiryDate,
        'subStatus': 'إنذار', // تحويله لفترة سماح/إنذار
      });
      logAction(action: 'تعديل فترة السماح', details: 'تم تعديل تاريخ الانتهاء للرقم $agentPhone إلى $newExpiryDate', severity: 'medium', targetPhone: agentPhone);
    } catch (e) {
      throw 'فشل تحديث فترة السماح: $e';
    }
  }

  // 4. إيقاف / استئناف خطة الوكيل
  Future<void> toggleSubscriptionStatus(String agentPhone, String currentStatus) async {
    try {
      String newStatus = currentStatus == 'موقوف مؤقتاً' ? 'نشط' : 'موقوف مؤقتاً';
      await _db.collection('users').doc(agentPhone).update({'subStatus': newStatus});
      logAction(action: 'تغيير حالة الاشتراك', details: 'تغيرت خطة الوكيل $agentPhone إلى [$newStatus]', severity: 'critical', targetPhone: agentPhone);
    } catch (e) {
      throw 'فشل تغيير حالة الخطة: $e';
    }
  }
}
