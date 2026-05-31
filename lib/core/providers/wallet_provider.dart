import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../constants.dart';
import '../services/api_service.dart';
import 'auth_provider.dart';
import 'settings_provider.dart';
import 'transactions_provider.dart';

class WalletProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final AuthProvider? _auth;
  final SettingsProvider? _settings;
  final TransactionsProvider? _transactions;

  WalletProvider(this._auth, {
    SettingsProvider? settings,
    TransactionsProvider? transactions,
  })  : _settings = settings,
        _transactions = transactions {
    _auth?.addListener(_onAuthChanged);
    if (_auth?.activeUserPhone != null) {
      _startListeners();
    }
  }

  @override
  void dispose() {
    _cancelListeners();
    _auth?.removeListener(_onAuthChanged);
    super.dispose();
  }

  // ---------- بيانات مخزنة محلياً ----------
  List<Map<String, dynamic>> _usersDatabase = [];
  List<Map<String, dynamic>> _rechargeRequests = [];
  List<Map<String, dynamic>> _myAgentBankAccounts = [];
  List<Map<String, dynamic>> _bankAccounts = [];

  StreamSubscription? _usersSub;
  StreamSubscription? _rechargeSub;
  StreamSubscription? _bankAccountsSub;
  StreamSubscription? _agentBankSub;

  void _onAuthChanged() {
    if (_auth?.activeUserPhone != null) {
      _startListeners();
    } else {
      _cancelListeners();
      _myAgentBankAccounts = [];
      notifyListeners();
    }
  }

  void _startListeners() {
    _cancelListeners();

    _usersSub = _db.collection('users').snapshots().listen((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        _usersDatabase = snapshot.docs.map((doc) => doc.data()).toList();
        _runAutoRadar(_usersDatabase);
        notifyListeners();
      }
    });

    _rechargeSub = _db
        .collection('recharge_requests')
        .where('status', isEqualTo: 'قيد الانتظار')
        .snapshots()
        .listen((snapshot) {
      _rechargeRequests = snapshot.docs
          .map((doc) => {'docId': doc.id, ...doc.data()})
          .toList();
      notifyListeners();
    });

    _bankAccountsSub = _db
        .collection('bank_accounts')
        .orderBy('order')
        .snapshots()
        .listen((snapshot) {
      _bankAccounts = snapshot.docs
          .map((doc) => {'docId': doc.id, ...doc.data()})
          .toList();
      notifyListeners();
    });

    if (_auth?.currentUserRole == 'agent' ||
        _auth?.currentUserRole == 'super_admin') {
      _agentBankSub = _db
          .collection('agent_bank_accounts')
          .where('agentPhone', isEqualTo: _auth!.activeUserPhone)
          .orderBy('order')
          .snapshots()
          .listen((snapshot) {
        _myAgentBankAccounts = snapshot.docs
            .map((doc) => {'docId': doc.id, ...doc.data()})
            .toList();
        notifyListeners();
      });
    }
  }

  void _cancelListeners() {
    _usersSub?.cancel();
    _rechargeSub?.cancel();
    _bankAccountsSub?.cancel();
    _agentBankSub?.cancel();
    _usersSub = null;
    _rechargeSub = null;
    _bankAccountsSub = null;
    _agentBankSub = null;
  }

  void _runAutoRadar(List<Map<String, dynamic>> users) {
    final now = DateTime.now();
    WriteBatch batch = _db.batch();
    bool needsUpdate = false;

    for (var user in users) {
      if (user['role'] == 'agent' &&
          user['subExpiry'] != null &&
          user['subStatus'] == 'نشط') {
        try {
          DateTime expiryDate = DateTime.parse(user['subExpiry']);
          if (now.isAfter(expiryDate)) {
            DocumentReference ref = _db.collection('users').doc(user['phone']);
            batch.update(ref, {'subStatus': 'إنذار'});
            needsUpdate = true;
          }
        } catch (e) {}
      }
    }
    if (needsUpdate) batch.commit();
  }

  // ---------- Getters الأساسية ----------
  List<Map<String, dynamic>> get usersDatabase => _usersDatabase;
  List<Map<String, dynamic>> get agentsList =>
      _usersDatabase.where((user) => user['role'] == 'agent').toList();
  List<Map<String, dynamic>> get usersList =>
      _usersDatabase
          .where((user) => user['role'] == 'user' || user['role'] == 'pos')
          .toList();
  List<Map<String, dynamic>> get pendingRechargeRequests => _rechargeRequests;
  List<Map<String, dynamic>> get bankAccounts => _bankAccounts;
  List<Map<String, dynamic>> get myAgentBankAccounts => _myAgentBankAccounts;

  // ---------- وسائط إلى TransactionsProvider ----------
  List<Map<String, dynamic>> get transactionsLedger =>
      _transactions?.transactionsLedger ?? [];
  List<Map<String, dynamic>> get salesList =>
      _transactions?.salesList ?? [];
  List<Map<String, dynamic>> get supportTickets =>
      _transactions?.supportTickets ?? [];

  DateTimeRange? get dashboardDateRange =>
      _transactions?.dashboardDateRange;
  void setDashboardDateRange(DateTimeRange? range) {
    _transactions?.setDashboardDateRange(range);
    notifyListeners();
  }

  double get filteredSales =>
      _transactions?.filteredSales ?? 0.0;
  double get filteredProfit =>
      _transactions?.filteredProfit ?? 0.0;
  int get openTicketsCount =>
      _transactions?.openTicketsCount ?? 0;
  int get criticalTicketsCount =>
      _transactions?.criticalTicketsCount ?? 0;

  // ---------- وسائط إلى AuthProvider (الملف الشخصي) ----------
  String? get activeUserPhone => _auth?.activeUserPhone;
  String get currentUserPhone => _auth?.activeUserPhone ?? '';
  String get currentUserRole => _auth?.currentUserRole ?? 'guest';
  bool hasPermission(String permissionName) =>
      _auth?.hasPermission(permissionName) ?? false;

  Future<bool> changeUserName(String newName) async =>
      await _auth?.changeUserName(newName) ?? false;
  Future<bool> changeUserPin(String oldPin, String newPin) async =>
      await _auth?.changeUserPin(oldPin, newPin) ?? false;
  Future<String> changeUserPinWithOld(String oldPin, String newPin, String confirmPin) async {
    if (_auth == null) return 'خطأ في المصادقة';
    return await _auth!.changeUserPinWithOld(oldPin, newPin, confirmPin);
  }
  bool changeUserPassword(String oldPassword, String newPassword) =>
      _auth?.changeUserPassword(oldPassword, newPassword) ?? false;
  void toggleBiometric(bool isEnabled) =>
      _auth?.toggleBiometric(isEnabled);
  Future<void> updatePrivacySettings({required bool showPhone}) async =>
      await _auth?.updatePrivacySettings(showPhone: showPhone);
  Future<void> updatePrivacySetting(String key, bool value) async =>
      await _auth?.updatePrivacySetting(key, value);
  Future<void> updateUserDailyLimit(double limit) async =>
      await _auth?.updateUserDailyLimit(limit);
  Future<void> updateUserMonthlyLimit(double limit) async =>
      await _auth?.updateUserMonthlyLimit(limit);
  Future<bool> deleteUserAccount(String password) async =>
      await _auth?.deleteUserAccount(password) ?? false;
  Future<void> saveUserPreferredColor(Color color) async =>
      await _auth?.saveUserPreferredColor(color);
  Future<Color?> getUserPreferredColor() async =>
      await _auth?.getUserPreferredColor();
  Future<void> updateLastSeen() async =>
      await _auth?.updateLastSeen();
  Future<void> togglePinEnabled(bool value) async =>
      await _auth?.togglePinEnabled(value);

  // ---------- Getters من الجلسة والملف الشخصي ----------
  String get currentUserName {
    if (_auth?.activeUserPhone == null) return '';
    final user = _usersDatabase.firstWhere(
        (u) => u['phone'] == _auth!.activeUserPhone,
        orElse: () => {'name': ''});
    return user['name'] ?? '';
  }

  String get currentUserPin => _auth?.currentUserPin ?? '';
  String get currentUserNetwork {
    if (_auth?.activeUserPhone == null) return 'غير محدد';
    final user = _usersDatabase.firstWhere(
        (u) => u['phone'] == _auth!.activeUserPhone,
        orElse: () => {'networkName': 'غير محدد'});
    return user['networkName'] ?? 'غير محدد';
  }

  List<String> get currentUserNetworkIds {
    if (_auth?.activeUserPhone == null) return [];
    final user = _usersDatabase.firstWhere(
        (u) => u['phone'] == _auth!.activeUserPhone,
        orElse: () => {'networkIds': <String>[]});
    return List<String>.from(user['networkIds'] ?? []);
  }

  String? get currentUserAccountNumber {
    if (_auth?.activeUserPhone == null) return null;
    final user = _usersDatabase.firstWhere(
        (u) => u['phone'] == _auth!.activeUserPhone,
        orElse: () => {});
    return user['accountNumber']?.toString();
  }

  bool get currentUserPrivacyShowPhone {
    if (_auth?.activeUserPhone == null) return true;
    final user = _usersDatabase.firstWhere(
        (u) => u['phone'] == _auth!.activeUserPhone,
        orElse: () => {'privacy_showPhone': true});
    return user['privacy_showPhone'] ?? true;
  }

  bool get isBiometricCurrentlyEnabled {
    if (_auth?.activeUserPhone == null) return false;
    final user = _usersDatabase.firstWhere(
        (u) => u['phone'] == _auth!.activeUserPhone,
        orElse: () => {'isBiometricEnabled': false});
    return user['isBiometricEnabled'] ?? false;
  }

  bool get isPinEnabled {
    if (_auth?.activeUserPhone == null) return false;
    final user = _usersDatabase.firstWhere(
      (u) => u['phone'] == _auth!.activeUserPhone,
      orElse: () => {'pinEnabled': false},
    );
    return user['pinEnabled'] == true;
  }

  double get currentUserBalance {
    if (_auth?.activeUserPhone == null) return 0.0;
    final user = _usersDatabase.firstWhere(
        (u) => u['phone'] == _auth!.activeUserPhone,
        orElse: () => {'balance': 0.0});
    if (user['role'] == 'user' || user['role'] == 'pos') {
      Map<String, dynamic> wallets = user['wallets'] ?? {};
      return wallets.values.fold(0.0, (sum, val) => sum + (val as num).toDouble());
    }
    return (user['balance'] ?? 0.0).toDouble();
  }

  double get availableBalance => currentUserBalance - heldBalance;

  double get heldBalance {
    if (_auth?.activeUserPhone == null) return 0.0;
    final user = _usersDatabase.firstWhere(
      (u) => u['phone'] == _auth!.activeUserPhone,
      orElse: () => {'heldBalance': 0.0},
    );
    return (user['heldBalance'] ?? 0.0).toDouble();
  }

  double getWalletBalance(String agentPhone) {
    if (_auth?.activeUserPhone == null) return 0.0;
    final user = _usersDatabase.firstWhere(
        (u) => u['phone'] == _auth!.activeUserPhone,
        orElse: () => {'wallets': {}});
    Map<String, dynamic> wallets = user['wallets'] ?? {};
    return (wallets[agentPhone] ?? 0.0).toDouble();
  }

  List<Map<String, dynamic>> get userPurchasedCards {
    if (_auth?.activeUserPhone == null) return [];
    final user = _usersDatabase.firstWhere(
        (u) => u['phone'] == _auth!.activeUserPhone,
        orElse: () => {'purchasedCards': []});
    var rawList = user['purchasedCards'] ?? [];
    List<Map<String, dynamic>> structuredList = [];
    for (var item in rawList) {
      if (item is Map) {
        structuredList.add(Map<String, dynamic>.from(item));
      } else if (item is String) {
        structuredList.add({
          'title': item,
          'pin': 'بيانات قديمة',
          'price': 0.0,
          'date': ''
        });
      }
    }
    return structuredList;
  }

  String? get currentUserEmail {
    if (_auth?.activeUserPhone == null) return null;
    final user = _usersDatabase.firstWhere(
        (u) => u['phone'] == _auth!.activeUserPhone,
        orElse: () => {});
    return user['email'];
  }

  List<String> get currentUserHiddenSections {
    if (_auth?.activeUserPhone == null) return [];
    final user = _usersDatabase.firstWhere(
        (u) => u['phone'] == _auth!.activeUserPhone,
        orElse: () => {'role': 'user', 'hiddenSections': <String>[]});
    List<String> personalHidden = List<String>.from(user['hiddenSections'] ?? []);
    List<String> universalHidden = user['role'] == 'agent'
        ? (_settings?.agentUniversalHiddenSections ?? [])
        : (_settings?.userUniversalHiddenSections ?? []);
    return {...personalHidden, ...universalHidden}.toList();
  }

  // ---------- البريد الإلكتروني ----------
  Future<void> updateUserEmail(String email) async {
    if (_auth?.activeUserPhone == null) return;
    await _db.collection('users').doc(_auth!.activeUserPhone).update({'email': email});
    final index = _usersDatabase.indexWhere((u) => u['phone'] == _auth!.activeUserPhone);
    if (index != -1) {
      _usersDatabase[index]['email'] = email;
      notifyListeners();
    }
  }

  Future<String?> loadUserEmail() async {
    if (_auth?.activeUserPhone == null) return null;
    final doc = await _db.collection('users').doc(_auth!.activeUserPhone).get();
    if (doc.exists && doc.data() != null) {
      final email = doc.data()!['email'];
      final index = _usersDatabase.indexWhere((u) => u['phone'] == _auth!.activeUserPhone);
      if (index != -1) {
        _usersDatabase[index]['email'] = email;
        notifyListeners();
      }
      return email;
    }
    return null;
  }

  // ---------- أرقام الحسابات ----------
  bool _isSpecialAccountNumber(String numberStr) {
    final num = int.tryParse(numberStr);
    if (num == null || num < 10000) return true;
    if (numberStr.length >= 5 && numberStr.split('').toSet().length == 1) return true;
    final ascending = '0123456789';
    if (ascending.contains(numberStr)) return true;
    final descending = '9876543210';
    if (descending.contains(numberStr)) return true;
    return false;
  }

  Future<String> generateNextAccountNumber() async {
    final usersSnapshot = await _db
        .collection('users')
        .where('accountNumber', isNotEqualTo: null)
        .get();

    List<int> existingNumbers = [];
    for (var doc in usersSnapshot.docs) {
      final data = doc.data();
      final acc = data['accountNumber'];
      if (acc != null) {
        final num = int.tryParse(acc.toString());
        if (num != null) existingNumbers.add(num);
      }
    }

    int candidate = 10000;
    if (existingNumbers.isNotEmpty) {
      candidate = existingNumbers.reduce((a, b) => a > b ? a : b) + 1;
      if (candidate > 19999 && candidate < 100000) {
        candidate = 100000;
      } else if (candidate > 199999 && candidate < 1000000) {
        candidate = 1000000;
      } else if (candidate > 1999999 && candidate < 10000000) {
        candidate = 10000000;
      }
    }

    while (_isSpecialAccountNumber(candidate.toString())) {
      candidate++;
      if (candidate > 19999 && candidate < 100000) {
        candidate = 100000;
      } else if (candidate > 199999 && candidate < 1000000) {
        candidate = 1000000;
      } else if (candidate > 1999999 && candidate < 10000000) {
        candidate = 10000000;
      }
    }

    return candidate.toString();
  }

  Future<void> ensureUserAccountNumber() async {
    if (_auth?.activeUserPhone == null) return;
    try {
      final doc = await _db.collection('users').doc(_auth!.activeUserPhone).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['accountNumber'] == null) {
          final newAcc = await generateNextAccountNumber();
          await _db.collection('users').doc(_auth!.activeUserPhone).update({
            'accountNumber': newAcc,
          });
        }
      }
    } catch (e) {
      debugPrint('خطأ في ضمان رقم الحساب: $e');
    }
  }

  // ---------- البحث عن المستخدمين ----------
  Future<Map<String, dynamic>?> searchUserByAccountOrName(String query) async {
    if (query.trim().isEmpty) return null;
    final isNumeric = RegExp(r'^\d+$').hasMatch(query.trim());

    try {
      if (isNumeric) {
        final snap = await _db
            .collection('users')
            .where('accountNumber', isEqualTo: query.trim())
            .limit(1)
            .get();
        if (snap.docs.isNotEmpty) {
          final data = snap.docs.first.data() as Map<String, dynamic>;
          if (data['isBanned'] == true) return null;
          return _buildSearchResult(data, snap.docs.first.id);
        }
      } else {
        for (var user in _usersDatabase) {
          final name = user['name']?.toString() ?? '';
          if (name.contains(query.trim())) {
            if (user['isBanned'] == true) continue;
            return _buildSearchResult(user, user['phone'] ?? '');
          }
        }
        final snap = await _db
            .collection('users')
            .where('name', isGreaterThanOrEqualTo: query.trim())
            .where('name', isLessThan: '${query.trim()}z')
            .limit(1)
            .get();
        if (snap.docs.isNotEmpty) {
          final data = snap.docs.first.data() as Map<String, dynamic>;
          return _buildSearchResult(data, snap.docs.first.id);
        }
      }
      return null;
    } catch (e) {
      throw 'خطأ في البحث: $e';
    }
  }

  Map<String, dynamic> _buildSearchResult(Map<String, dynamic> data, String phone) {
    final bool showPhone = data['privacy_showPhone'] ?? true;
    final bool hideBalance = data['privacy_hideBalance'] ?? false;
    final bool showFullName = data['privacy_showFullName'] ?? true;
    return {
      'accountNumber': data['accountNumber'] ?? 'غير متوفر',
      'name': showFullName ? (data['name'] ?? 'مجهول') : 'مخفي',
      'role': data['role'] ?? 'user',
      'phone': showPhone ? phone : 'مخفي',
      'balance': hideBalance ? 0.0 : _getUserBalance(data, phone),
    };
  }

  double _getUserBalance(Map<String, dynamic> data, String phone) {
    if (data['role'] == 'user' || data['role'] == 'pos') {
      Map<String, dynamic> wallets = data['wallets'] ?? {};
      return wallets.values.fold(0.0, (sum, val) => sum + (val as num).toDouble());
    }
    return (data['balance'] ?? 0.0).toDouble();
  }

  Future<Map<String, dynamic>?> searchUserForTransfer(String targetPhone) async {
    if (_auth?.activeUserPhone == null) throw 'يرجى تسجيل الدخول.';
    if (targetPhone == _auth!.activeUserPhone) throw 'لا يمكنك تحويل الرصيد لنفسك!';

    try {
      final doc = await _db.collection('users').doc(targetPhone).get();
      if (!doc.exists) return null;

      final data = doc.data() as Map<String, dynamic>;

      var lastTxn = await _db
          .collection('transactions')
          .where('toPhone', isEqualTo: targetPhone)
          .where('fromPhone', isEqualTo: _auth!.activeUserPhone)
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      String lastRecharge = 'لا يوجد سجل سابق';
      if (lastTxn.docs.isNotEmpty) {
        var tData = lastTxn.docs.first.data() as Map<String, dynamic>;
        if (tData['timestamp'] != null) {
          lastRecharge = DateFormat('yyyy-MM-dd hh:mm a')
              .format((tData['timestamp'] as Timestamp).toDate());
        }
      }

      double displayBalance = 0.0;
      if (data['role'] == 'user' || data['role'] == 'pos') {
        Map<String, dynamic> wallets = data['wallets'] ?? {};
        displayBalance = (wallets[_auth!.activeUserPhone] ?? 0.0).toDouble();
      } else {
        displayBalance = (data['balance'] ?? 0.0).toDouble();
      }

      return {
        'name': data['name'] ?? 'مجهول',
        'role': data['role'] ?? 'user',
        'networkName': data['networkName'] ?? 'غير محدد',
        'balance': displayBalance,
        'lastRecharge': lastRecharge,
      };
    } catch (e) {
      throw 'حدث خطأ أثناء البحث عن الرقم.';
    }
  }

  // ---------- دوال المحافظ والتحويلات ----------
  Future<void> transferToUser({
    required String targetPhone,
    required double amount,
  }) async {
    if (availableBalance < amount) throw 'الرصيد المتاح غير كافٍ.';
    final api = ApiService(authToken: _auth?.authToken);
    await api.post('/api/transfer', {
      'targetPhone': targetPhone,
      'amount': amount,
    }, authenticate: true);
  }

  Future<void> secureTransferBalance({
    required String targetPhone,
    required String targetName,
    required double amount,
    required String password,
  }) async {
    await advancedSecureTransferBalance(
        targetPhone: targetPhone,
        targetName: targetName,
        amount: amount,
        taxPercentage: 0.0,
        note: '',
        paymentMethod: 'نقد',
        password: password);
  }

  Future<void> advancedSecureTransferBalance({
    required String targetPhone,
    required String targetName,
    required double amount,
    required double taxPercentage,
    required String note,
    required String paymentMethod,
    required String password,
  }) async {
    if (_auth?.activeUserPhone == null) throw 'يرجى تسجيل الدخول.';

    final myData = _usersDatabase.firstWhere(
        (u) => u['phone'] == _auth!.activeUserPhone,
        orElse: () => {});
    if (myData['password'] != password) {
      throw 'كلمة المرور غير صحيحة ❌';
    }

    final api = ApiService(authToken: _auth?.authToken);
    await api.post('/api/transfer', {
      'targetPhone': targetPhone,
      'amount': amount,
    }, authenticate: true);
  }

  Future<void> submitSaaSRechargeRequest({
    required double quotaAmount,
    required double feeAmount,
    required String adminBankName,
    required String transferSource,
    required String reference,
    required String base64Image,
  }) async {
    final api = ApiService(authToken: _auth?.authToken);
    await api.post('/api/recharge-request', {
      'amount': quotaAmount,
      'bankName': adminBankName,
      'transferSource': transferSource,
      'reference': reference,
      'receiptBase64': base64Image,
    }, authenticate: true);
  }

  Future<void> requestRechargeFromAgent({
    required String agentPhone,
    required double amount,
    required String paymentMethod,
    required String reference,
    String? base64Image,
    String? fullName,
  }) async {
    if (_auth?.activeUserPhone == null) throw 'يرجى تسجيل الدخول.';
    final docData = <String, dynamic>{
      'userPhone': _auth!.activeUserPhone,
      'userName': currentUserName,
      'targetPhone': agentPhone,
      'amount': amount,
      'paymentMethod': paymentMethod,
      'reference': reference,
      'receiptBase64': base64Image ?? '',
      'status': 'قيد الانتظار',
      'type': 'user_to_agent',
      'timestamp': FieldValue.serverTimestamp(),
    };
    if (fullName != null && fullName.isNotEmpty) {
      docData['fullName'] = fullName;
    }
    await _db.collection('user_recharges').add(docData);
    sendNotification(
        targetPhones: [agentPhone],
        title: 'طلب شحن جديد 💰',
        body: '${currentUserName} يطلب شحن مبلغ $amount ريال.');
  }

  Future<void> agentAcceptUserRecharge(
      String requestId, String requesterPhone, double amount) async {
    if (_auth?.activeUserPhone == null) return;

    final myDoc = await _db
        .collection('users')
        .doc(_auth!.activeUserPhone)
        .get();
    final myData = myDoc.data() ?? {};
    if ((myData['balance'] ?? 0.0) < amount) {
      throw 'رصيدك لا يكفي! قم بتغذية رصيدك أولاً.';
    }

    final requesterDoc =
        await _db.collection('users').doc(requesterPhone).get();
    final requesterData = requesterDoc.data() ?? {};

    WriteBatch batch = _db.batch();

    batch.update(
        _db.collection('user_recharges').doc(requestId), {'status': 'مقبول'});
    batch.update(myDoc.reference, {'balance': FieldValue.increment(-amount)});

    batch.update(requesterDoc.reference,
        {'wallets.${_auth!.activeUserPhone}': FieldValue.increment(amount)});

    batch.set(_db.collection('transactions').doc(), {
      'fromPhone': _auth!.activeUserPhone,
      'toPhone': requesterPhone,
      'agentPhone': _auth!.activeUserPhone,
      'agentName': currentUserName,
      'targetName': requesterData['name'] ?? 'مستخدم',
      'networkName': requesterData['networkName'] ?? 'غير محدد',
      'amount': amount,
      'type': 'transfer',
      'paymentMethod': 'آجل (من حصة الوكيل)',
      'title': 'موافقة على طلب شحن من ${requesterData['name'] ?? 'مستخدم'}',
      'reference': 'RCH-$requestId',
      'timestamp': FieldValue.serverTimestamp()
    });

    DocumentReference notifRef = _db.collection('notifications').doc();
    batch.set(notifRef, {
      'targetPhones': [requesterPhone],
      'title': 'تم شحن محفظتك 🎉',
      'body':
          'تمت الموافقة وإضافة $amount ريال لمحفظتك من $currentUserName.',
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
      'readBy': [],
    });

    await batch.commit();
  }

  // ---------- شراء كرت (فردي وجماعي) ----------
  Future<String> executeRealPurchase(
    double price, String cardTitle, String agentPhone, String categoryId) async {
    if (_auth?.activeUserPhone == null) throw 'يرجى تسجيل الدخول أولاً.';
    if (availableBalance < price) throw 'الرصيد المتاح غير كافٍ.';
    final api = ApiService(authToken: _auth?.authToken);
    final result = await api.post('/api/purchase', {
      'agentPhone': agentPhone,
      'categoryId': categoryId,
      'cardTitle': cardTitle,
      'price': price,
    }, authenticate: true);
    return result['pin'] as String;
  }

  Future<List<String>> executeBulkPurchase({
    required double totalPrice,
    required double unitPrice,
    required int quantity,
    required double discountAmount,
    required double couponDiscount,
    required String cardTitle,
    required String agentPhone,
    required String categoryId,
    String? appliedCouponId,
  }) async {
    if (_auth?.activeUserPhone == null) throw 'يرجى تسجيل الدخول أولاً لإتمام الشراء.';
    if (availableBalance < totalPrice) throw 'الرصيد المتاح غير كافٍ.';

    final userRef = _db.collection('users').doc(_auth!.activeUserPhone);

    final availableCardsQuery = await _db
        .collection('cards')
        .where('agentPhone', isEqualTo: agentPhone)
        .where('categoryId', isEqualTo: categoryId)
        .where('status', isEqualTo: 'متاح')
        .limit(quantity)
        .get();

    if (availableCardsQuery.docs.length < quantity) {
      throw 'عذراً، لا توجد كروت كافية. المتاح: ${availableCardsQuery.docs.length}';
    }

    final List<String> pins = [];
    final List<DocumentReference> cardRefs = [];

    for (var doc in availableCardsQuery.docs) {
      final cardData = doc.data() as Map<String, dynamic>;
      pins.add(cardData['pin'] ?? 'غير معروف');
      cardRefs.add(doc.reference);
    }

    await _db.runTransaction((transaction) async {
      final userSnapshot = await transaction.get(userRef);
      if (!userSnapshot.exists) throw 'حساب المستخدم غير موجود.';

      final userData = userSnapshot.data() as Map<String, dynamic>;
      Map<String, dynamic> wallets = userData['wallets'] ?? {};
      double currentWalletBalance = (wallets[agentPhone] ?? 0.0).toDouble();

      double creditLimit = 0.0;
      if (userData['role'] == 'pos') {
        Map<String, dynamic> relations = userData['agent_relations'] ?? {};
        Map<String, dynamic> myRel = relations[agentPhone] ?? {};
        creditLimit = (myRel['creditLimit'] ?? 0.0).toDouble();
      }

      if ((currentWalletBalance + creditLimit) < totalPrice) {
        throw 'الرصيد أو الحد الائتماني غير كافٍ.';
      }

      transaction.update(userRef, {
        'wallets.$agentPhone': FieldValue.increment(-totalPrice),
      });

      for (var ref in cardRefs) {
        transaction.update(ref, {
          'status': 'مباع',
          'buyerPhone': _auth!.activeUserPhone,
          'soldAt': FieldValue.serverTimestamp(),
          'soldPrice': unitPrice,
          'discountAmount': discountAmount + couponDiscount,
        });
      }

      for (var pin in pins) {
        final purchaseInvoice = {
          'title': cardTitle,
          'pin': pin,
          'price': unitPrice,
          'agentPhone': agentPhone,
          'date': DateTime.now().toIso8601String(),
        };
        transaction.update(userRef, {
          'purchasedCards': FieldValue.arrayUnion([purchaseInvoice])
        });
      }

      transaction.update(_db.collection('system').doc('main_info'), {
        'totalSystemCards': FieldValue.increment(-quantity)
      });

      DocumentReference txnRef = _db.collection('transactions').doc();
      transaction.set(txnRef, {
        'fromPhone': _auth!.activeUserPhone,
        'toPhone': agentPhone,
        'agentPhone': agentPhone,
        'agentName': currentUserName,
        'targetName': userData['name'] ?? 'زبون',
        'networkName': userData['networkName'] ?? 'غير محدد',
        'amount': totalPrice,
        'fee': 0.0,
        'paymentMethod': 'خصم من المحفظة',
        'type': 'sale',
        'title': 'بيع $quantity كرت: $cardTitle',
        'reference': 'BULK-${DateTime.now().millisecondsSinceEpoch}',
        'discount': discountAmount + couponDiscount,
        'timestamp': FieldValue.serverTimestamp()
      });

      if (appliedCouponId != null) {
        transaction.update(_db.collection('coupons').doc(appliedCouponId), {
          'currentUsage': FieldValue.increment(1),
        });
      }
    });

    return pins;
  }

  // ---------- الحسابات البنكية للوكيل ----------
  Future<void> addAgentBankAccount(String networkName, String agentName,
      String bankName, String accNumber, String note, [List<String>? networkIds]) async {
    if (_auth?.activeUserPhone == null) return;
    try {
      int newOrder = _myAgentBankAccounts.length;
      final docRef = await _db.collection('agent_bank_accounts').add({
        'agentPhone': _auth!.activeUserPhone,
        'networkName': networkName,
        'agentName': agentName,
        'bankName': bankName,
        'accountNumber': accNumber,
        'note': note.isNotEmpty ? note : 'لا توجد ملاحظات',
        'status': 'نشط',
        'order': newOrder,
        'createdAt': FieldValue.serverTimestamp(),
        'networkIds': networkIds ?? [],
      });

      _myAgentBankAccounts.add({
        'docId': docRef.id,
        'agentPhone': _auth!.activeUserPhone,
        'networkName': networkName,
        'agentName': agentName,
        'bankName': bankName,
        'accountNumber': accNumber,
        'note': note.isNotEmpty ? note : 'لا توجد ملاحظات',
        'status': 'نشط',
        'order': newOrder,
        'createdAt': Timestamp.now(),
        'networkIds': networkIds ?? [],
      });
      notifyListeners();
    } catch (e) {
      throw 'خطأ في إضافة الحساب: $e';
    }
  }

  Future<void> updateAgentBankAccount(String docId, String networkName,
      String agentName, String bankName, String accNumber, String note, [List<String>? networkIds]) async {
    final updateData = <String, dynamic>{
      'networkName': networkName,
      'agentName': agentName,
      'bankName': bankName,
      'accountNumber': accNumber,
      'note': note,
    };
    if (networkIds != null) {
      updateData['networkIds'] = networkIds;
    }
    await _db.collection('agent_bank_accounts').doc(docId).update(updateData);

    final index = _myAgentBankAccounts.indexWhere((a) => a['docId'] == docId);
    if (index != -1) {
      _myAgentBankAccounts[index].addAll(updateData);
      notifyListeners();
    }
  }

  Future<void> toggleAgentBankAccountStatus(
      String docId, String currentStatus) async {
    String newStatus = currentStatus == 'نشط' ? 'موقوف' : 'نشط';
    await _db
        .collection('agent_bank_accounts')
        .doc(docId)
        .update({'status': newStatus});

    final index = _myAgentBankAccounts.indexWhere((a) => a['docId'] == docId);
    if (index != -1) {
      _myAgentBankAccounts[index]['status'] = newStatus;
      notifyListeners();
    }
  }

  Future<void> deleteAgentBankAccount(String docId) async {
    await _db.collection('agent_bank_accounts').doc(docId).delete();
    _myAgentBankAccounts.removeWhere((a) => a['docId'] == docId);
    notifyListeners();
  }

  Future<void> reorderAgentBankAccounts(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) newIndex -= 1;
    final item = _myAgentBankAccounts.removeAt(oldIndex);
    _myAgentBankAccounts.insert(newIndex, item);
    notifyListeners();
    WriteBatch batch = _db.batch();
    for (int i = 0; i < _myAgentBankAccounts.length; i++) {
      batch.update(
          _db.collection('agent_bank_accounts').doc(_myAgentBankAccounts[i]['docId']),
          {'order': i});
    }
    await batch.commit();
  }

  // ---------- نقاط البيع (تمويل فقط) ----------
  Future<void> fundSubAgent(String posPhone, double amount) async {
    if (_auth?.activeUserPhone == null) return;

    final agentDoc = await _db.collection('users').doc(_auth!.activeUserPhone).get();
    final agentData = agentDoc.data() ?? {};
    if ((agentData['balance'] ?? 0.0) < amount) {
      throw 'رصيد الحصة غير كافٍ لإتمام التحويل.';
    }

    final posDoc = await _db.collection('users').doc(posPhone).get();
    final posData = posDoc.data() ?? {};

    WriteBatch batch = _db.batch();

    batch.update(agentDoc.reference, {'balance': FieldValue.increment(-amount)});
    batch.update(_db.collection('users').doc(posPhone),
        {'wallets.${_auth!.activeUserPhone}': FieldValue.increment(amount)});

    batch.set(_db.collection('transactions').doc(), {
      'fromPhone': _auth!.activeUserPhone,
      'toPhone': posPhone,
      'agentPhone': _auth!.activeUserPhone,
      'agentName': currentUserName,
      'targetName': posData['name'] ?? 'نقطة بيع',
      'networkName': posData['networkName'] ?? 'غير محدد',
      'amount': amount,
      'fee': 0.0,
      'type': 'transfer',
      'paymentMethod': 'آجل (من حصة الوكيل)',
      'title': 'تغذية محفظة نقطة البيع: ${posData['name'] ?? ''}',
      'reference': 'FND-${DateTime.now().millisecondsSinceEpoch}',
      'timestamp': FieldValue.serverTimestamp()
    });

    batch.set(_db.collection('notifications').doc(), {
      'targetPhones': [posPhone],
      'title': 'تغذية رصيد 💰',
      'body': 'تم تحويل $amount ريال لمحفظتك من الوكيل $currentUserName.',
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
      'readBy': [],
    });

    await batch.commit();
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

      final agentDoc = await _db.collection('users').doc(agentPhone).get();
      final agentData = agentDoc.data() ?? {};

      DocumentReference transactionRef = _db.collection('transactions').doc();
      batch.set(transactionRef, {
        'fromPhone': '774578241',
        'toPhone': agentPhone,
        'agentPhone': agentPhone,
        'agentName': agentName,
        'targetName': 'المركز الرئيسي',
        'networkName': agentData['networkName'] ?? 'غير محدد',
        'type': amount > 0 ? 'deposit' : 'expense',
        'title': amount > 0
            ? 'تسوية يدوية للحصة (إضافة)'
            : 'تسوية يدوية للحصة (خصم)',
        'amount': amount.abs(),
        'fee': 0.0,
        'paymentMethod': 'تسوية إدارية',
        'reason': reason,
        'reference': 'SET-${DateTime.now().millisecondsSinceEpoch}',
        'timestamp': FieldValue.serverTimestamp()
      });

      DocumentReference notifRef = _db.collection('notifications').doc();
      batch.set(notifRef, {
        'targetPhones': [agentPhone],
        'title': 'تسوية يدوية لحصتك ⚙️',
        'body':
            'تم ${amount > 0 ? "إضافة" : "خصم"} مبلغ ${amount.abs()} ريال.\nالسبب: $reason',
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'readBy': [],
      });

      await batch.commit();
    } catch (e) {
      throw 'فشل التسوية اليدوية: $e';
    }
  }

  // ---------- طلبات الشحن والإيداع ----------
  Future<String> uploadReceiptImage(File file) async {
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    final ref = FirebaseStorage.instance
        .ref()
        .child('receipts')
        .child(currentUserId)
        .child(fileName);
    final uploadTask = ref.putFile(file);
    final snapshot = await uploadTask.whenComplete(() => null);
    return await snapshot.ref.getDownloadURL();
  }

  String get currentUserId => _auth?.activeUserPhone ?? '';

  Future<void> submitDepositRequest({
    required String bankAccountId,
    required double amount,
    required String reference,
    required String receiptImageUrl,
  }) async {
    String? agentId;
    String? bankName;
    String? accountNumber;

    final agentsSnap = await _db
        .collection('users')
        .where('role', isEqualTo: 'agent')
        .where('networkIds', arrayContainsAny: currentUserNetworkIds)
        .get();

    for (var agentDoc in agentsSnap.docs) {
      final accDoc = await _db.collection('agent_bank_accounts').doc(bankAccountId).get();
      if (accDoc.exists) {
        agentId = agentDoc.id;
        bankName = accDoc.data()?['bankName'] ?? '';
        accountNumber = accDoc.data()?['accountNumber'] ?? '';
        break;
      }
    }

    if (agentId == null) throw Exception('الحساب غير موجود');

    await _db.collection('depositRequests').add({
      'userId': currentUserId,
      'userName': currentUserName,
      'agentId': agentId,
      'bankAccountId': bankAccountId,
      'bankName': bankName,
      'accountNumber': accountNumber,
      'amount': amount,
      'reference': reference,
      'receiptImageUrl': receiptImageUrl,
      'status': 'pending',
      'rejectionReason': '',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> cancelDepositRequest(String docId) async {
    await _db.collection('depositRequests').doc(docId).update({
      'status': 'cancelled',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<Map<String, dynamic>>> getPendingDepositRequestsStream() {
    return _db
        .collection('depositRequests')
        .where('userId', isEqualTo: currentUserId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) {
              final data = doc.data();
              return {
                'docId': doc.id,
                ...data,
              };
            }).toList());
  }

  Stream<List<Map<String, dynamic>>> getMyPendingUserRecharges() {
    if (_auth?.activeUserPhone == null) return Stream.value([]);
    return _db
        .collection('user_recharges')
        .where('userPhone', isEqualTo: _auth!.activeUserPhone)
        .where('status', isEqualTo: 'قيد الانتظار')
        .snapshots()
        .map((snap) => snap.docs.map((doc) {
              final data = doc.data();
              data['docId'] = doc.id;
              return data;
            }).toList());
  }

  Stream<List<Map<String, dynamic>>> getPendingPosRechargeRequests() {
    if (_auth?.activeUserPhone == null) return Stream.value([]);
    return _db
        .collection('user_recharges')
        .where('targetPhone', isEqualTo: _auth!.activeUserPhone)
        .where('status', isEqualTo: 'قيد الانتظار')
        .snapshots()
        .map((snap) => snap.docs.map((doc) {
              final data = doc.data();
              data['docId'] = doc.id;
              return data;
            }).toList());
  }

  Future<void> cancelQuotaRequest(String docId) async {
    await _db.collection('recharge_requests').doc(docId).delete();
  }

  // ---------- اشتراكات الوكلاء (مؤقتة هنا) ----------
  Map<String, dynamic> get subscriptionStats {
    int active = 0, expiringSoon = 0, frozen = 0;
    double realExpectedRevenue = 0.0;
    for (var agent in agentsList) {
      String status = agent['subStatus'] ?? 'نشط';
      if (status == 'نشط' || status == 'فترة مجانية') {
        active++;
        realExpectedRevenue += (agent['subPrice'] ?? 0.0).toDouble();
      } else if (status == 'إنذار') {
        expiringSoon++;
      } else if (status == 'مجمد' || status == 'موقوف مؤقتاً') {
        frozen++;
      }
    }
    return {
      'active': active,
      'expiringSoon': expiringSoon,
      'frozen': frozen,
      'expectedRevenue': realExpectedRevenue
    };
  }

  // ---------- دوال مساعدة (شبكات الوكلاء) ----------
  Future<List<Map<String, dynamic>>> getAgentNetworkNames() async {
    if (_auth?.activeUserPhone == null) return [];
    try {
      final snap = await _db
          .collection('networks')
          .where('agentPhone', isEqualTo: _auth!.activeUserPhone)
          .where('isActive', isEqualTo: true)
          .get();
      return snap.docs.map((doc) => {
        'networkId': doc.id,
        'networkName': doc['name'] ?? 'بدون اسم',
      }).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getRealAgentsForRecharge() async {
    try {
      final agentsSnap = await _db
          .collection('users')
          .where('role', isEqualTo: 'agent')
          .where('status', isEqualTo: 'نشط')
          .get();

      List<Map<String, dynamic>> realAgents = [];

      for (var doc in agentsSnap.docs) {
        final agent = doc.data();
        final phone = doc.id;

        final networksSnap = await _db
            .collection('networks')
            .where('agentPhone', isEqualTo: phone)
            .where('isActive', isEqualTo: true)
            .limit(1)
            .get();

        if (networksSnap.docs.isEmpty) continue;

        final banksSnap = await _db
            .collection('agent_bank_accounts')
            .where('agentPhone', isEqualTo: phone)
            .where('status', isEqualTo: 'نشط')
            .limit(1)
            .get();

        if (banksSnap.docs.isEmpty) continue;

        realAgents.add({
          'phone': phone,
          'name': agent['name'] ?? '',
          'networkName': agent['networkName'] ?? '',
        });
      }

      return realAgents;
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getActiveNetworksForRecharge() async {
    try {
      final agentsSnap = await _db
          .collection('users')
          .where('role', isEqualTo: 'agent')
          .where('status', isEqualTo: 'نشط')
          .get();

      List<Map<String, dynamic>> activeNetworks = [];

      for (var agentDoc in agentsSnap.docs) {
        final agentPhone = agentDoc.id;
        final agentData = agentDoc.data();

        final banksSnap = await _db
            .collection('agent_bank_accounts')
            .where('agentPhone', isEqualTo: agentPhone)
            .where('status', isEqualTo: 'نشط')
            .limit(1)
            .get();

        if (banksSnap.docs.isEmpty) continue;

        final networksSnap = await _db
            .collection('networks')
            .where('agentPhone', isEqualTo: agentPhone)
            .where('isActive', isEqualTo: true)
            .get();

        for (var netDoc in networksSnap.docs) {
          final netData = netDoc.data();
          activeNetworks.add({
            'networkId': netDoc.id,
            'networkName': netData['name'] ?? 'بدون اسم',
            'agentPhone': agentPhone,
            'agentName': agentData['name'] ?? agentPhone,
          });
        }
      }

      return activeNetworks;
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getAgentBankAccountsForUser(String agentPhone) async {
    final snap = await _db
        .collection('agent_bank_accounts')
        .where('agentPhone', isEqualTo: agentPhone)
        .where('status', isEqualTo: 'نشط')
        .orderBy('order')
        .get();
    return snap.docs.map((doc) => {'docId': doc.id, ...doc.data()}).toList();
  }

  Future<List<Map<String, dynamic>>> getActiveBankAccountsForUserNetworks() async {
    final agentsSnap = await _db
        .collection('users')
        .where('role', isEqualTo: 'agent')
        .get();

    List<Map<String, dynamic>> accounts = [];

    for (var agentDoc in agentsSnap.docs) {
      final agentId = agentDoc.id;
      final bankAccSnap = await _db
          .collection('agent_bank_accounts')
          .where('agentPhone', isEqualTo: agentId)
          .where('status', isEqualTo: 'نشط')
          .get();

      for (var accDoc in bankAccSnap.docs) {
        final data = accDoc.data();
        accounts.add({
          'docId': accDoc.id,
          'agentId': agentId,
          'agentPhone': agentId,
          ...data,
        });
      }
    }

    return accounts;
  }

  Future<void> adminAcceptSaaSRecharge(String requestId, String agentPhone,
      double quotaAmount, double feeAmount) async {
    final batch = _db.batch();

    batch.update(_db.collection('recharge_requests').doc(requestId), {
      'status': 'approved',
      'processedAt': FieldValue.serverTimestamp(),
    });

    batch.update(_db.collection('users').doc(agentPhone), {
      'balance': FieldValue.increment(quotaAmount),
    });

    final txnRef = _db.collection('transactions').doc();
    batch.set(txnRef, {
      'fromPhone': '774578241',
      'toPhone': agentPhone,
      'agentPhone': agentPhone,
      'agentName': '',
      'targetName': 'وكيل',
      'networkName': 'النظام',
      'type': 'deposit',
      'title': 'توريد حصة مبيعات (موافقة طلب)',
      'amount': quotaAmount,
      'fee': feeAmount,
      'paymentMethod': 'نظام SaaS',
      'reference': 'REQ-$requestId',
      'timestamp': FieldValue.serverTimestamp()
    });

    final notifRef = _db.collection('notifications').doc();
    batch.set(notifRef, {
      'targetPhones': [agentPhone],
      'title': 'تم شحن رصيدك! 🎉',
      'body': 'تمت الموافقة على طلبك وإضافة $quotaAmount ريال إلى محفظتك.',
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
      'readBy': [],
    });

    await batch.commit();
  }

  Future<void> rejectRechargeRequest(String requestId, String reason) async {
    final reqDoc = await _db.collection('recharge_requests').doc(requestId).get();
    if (reqDoc.exists) {
      final reqData = reqDoc.data() as Map<String, dynamic>;
      String agentPhone = reqData['userPhone'] ?? reqData['agentPhone'];

      final batch = _db.batch();
      batch.update(reqDoc.reference, {
        'status': 'rejected',
        'rejectReason': reason,
        'processedAt': FieldValue.serverTimestamp(),
      });

      final notifRef = _db.collection('notifications').doc();
      batch.set(notifRef, {
        'targetPhones': [agentPhone],
        'title': 'عذراً، تم رفض طلب الشحن ❌',
        'body': 'تم رفض طلب الشحن. السبب: $reason',
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'readBy': [],
      });

      await batch.commit();
    }
  }

  // ---------- دوال مساعدة (إشعارات، تدقيق) ----------
  void sendNotification({
    required List<String> targetPhones,
    required String title,
    required String body,
  }) async {
    await _db.collection('notifications').add({
      'targetPhones': targetPhones,
      'title': title,
      'body': body,
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
      'readBy': [],
    });
  }

  Future<void> _logAction({
    required String action,
    required String details,
    required String severity,
    String? targetPhone,
  }) async {
    if (_auth?.activeUserPhone == null) return;
    try {
      final userDoc = await _db.collection('users').doc(_auth!.activeUserPhone).get();
      final userData = userDoc.data() ?? {};
      final now = DateTime.now();
      final formattedDate =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

      await _db.collection('audit_logs').add({
        'name': userData['name'] ?? 'غير معروف',
        'phone': _auth!.activeUserPhone,
        'role': userData['role'] ?? 'Unknown',
        'action': action,
        'details': details,
        'datetime': formattedDate,
        'timestamp': FieldValue.serverTimestamp(),
        'ip': 'Cloud System',
        'severity': severity,
        'targetPhone': targetPhone,
      });
    } catch (e) {
      debugPrint('خطأ في تسجيل الحدث: $e');
    }
  }

  Future<void> updateUserPin(String pin) async {
    if (_auth?.activeUserPhone == null) return;
    await _db.collection('users').doc(_auth!.activeUserPhone).update({'pin': pin});
    final index = _usersDatabase.indexWhere((u) => u['phone'] == _auth!.activeUserPhone);
    if (index != -1) {
      _usersDatabase[index]['pin'] = pin;
      notifyListeners();
    }
  }

  Future<void> setHoldAmount(double amount) async {
    if (_auth?.activeUserPhone == null) return;
    await _db.collection('users').doc(_auth!.activeUserPhone).update({
      'heldBalance': amount,
    });
  }

  Future<void> updateDangerLimit(String phone, double newLimit) async {
    await _db.collection('users').doc(phone).update({'dangerLimit': newLimit});
  }
}
