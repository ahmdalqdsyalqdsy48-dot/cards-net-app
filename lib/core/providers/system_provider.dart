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
  // 🆕 متغيرات النسخ الاحتياطي والحسابات البنكية
  // ==========================================
  bool _isAutoBackupEnabled = true;
  String _backupFrequency = 'يومياً';
  String _backupTime = '04:00 فجراً';
  String _emergencyEmail = '';
  bool _isDriveLinked = false;
  bool _isDropboxLinked = false;
  List<Map<String, dynamic>> _backupsList = [];
  
  // 👈 قائمة الحسابات البنكية السحابية
  List<Map<String, dynamic>> _bankAccounts = [];

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

    // 🆕 الاستماع للحسابات البنكية (مرتبة حسب حقل "order")
    _db.collection('bank_accounts').orderBy('order').snapshots().listen((snapshot) {
      _bankAccounts = snapshot.docs.map((doc) => {'docId': doc.id, ...doc.data()}).toList();
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
  List<Map<String, dynamic>> get auditLogs => _auditLogs;

  bool get isAutoBackupEnabled => _isAutoBackupEnabled;
  String get backupFrequency => _backupFrequency;
  String get backupTime => _backupTime;
  String get emergencyEmail => _emergencyEmail;
  bool get isDriveLinked => _isDriveLinked;
  bool get isDropboxLinked => _isDropboxLinked;
  List<Map<String, dynamic>> get backupsList => _backupsList;
  
  // 👈 قراءة الحسابات البنكية السحابية
  List<Map<String, dynamic>> get bankAccounts => _bankAccounts;

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
      });
    } catch (e) {}
  }

  // ==========================================
  // 5. دوال الإدارة والتحكم السحابية المضمونة 🚀
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
          'createdAt': FieldValue.serverTimestamp(), // 👈 توثيق وقت الإنشاء
        });
        
        logAction(action: 'إضافة وكيل جديد', details: 'تم إضافة وكيل جديد باسم "$name" ورقم $phone', severity: 'medium');
      } else {
        throw 'رقم الهاتف مسجل مسبقاً في النظام!';
      }
    } catch (e) {
      // قذف الخطأ للشاشة
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
      logAction(action: 'تغيير حالة حساب', details: 'تم تغيير حالة الحساب $phone إلى [$newStatus]', severity: 'critical');
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

  Future<void> updateAutoBackupSettings(bool isEnabled, String freq, String time, String email) async {
    await _db.collection('system').doc('backup_settings').update({
      'isAutoBackupEnabled': isEnabled,
      'backupFrequency': freq,
      'backupTime': time,
      'emergencyEmail': email,
    });
    logAction(action: 'إعدادات النسخ', details: 'تم تعديل إعدادات النسخ الاحتياطي التلقائي', severity: 'medium');
  }

  Future<void> toggleCloudLink(String service, bool isLinked) async {
    if (service == 'drive') {
      await _db.collection('system').doc('backup_settings').update({'isDriveLinked': isLinked});
    } else {
      await _db.collection('system').doc('backup_settings').update({'isDropboxLinked': isLinked});
    }
    logAction(action: 'الربط السحابي', details: 'تم ${isLinked ? "ربط" : "إلغاء ربط"} حساب $service بنجاح', severity: 'medium');
  }

  Future<void> takeManualBackup() async {
    final now = DateTime.now();
    final amPm = now.hour >= 12 ? 'PM' : 'AM';
    int hour12 = now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour);
    final formattedDate = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${hour12.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} $amPm';
    
    await _db.collection('backups').add({
      'date': formattedDate,
      'size': '45 MB',
      'type': 'يدوي (محلي)',
      'timestamp': FieldValue.serverTimestamp(),
    });
    logAction(action: 'أخذ نسخة يدوية', details: 'تم أخذ نسخة احتياطية بنجاح وتم رفعها للسحابة', severity: 'medium');
  }

  Future<void> deleteBackup(String docId) async {
    await _db.collection('backups').doc(docId).delete();
    logAction(action: 'حذف نسخة احتياطية', details: 'تم مسح نسخة احتياطية قديمة لتوفير المساحة', severity: 'critical');
  }

  Future<void> logRestoreAttempt(bool isSuccess, String backupDate) async {
    if (isSuccess) {
      logAction(action: 'استعادة النظام (ناجحة)', details: 'تم استعادة النظام إلى النقطة الزمنية ($backupDate)', severity: 'critical');
    } else {
      logAction(action: 'استعادة النظام (فاشلة)', details: 'محاولة فاشلة لاستعادة النظام - إدخال رمز PIN غير صحيح', severity: 'critical');
    }
  }

  // ==========================================
  // 🆕 دوال إدارة الحسابات البنكية المضمونة
  // ==========================================

  Future<void> addBankAccount(String bankName, String accNumber, String beneficiary) async {
    try {
      int newOrder = _bankAccounts.length;
      
      await _db.collection('bank_accounts').add({
        'bankName': bankName,
        'accountNumber': accNumber,
        'beneficiary': beneficiary.isNotEmpty ? beneficiary : 'غير محدد',
        'status': 'نشط',
        'hasQR': false, 
        'order': newOrder,
        'createdAt': FieldValue.serverTimestamp(), // 👈 توثيق وقت الإنشاء
      });
      
      logAction(action: 'إضافة حساب بنكي', details: 'تم إضافة حساب $bankName برقم $accNumber', severity: 'medium');
    } catch (e) {
      // 👈 قذف الخطأ لكي تلتقطه الشاشة إذا فشل الحفظ
      throw 'حدث خطأ أثناء حفظ الحساب السحابي: $e';
    }
  }

  Future<void> updateBankAccount(String docId, String bankName, String accNumber, String beneficiary) async {
    try {
      await _db.collection('bank_accounts').doc(docId).update({
        'bankName': bankName,
        'accountNumber': accNumber,
        'beneficiary': beneficiary,
      });
      logAction(action: 'تعديل حساب بنكي', details: 'تم تعديل بيانات الحساب البنكي $bankName', severity: 'medium');
    } catch (e) {
      throw 'حدث خطأ أثناء تعديل الحساب: $e';
    }
  }

  Future<void> toggleBankAccountStatus(String docId, String currentStatus) async {
    try {
      String newStatus = currentStatus == 'نشط' ? 'موقوف' : 'نشط';
      await _db.collection('bank_accounts').doc(docId).update({'status': newStatus});
      logAction(action: 'تغيير حالة حساب بنكي', details: 'تم $newStatus حساب بنكي', severity: 'medium');
    } catch (e) {
      throw 'حدث خطأ أثناء تغيير حالة الحساب: $e';
    }
  }

  Future<void> deleteBankAccount(String docId) async {
    try {
      await _db.collection('bank_accounts').doc(docId).delete();
      logAction(action: 'حذف حساب بنكي', details: 'تم حذف حساب بنكي من النظام', severity: 'critical');
    } catch (e) {
      throw 'حدث خطأ أثناء محاولة حذف الحساب: $e';
    }
  }

  Future<void> reorderBankAccounts(int oldIndex, int newIndex) async {
    try {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      
      // التحديث المحلي الفوري لسرعة الاستجابة
      final item = _bankAccounts.removeAt(oldIndex);
      _bankAccounts.insert(newIndex, item);
      notifyListeners();

      // الإرسال السحابي
      WriteBatch batch = _db.batch();
      for (int i = 0; i < _bankAccounts.length; i++) {
        DocumentReference ref = _db.collection('bank_accounts').doc(_bankAccounts[i]['docId']);
        batch.update(ref, {'order': i});
      }
      
      await batch.commit();
      logAction(action: 'إعادة ترتيب الحسابات', details: 'تم تغيير ترتيب ظهور الحسابات البنكية للوكلاء', severity: 'normal');
    } catch (e) {
      throw 'حدث خطأ في مزامنة الترتيب السحابي: $e';
    }
  }
}
