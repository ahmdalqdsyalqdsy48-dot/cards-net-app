import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;

class WalletProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const String _serverUrl = 'https://mikrotik-server-qu6a.onrender.com';

  // ---------- بيانات الجلسة (تُضبط من AuthProvider) ----------
  String? _authToken;
  String? _activeUserPhone;

  // ---------- الحسابات البنكية (مشرف) ----------
  List<Map<String, dynamic>> _bankAccounts = [];

  // ---------- الحسابات البنكية (وكيل) ----------
  List<Map<String, dynamic>> _myAgentBankAccounts = [];
  StreamSubscription? _agentBankSubscription;

  // ---------- طلبات الشحن ----------
  List<Map<String, dynamic>> _rechargeRequests = [];

  // ---------- الحجز المالي ----------
  double _heldBalance = 0.0;

  // ---------- تهيئة المستمعات ----------
  WalletProvider() {
    _initListeners();
  }

  void _initListeners() {
    // حسابات بنكية للنظام
    _db
        .collection('bank_accounts')
        .orderBy('order')
        .snapshots()
        .listen((snapshot) {
      _bankAccounts =
          snapshot.docs.map((doc) => {'docId': doc.id, ...doc.data()}).toList();
      notifyListeners();
    });

    // طلبات الشحن (للوكيل)
    _db
        .collection('recharge_requests')
        .where('status', isEqualTo: 'قيد الانتظار')
        .snapshots()
        .listen((snapshot) {
      _rechargeRequests =
          snapshot.docs.map((doc) => {'docId': doc.id, ...doc.data()}).toList();
      notifyListeners();
    });
  }

  // ---------- دالة لضبط الجلسة (تُستدعى بعد تسجيل الدخول) ----------
  void setSession(String? authToken, String? activeUserPhone) {
    _authToken = authToken;
    _activeUserPhone = activeUserPhone;
    _listenToAgentBankAccounts();
    _listenToUserRecharges();
  }

  void clearSession() {
    _authToken = null;
    _activeUserPhone = null;
    _agentBankSubscription?.cancel();
    _agentBankSubscription = null;
    _myAgentBankAccounts = [];
    _rechargeRequests = [];
  }

  // ---------- مستمع حسابات الوكيل الشخصية ----------
  void _listenToAgentBankAccounts() {
    _agentBankSubscription?.cancel();
    if (_activeUserPhone != null) {
      _agentBankSubscription = _db
          .collection('agent_bank_accounts')
          .where('agentPhone', isEqualTo: _activeUserPhone)
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

  StreamSubscription? _userRechargesSubscription;
  void _listenToUserRecharges() {
    _userRechargesSubscription?.cancel();
    // يمكن تفعيله عند الحاجة
  }

  // ------------------- دالة الاتصال بالخادم -------------------
  Future<Map<String, dynamic>> _post(String endpoint, Map<String, dynamic> body,
      {bool authenticate = false}) async {
    final uri = Uri.parse('$_serverUrl$endpoint');
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (authenticate && _authToken != null) {
      headers['Authorization'] = 'Bearer $_authToken';
    }
    final response =
        await http.post(uri, headers: headers, body: jsonEncode(body));
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw decoded['error'] ?? 'خطأ غير معروف';
    }
    return decoded;
  }

  // ------------------- دوال الحسابات البنكية للوكيل -------------------
  Future<void> addAgentBankAccount(String networkName, String agentName,
      String bankName, String accNumber, String note, [List<String>? networkIds]) async {
    if (_activeUserPhone == null) return;
    try {
      int newOrder = _myAgentBankAccounts.length;
      final docRef = await _db.collection('agent_bank_accounts').add({
        'agentPhone': _activeUserPhone,
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
        'agentPhone': _activeUserPhone,
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

  Future<List<Map<String, dynamic>>> getAgentNetworkNames() async {
    if (_activeUserPhone == null) return [];
    try {
      final snap = await _db
          .collection('networks')
          .where('agentPhone', isEqualTo: _activeUserPhone)
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

  // ------------------- طلبات الشحن والتحويل (مستخدم) -------------------
  Future<void> requestRechargeFromAgent({
    required String agentPhone,
    required double amount,
    required String paymentMethod,
    required String reference,
    String? base64Image,
    String? fullName,
  }) async {
    if (_activeUserPhone == null) throw 'يرجى تسجيل الدخول.';
    final docData = <String, dynamic>{
      'userPhone': _activeUserPhone,
      'userName': '', // سيتم ملؤه من AuthProvider عند الاستخدام
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
    // استدعاء الإشعار سيكون من خلال NotificationProvider
  }

  Future<void> submitDepositRequest({
    required String bankAccountId,
    required double amount,
    required String reference,
    required String receiptImageUrl,
  }) async {
    if (_activeUserPhone == null) throw 'يرجى تسجيل الدخول.';
    // البحث عن معرف الوكيل صاحب الحساب
    final accDoc = await _db.collection('agent_bank_accounts').doc(bankAccountId).get();
    if (!accDoc.exists) throw 'الحساب غير موجود';
    final agentId = accDoc.data()?['agentPhone'] ?? '';
    final bankName = accDoc.data()?['bankName'] ?? '';
    final accountNumber = accDoc.data()?['accountNumber'] ?? '';

    await _db.collection('depositRequests').add({
      'userId': _activeUserPhone,
      'userName': '', // من AuthProvider
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
    if (_activeUserPhone == null) return Stream.value([]);
    return _db
        .collection('depositRequests')
        .where('userId', isEqualTo: _activeUserPhone)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) {
              final data = doc.data();
              return {'docId': doc.id, ...data};
            }).toList());
  }

  Future<String> uploadReceiptImage(File file) async {
    if (_activeUserPhone == null) throw 'يرجى تسجيل الدخول';
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    final ref = FirebaseStorage.instance
        .ref()
        .child('receipts')
        .child(_activeUserPhone!)
        .child(fileName);
    final uploadTask = ref.putFile(file);
    final snapshot = await uploadTask.whenComplete(() => null);
    return await snapshot.ref.getDownloadURL();
  }

  // ------------------- طلبات الشحن (وكيل) -------------------
  Future<void> submitSaaSRechargeRequest({
    required double quotaAmount,
    required double feeAmount,
    required String adminBankName,
    required String transferSource,
    required String reference,
    required String base64Image,
  }) async {
    await _post('/api/recharge-request', {
      'amount': quotaAmount,
      'bankName': adminBankName,
      'transferSource': transferSource,
      'reference': reference,
      'receiptBase64': base64Image,
    }, authenticate: true);
  }

  Future<void> adminAcceptSaaSRecharge(String requestId, String agentPhone,
      double quotaAmount, double feeAmount) async {
    await _post('/api/accept-recharge', {
      'requestId': requestId,
      'agentPhone': agentPhone,
      'quotaAmount': quotaAmount,
    }, authenticate: true);
  }

  Future<void> rejectRechargeRequest(String requestId, String reason) async {
    try {
      final reqDoc =
          await _db.collection('recharge_requests').doc(requestId).get();
      if (reqDoc.exists) {
        final reqData = reqDoc.data() as Map<String, dynamic>;
        String userPhone = reqData['userPhone'];

        WriteBatch batch = _db.batch();
        batch.update(
            reqDoc.reference, {'status': 'مرفوض', 'rejectReason': reason});

        // إرسال إشعار بالرفض (يمكن استدعاء NotificationProvider)
        DocumentReference notifRef = _db.collection('notifications').doc();
        batch.set(notifRef, {
          'targetPhones': [userPhone],
          'title': 'تم رفض طلب الشحن ❌',
          'body': 'السبب: $reason',
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
          'readBy': [],
        });

        await batch.commit();
      }
    } catch (e) {}
  }

  Future<void> cancelQuotaRequest(String docId) async {
    await _db.collection('recharge_requests').doc(docId).delete();
  }

  Future<void> agentAcceptUserRecharge(
      String requestId, String requesterPhone, double amount) async {
    if (_activeUserPhone == null) return;

    final myDoc = await _db.collection('users').doc(_activeUserPhone).get();
    final myData = myDoc.data() as Map<String, dynamic>? ?? {};
    if ((myData['balance'] ?? 0.0) < amount) {
      throw 'رصيدك لا يكفي! قم بتغذية رصيدك أولاً لتتمكن من إعطاء رصيد للآخرين.';
    }

    final requesterDoc =
        await _db.collection('users').doc(requesterPhone).get();
    final requesterData = requesterDoc.data() as Map<String, dynamic>? ?? {};

    WriteBatch batch = _db.batch();

    batch.update(
        _db.collection('user_recharges').doc(requestId), {'status': 'مقبول'});
    batch.update(myDoc.reference, {'balance': FieldValue.increment(-amount)});

    batch.update(requesterDoc.reference,
        {'wallets.$_activeUserPhone': FieldValue.increment(amount)});

    batch.set(_db.collection('transactions').doc(), {
      'fromPhone': _activeUserPhone,
      'toPhone': requesterPhone,
      'agentPhone': _activeUserPhone,
      'agentName': '', // يُملأ من AuthProvider
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
      'body': 'تمت الموافقة وإضافة $amount ريال لمحفظتك من $_activeUserPhone.',
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
      'readBy': [],
    });

    await batch.commit();
  }

  // ------------------- تحويل رصيد بين مستخدمين -------------------
  Future<void> transferToUser({
    required String targetPhone,
    required double amount,
  }) async {
    if (_activeUserPhone == null) throw 'يرجى تسجيل الدخول.';
    // التحقق من الرصيد المتاح سيكون في AuthProvider
    await _post('/api/transfer', {
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
    if (_activeUserPhone == null) throw 'يرجى تسجيل الدخول.';
    // التحقق من كلمة المرور يتم في AuthProvider
    await _post('/api/transfer', {
      'targetPhone': targetPhone,
      'amount': amount,
    }, authenticate: true);
  }

  Future<Map<String, dynamic>?> searchUserForTransfer(
      String targetPhone) async {
    if (_activeUserPhone == null) throw 'يرجى تسجيل الدخول.';
    if (targetPhone == _activeUserPhone) throw 'لا يمكنك تحويل الرصيد لنفسك!';

    try {
      final doc = await _db.collection('users').doc(targetPhone).get();
      if (!doc.exists) return null;

      final data = doc.data() as Map<String, dynamic>;

      var lastTxn = await _db
          .collection('transactions')
          .where('toPhone', isEqualTo: targetPhone)
          .where('fromPhone', isEqualTo: _activeUserPhone)
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
        displayBalance = (wallets[_activeUserPhone] ?? 0.0).toDouble();
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

  // ------------------- الحجز المالي -------------------
  Future<void> setHoldAmount(double amount) async {
    if (_activeUserPhone == null) return;
    await _db.collection('users').doc(_activeUserPhone).update({'heldBalance': amount});
    _heldBalance = amount;
    notifyListeners();
  }

  // ------------------- Getters -------------------
  List<Map<String, dynamic>> get bankAccounts => _bankAccounts;
  List<Map<String, dynamic>> get myAgentBankAccounts => _myAgentBankAccounts;
  List<Map<String, dynamic>> get pendingRechargeRequests => _rechargeRequests;

  double get heldBalance => _heldBalance;
  // availableBalance تحتاج لمزود آخر، لذا سنكتفي بـ heldBalance هنا

  Stream<List<Map<String, dynamic>>> getMyPendingQuotaRequests() {
    if (_activeUserPhone == null) return Stream.value([]);
    return _db
        .collection('recharge_requests')
        .where('userPhone', isEqualTo: _activeUserPhone)
        .where('type', isEqualTo: 'saas_quota')
        .where('status', isEqualTo: 'قيد الانتظار')
        .snapshots()
        .map((snap) => snap.docs.map((doc) {
              final data = doc.data();
              data['docId'] = doc.id;
              return data;
            }).toList());
  }

  Stream<List<Map<String, dynamic>>> getPendingPosRechargeRequests() {
    if (_activeUserPhone == null) return Stream.value([]);
    return _db
        .collection('user_recharges')
        .where('targetPhone', isEqualTo: _activeUserPhone)
        .where('status', isEqualTo: 'قيد الانتظار')
        .snapshots()
        .map((snap) => snap.docs.map((doc) {
              final data = doc.data();
              data['docId'] = doc.id;
              return data;
            }).toList());
  }

  // ------------------- الحسابات البنكية (مشرف) -------------------
  Future<void> addBankAccount(
      String bankName, String accNumber, String beneficiary) async {
    try {
      int newOrder = _bankAccounts.length;
      await _db.collection('bank_accounts').add({
        'bankName': bankName,
        'accountNumber': accNumber,
        'beneficiary': beneficiary.isNotEmpty ? beneficiary : 'غير محدد',
        'status': 'نشط',
        'hasQR': false,
        'order': newOrder,
        'createdAt': FieldValue.serverTimestamp()
      });
    } catch (e) {
      throw 'خطأ: $e';
    }
  }

  Future<void> updateBankAccount(
      String docId, String bankName, String accNumber, String beneficiary) async {
    await _db.collection('bank_accounts').doc(docId).update({
      'bankName': bankName,
      'accountNumber': accNumber,
      'beneficiary': beneficiary
    });
  }

  Future<void> toggleBankAccountStatus(
      String docId, String currentStatus) async {
    String newStatus = currentStatus == 'نشط' ? 'موقوف' : 'نشط';
    await _db
        .collection('bank_accounts')
        .doc(docId)
        .update({'status': newStatus});
  }

  Future<void> deleteBankAccount(String docId) async {
    await _db.collection('bank_accounts').doc(docId).delete();
  }

  Future<void> reorderBankAccounts(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) newIndex -= 1;
    final item = _bankAccounts.removeAt(oldIndex);
    _bankAccounts.insert(newIndex, item);
    notifyListeners();
    WriteBatch batch = _db.batch();
    for (int i = 0; i < _bankAccounts.length; i++) {
      batch.update(_db.collection('bank_accounts').doc(_bankAccounts[i]['docId']),
          {'order': i});
    }
    await batch.commit();
  }
}
