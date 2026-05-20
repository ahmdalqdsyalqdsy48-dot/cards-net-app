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

class WalletProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final AuthProvider? _auth;

  WalletProvider(this._auth) {
    // استمع لتغيرات AuthProvider لتحديث المستمعين عند تسجيل الدخول/الخروج
    _auth?.addListener(_onAuthChanged);
    // إذا كان المستخدم مسجلاً بالفعل، قم بتشغيل المستمعين
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

  // ---------- بيانات المستخدمين والمعاملات (مخزنة محلياً) ----------
  List<Map<String, dynamic>> _usersDatabase = [];
  List<Map<String, dynamic>> _rechargeRequests = [];
  List<Map<String, dynamic>> _transactionsLedger = [];
  List<Map<String, dynamic>> _salesList = [];
  List<Map<String, dynamic>> _myAgentBankAccounts = [];

  StreamSubscription? _usersSub;
  StreamSubscription? _rechargeSub;
  StreamSubscription? _transactionsSub;
  StreamSubscription? _salesSub;
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

    _transactionsSub = _db
        .collection('transactions')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen((snapshot) {
      _transactionsLedger = snapshot.docs
          .map((doc) => {'docId': doc.id, ...doc.data()})
          .toList();
      notifyListeners();
    });

    _salesSub = _db.collection('sales').snapshots().listen((snapshot) {
      _salesList = snapshot.docs
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
    _transactionsSub?.cancel();
    _salesSub?.cancel();
    _agentBankSub?.cancel();
    _usersSub = null;
    _rechargeSub = null;
    _transactionsSub = null;
    _salesSub = null;
    _agentBankSub = null;
  }

  // ---------- الرادار التلقائي للاشتراكات المنتهية ----------
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

  // ---------- Getters ----------
  List<Map<String, dynamic>> get usersDatabase => _usersDatabase;
  List<Map<String, dynamic>> get agentsList =>
      _usersDatabase.where((user) => user['role'] == 'agent').toList();
  List<Map<String, dynamic>> get usersList =>
      _usersDatabase
          .where((user) => user['role'] == 'user' || user['role'] == 'pos')
          .toList();
  List<Map<String, dynamic>> get pendingRechargeRequests => _rechargeRequests;
  List<Map<String, dynamic>> get transactionsLedger => _transactionsLedger;
  List<Map<String, dynamic>> get salesList => _salesList;
  List<Map<String, dynamic>> get myAgentBankAccounts => _myAgentBankAccounts;

  double get currentUserBalance {
    if (_auth?.activeUserPhone == null) return 0.0;
    final user = _usersDatabase.firstWhere(
        (u) => u['phone'] == _auth!.activeUserPhone,
        orElse: () => {'balance': 0.0});
    if (user['role'] == 'user' || user['role'] == 'pos') {
      Map<String, dynamic> wallets = user['wallets'] ?? {};
      return wallets.values
          .fold(0.0, (sum, val) => sum + (val as num).toDouble());
    }
    return (user['balance'] ?? 0.0).toDouble();
  }

  double get availableBalance {
    return currentUserBalance - heldBalance;
  }

  double get heldBalance {
    if (_auth?.activeUserPhone == null) return 0.0;
    final user = _usersDatabase.firstWhere(
      (u) => u['phone'] == _auth!.activeUserPhone,
      orElse: () => {'heldBalance': 0.0},
    );
    return (user['heldBalance'] ?? 0.0).toDouble();
  }

  String get currentUserName {
    if (_auth?.activeUserPhone == null) return '';
    final user = _usersDatabase.firstWhere(
        (u) => u['phone'] == _auth!.activeUserPhone,
        orElse: () => {'name': ''});
    return user['name'] ?? '';
  }

  String? get activeUserPhone => _auth?.activeUserPhone;

  // ✅ تمت الإضافة: رمز PIN الحالي للمستخدم المسجل دخوله
  String get currentUserPin {
    if (_auth?.activeUserPhone == null) return '';
    final user = _usersDatabase.firstWhere(
      (u) => u['phone'] == _auth!.activeUserPhone,
      orElse: () => {'pin': '123456'},
    );
    return user['pin'] ?? '123456';
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

  // ---------- دوال شحن الرصيد ----------
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
    _sendNotification(
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

  // ---------- نقاط البيع وتمويلها ----------
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

  // ---------- وظائف مساعدة ----------
  void _sendNotification({
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

  // ---------- إعدادات المستخدم المالية ----------
  Future<void> setHoldAmount(double amount) async {
    if (_auth?.activeUserPhone == null) return;
    await _db.collection('users').doc(_auth!.activeUserPhone).update({
      'heldBalance': amount,
    });
  }

  Future<void> updateDangerLimit(String phone, double newLimit) async {
    await _db.collection('users').doc(phone).update({'dangerLimit': newLimit});
  }

  // ✅ تمت الإضافة: تحديث رمز PIN للمستخدم الحالي
  Future<void> updateUserPin(String pin) async {
    if (_auth?.activeUserPhone == null) return;
    await _db.collection('users').doc(_auth!.activeUserPhone).update({'pin': pin});
    final index = _usersDatabase.indexWhere((u) => u['phone'] == _auth!.activeUserPhone);
    if (index != -1) {
      _usersDatabase[index]['pin'] = pin;
      notifyListeners();
    }
  }
}
