import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_provider.dart';
import 'wallet_provider.dart';

class AgentAdminProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final AuthProvider _auth;
  final WalletProvider _wallet;

  AgentAdminProvider(this._auth, this._wallet);

  // ---------- إدارة الوكلاء ----------
  Future<void> addAgent({
    required String name,
    required String phone,
    required String password,
    String? networkName,
    String? profitMargin,
    String? location,
    double initialBalance = 0.0,
  }) async {
    try {
      bool exists = await _auth.checkUserExists(phone);
      if (!exists) {
        final DateTime nextMonth = DateTime.now().add(const Duration(days: 30));
        final String expiryDate =
            '${nextMonth.year}-${nextMonth.month.toString().padLeft(2, '0')}-${nextMonth.day.toString().padLeft(2, '0')}';

        await _db.collection('users').doc(phone).set({
          'id': 'AGENT_${DateTime.now().millisecondsSinceEpoch}',
          'name': name,
          'phone': phone,
          'password': password,
          'role': 'agent',
          'networkName': networkName ?? 'غير محدد',
          'profitMargin': profitMargin ?? 'غير محدد',
          'location': location ?? 'غير محدد',
          'balance': initialBalance,
          'dangerLimit': 0.0,
          'status': 'نشط',
          'pin': '123456',
          'subPlan': 'باقة افتراضية',
          'subPrice': 0.0,
          'subStatus': 'نشط',
          'subExpiry': expiryDate,
          'purchasedCards': [],
          'isBiometricEnabled': false,
          'createdAt': FieldValue.serverTimestamp(),
          'hiddenSections': [],
          'privacy_showPhone': true,
        });
        _logAction(
            action: 'إضافة وكيل جديد',
            details: 'تم إضافة وكيل جديد باسم "$name" ورقم $phone',
            severity: 'medium');

        _wallet.sendNotification(
            targetPhones: [phone],
            title: 'أهلاً بك كوكيل جديد! 🎉',
            body: 'تم تفعيل حسابك كوكيل معتمد في النظام.');
      } else {
        throw 'رقم الهاتف مسجل مسبقاً في النظام!';
      }
    } catch (e) {
      throw 'حدث خطأ: $e';
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
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data.addAll({
          'phone': newPhone,
          'name': newName,
          'networkName': newNetwork,
          'location': newLocation,
          'profitMargin': newProfit,
          'password': newPassword
        });
        WriteBatch batch = _db.batch();
        batch.set(_db.collection('users').doc(newPhone), data);
        if (oldPhone != newPhone) batch.delete(_db.collection('users').doc(oldPhone));
        await batch.commit();
      }
    } catch (e) {
      throw 'فشل تعديل بيانات الوكيل: $e';
    }
  }

  void toggleUserStatus(String phone, String currentStatus) {
    try {
      String newStatus = currentStatus == 'نشط' ? 'مجمد' : 'نشط';
      _db.collection('users').doc(phone).update({'status': newStatus});
    } catch (e) {}
  }

  void deleteAgent(String phone) {
    try {
      _db.collection('users').doc(phone).delete();
    } catch (e) {}
  }

  // ---------- نقاط البيع ----------
  Future<void> upgradeUserToPos({
    required String posPhone,
    required String storeName,
    required String location,
    required double creditLimit,
    required String commission,
    required List<String> allowedCategories,
    required double creditDeduction,
  }) async {
    if (_auth.activeUserPhone == null) return;
    try {
      final doc = await _db.collection('users').doc(posPhone).get();
      if (!doc.exists) throw 'الرقم غير مسجل كزبون مسبقاً.';

      final userData = doc.data() as Map<String, dynamic>;
      if (userData['role'] != 'user' && userData['role'] != 'pos') {
        throw 'لا يمكن تعديل صلاحية هذا الحساب.';
      }

      WriteBatch batch = _db.batch();

      batch.update(doc.reference, {
        'role': 'pos',
        'storeName': storeName,
        'location': location,
        'pos_agents': FieldValue.arrayUnion([_auth.activeUserPhone]),
        'agent_relations.${_auth.activeUserPhone}': {
          'creditLimit': creditLimit,
          'commission': commission,
          'allowedCategories': allowedCategories,
        }
      });

      batch.set(
          _db.collection('points_of_sale').doc(posPhone),
          {
            'phone': posPhone,
            'name': storeName,
            'location': location,
            'ownerName': userData['name'],
            'pos_agents': FieldValue.arrayUnion([_auth.activeUserPhone]),
            'status': 'نشط',
          },
          SetOptions(merge: true));

      final agentRef = _db.collection('users').doc(_auth.activeUserPhone);
      batch.update(agentRef, {'balance': FieldValue.increment(-creditDeduction)});

      DocumentReference txnRef = _db.collection('transactions').doc();
      batch.set(txnRef, {
        'fromPhone': _auth.activeUserPhone,
        'toPhone': posPhone,
        'agentPhone': _auth.activeUserPhone,
        'agentName': _wallet.currentUserName,
        'targetName': userData['name'] ?? 'مستخدم',
        'networkName': userData['networkName'] ?? 'غير محدد',
        'amount': creditDeduction,
        'type': 'credit_deduction',
        'title': 'حجز رصيد ائتماني لنقطة بيع: $storeName',
        'reference': 'CRD-${DateTime.now().millisecondsSinceEpoch}',
        'timestamp': FieldValue.serverTimestamp()
      });

      batch.set(_db.collection('notifications').doc(), {
        'targetPhones': [posPhone],
        'title': 'اعتماد نقطة بيع 🏪',
        'body': 'تم ربط حسابك بالوكيل ${_wallet.currentUserName} بأسعار الجملة بنجاح.',
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'readBy': [],
      });

      await batch.commit();
    } catch (e) {
      throw e.toString();
    }
  }

  Future<void> updatePosDetails({
    required String posPhone,
    required String storeName,
    required String location,
    required double creditLimit,
    required String commission,
    required List<String> allowedCategories,
    required double oldCreditLimit,
  }) async {
    if (_auth.activeUserPhone == null) return;
    try {
      WriteBatch batch = _db.batch();

      batch.update(_db.collection('users').doc(posPhone), {
        'storeName': storeName,
        'location': location,
        'agent_relations.${_auth.activeUserPhone}.creditLimit': creditLimit,
        'agent_relations.${_auth.activeUserPhone}.commission': commission,
        'agent_relations.${_auth.activeUserPhone}.allowedCategories': allowedCategories,
      });

      batch.update(_db.collection('points_of_sale').doc(posPhone), {
        'name': storeName,
        'location': location,
      });

      double difference = creditLimit - oldCreditLimit;
      if (difference > 0) {
        final agentRef = _db.collection('users').doc(_auth.activeUserPhone);
        batch.update(agentRef, {'balance': FieldValue.increment(-difference)});

        DocumentReference txnRef = _db.collection('transactions').doc();
        batch.set(txnRef, {
          'fromPhone': _auth.activeUserPhone,
          'toPhone': posPhone,
          'agentPhone': _auth.activeUserPhone,
          'agentName': _wallet.currentUserName,
          'targetName': 'نقطة بيع: $storeName',
          'networkName': 'النظام',
          'amount': difference,
          'type': 'credit_deduction',
          'title': 'زيادة الحد الائتماني لـ $storeName',
          'reference': 'CRD-${DateTime.now().millisecondsSinceEpoch}',
          'timestamp': FieldValue.serverTimestamp()
        });
      } else if (difference < 0) {
        double refund = (-difference);
        final agentRef = _db.collection('users').doc(_auth.activeUserPhone);
        batch.update(agentRef, {'balance': FieldValue.increment(refund)});

        DocumentReference txnRef = _db.collection('transactions').doc();
        batch.set(txnRef, {
          'fromPhone': posPhone,
          'toPhone': _auth.activeUserPhone,
          'agentPhone': _auth.activeUserPhone,
          'agentName': _wallet.currentUserName,
          'targetName': 'نقطة بيع: $storeName',
          'networkName': 'النظام',
          'amount': refund,
          'type': 'credit_refund',
          'title': 'تخفيض الحد الائتماني لـ $storeName وإعادة للمحفظة',
          'reference': 'RFD-${DateTime.now().millisecondsSinceEpoch}',
          'timestamp': FieldValue.serverTimestamp()
        });
      }

      await batch.commit();
    } catch (e) {
      throw 'فشل التعديل: $e';
    }
  }

  Future<void> receivePosPayment(String posPhone, double amount, String note) async {
    if (_auth.activeUserPhone == null) return;
    try {
      final posDoc = await _db.collection('users').doc(posPhone).get();
      final posData = posDoc.data() as Map<String, dynamic>? ?? {};

      WriteBatch batch = _db.batch();

      batch.update(_db.collection('users').doc(posPhone),
          {'wallets.${_auth.activeUserPhone}': FieldValue.increment(amount)});

      final agentRef = _db.collection('users').doc(_auth.activeUserPhone);
      batch.update(agentRef, {'balance': FieldValue.increment(amount)});

      batch.set(_db.collection('transactions').doc(), {
        'fromPhone': posPhone,
        'toPhone': _auth.activeUserPhone,
        'agentPhone': _auth.activeUserPhone,
        'agentName': _wallet.currentUserName,
        'targetName': posData['name'] ?? 'نقطة بيع',
        'networkName': posData['networkName'] ?? 'غير محدد',
        'type': 'deposit',
        'amount': amount,
        'fee': 0.0,
        'paymentMethod': 'نقدي / كاش',
        'note': note,
        'title': 'استلام سداد ديون من: ${posData['name'] ?? ''}',
        'reference': 'REP-${DateTime.now().millisecondsSinceEpoch}',
        'timestamp': FieldValue.serverTimestamp(),
      });

      await batch.commit();
    } catch (e) {
      throw e.toString();
    }
  }

  // ---------- الاشتراكات ----------
  Future<void> applySubscriptionPlan({
    required int targetingFilter,
    required String planName,
    required double planPrice,
    required int durationMonths,
    String? targetAgentPhone,
  }) async {
    try {
      WriteBatch batch = _db.batch();
      final DateTime newExpiry = DateTime.now().add(Duration(days: durationMonths * 30));
      final String formattedExpiry =
          '${newExpiry.year}-${newExpiry.month.toString().padLeft(2, '0')}-${newExpiry.day.toString().padLeft(2, '0')}';

      if (targetingFilter == 1) {
        for (var agent in _wallet.agentsList) {
          DocumentReference ref = _db.collection('users').doc(agent['phone']);
          batch.update(ref, {
            'subPlan': planName,
            'subPrice': planPrice,
            'subExpiry': formattedExpiry,
            'subStatus': 'نشط'
          });
        }
        _wallet.sendNotification(
            targetPhones: ['all_agents'],
            title: 'تحديث الباقة 🎁',
            body: 'تم تجديد باقتك إلى "$planName" بنجاح.');
      } else if (targetingFilter == 2 && targetAgentPhone != null) {
        DocumentReference ref = _db.collection('users').doc(targetAgentPhone);
        batch.update(ref, {
          'subPlan': planName,
          'subPrice': planPrice,
          'subExpiry': formattedExpiry,
          'subStatus': 'نشط'
        });
        _wallet.sendNotification(
            targetPhones: [targetAgentPhone],
            title: 'تحديث الباقة 🎁',
            body: 'تم تجديد باقتك إلى "$planName" بنجاح.');
      }
      await batch.commit();
    } catch (e) {
      throw 'حدث خطأ: $e';
    }
  }

  Future<void> updateAgentGracePeriod(String agentPhone, String newExpiryDate) async {
    try {
      await _db.collection('users').doc(agentPhone).update({
        'subExpiry': newExpiryDate,
        'subStatus': 'إنذار'
      });
      _wallet.sendNotification(
          targetPhones: [agentPhone],
          title: 'تنبيه فترة السماح ⚠️',
          body: 'تم تعديل تاريخ انتهاء باقتك إلى $newExpiryDate');
    } catch (e) {
      throw 'فشل التحديث: $e';
    }
  }

  Future<void> toggleSubscriptionStatus(String agentPhone, String currentStatus) async {
    try {
      String newStatus = currentStatus == 'موقوف مؤقتاً' ? 'نشط' : 'موقوف مؤقتاً';
      await _db.collection('users').doc(agentPhone).update({'subStatus': newStatus});
      _wallet.sendNotification(
          targetPhones: [agentPhone],
          title: 'حالة الحساب',
          body: 'تم تحويل حالة حسابك إلى: $newStatus');
    } catch (e) {
      throw 'فشل التغيير: $e';
    }
  }

  // ---------- تسوية يدوية ----------
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

  // ---------- حد الخطر ----------
  Future<void> updateDangerLimit(String phone, double newLimit) async {
    await _db.collection('users').doc(phone).update({'dangerLimit': newLimit});
  }

  // ---------- قبول شحن مشرف ----------
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

  // ---------- رفض طلب شحن ----------
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

  // ---------- الحسابات البنكية العامة ----------
  Future<void> addBankAccount(String bankName, String accNumber, String beneficiary) async {
    try {
      int newOrder = _wallet.bankAccounts.length;
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

  Future<void> updateBankAccount(String docId, String bankName, String accNumber, String beneficiary) async {
    await _db.collection('bank_accounts').doc(docId).update({
      'bankName': bankName,
      'accountNumber': accNumber,
      'beneficiary': beneficiary
    });
  }

  Future<void> toggleBankAccountStatus(String docId, String currentStatus) async {
    String newStatus = currentStatus == 'نشط' ? 'موقوف' : 'نشط';
    await _db.collection('bank_accounts').doc(docId).update({'status': newStatus});
  }

  Future<void> deleteBankAccount(String docId) async {
    await _db.collection('bank_accounts').doc(docId).delete();
  }

  Future<void> reorderBankAccounts(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) newIndex -= 1;
    final bankAccounts = List<Map<String, dynamic>>.from(_wallet.bankAccounts);
    final item = bankAccounts.removeAt(oldIndex);
    bankAccounts.insert(newIndex, item);
    WriteBatch batch = _db.batch();
    for (int i = 0; i < bankAccounts.length; i++) {
      batch.update(_db.collection('bank_accounts').doc(bankAccounts[i]['docId']),
          {'order': i});
    }
    await batch.commit();
    notifyListeners();
  }

  // ---------- أرقام الحسابات الجماعية ----------
  Future<int> adminGenerateMissingAccountNumbers() async {
    int generated = 0;
    try {
      final usersSnapshot = await _db.collection('users').get();
      for (var doc in usersSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['accountNumber'] == null) {
          final newAcc = await _wallet.generateNextAccountNumber();
          await doc.reference.update({'accountNumber': newAcc});
          generated++;
        }
      }
    } catch (e) {
      throw 'خطأ في التوليد الجماعي: $e';
    }
    return generated;
  }

  Future<void> adminUpdateUserAccountNumber(String phone, String newAccountNumber) async {
    final existing = await _db
        .collection('users')
        .where('accountNumber', isEqualTo: newAccountNumber)
        .get();
    if (existing.docs.isNotEmpty) {
      if (existing.docs.length > 1 || existing.docs.first.id != phone) {
        throw 'رقم الحساب مستخدم من قبل شخص آخر.';
      }
    }
    await _db.collection('users').doc(phone).update({
      'accountNumber': newAccountNumber,
    });
    _logAction(
        action: 'تعديل رقم حساب',
        details: 'تم تغيير رقم حساب $phone إلى $newAccountNumber',
        severity: 'high');
  }

  Future<void> adminToggleUserBan(String phone, bool ban) async {
    await _db.collection('users').doc(phone).update({
      'isBanned': ban,
    });
    _logAction(
        action: ban ? 'حظر حساب' : 'فك حظر حساب',
        details: 'المستخدم: $phone',
        severity: 'critical');
  }

  List<Map<String, dynamic>> getAllUsersWithAccountDetails() {
    return _wallet.usersDatabase.map((user) {
      return {
        'phone': user['phone'],
        'accountNumber': user['accountNumber'] ?? 'غير متوفر',
        'name': user['name'] ?? 'غير معروف',
        'role': user['role'] ?? 'مستخدم',
        'isBanned': user['isBanned'] ?? false,
        'privacyShowPhone': user['privacy_showPhone'] ?? true,
      };
    }).toList();
  }

  // ---------- البحث الإداري ----------
  Future<Map<String, dynamic>?> searchUserByAdmin(String query) async {
    if (query.trim().isEmpty) return null;
    final isNumeric = RegExp(r'^\d+$').hasMatch(query.trim());
    try {
      if (isNumeric) {
        var snap = await _db
            .collection('users')
            .where('accountNumber', isEqualTo: query.trim())
            .limit(1)
            .get();
        if (snap.docs.isEmpty) {
          snap = await _db
              .collection('users')
              .where('phone', isEqualTo: query.trim())
              .limit(1)
              .get();
        }
        if (snap.docs.isNotEmpty) {
          final data = snap.docs.first.data() as Map<String, dynamic>;
          return {
            ...data,
            'phone': snap.docs.first.id,
          };
        }
      } else {
        final snap = await _db
            .collection('users')
            .where('name', isGreaterThanOrEqualTo: query.trim())
            .where('name', isLessThan: '${query.trim()}z')
            .limit(1)
            .get();
        if (snap.docs.isNotEmpty) {
          final data = snap.docs.first.data() as Map<String, dynamic>;
          return {
            ...data,
            'phone': snap.docs.first.id,
          };
        }
      }
      return null;
    } catch (e) {
      throw 'خطأ في البحث الإداري: $e';
    }
  }

  // ---------- إعادة التعيين المتقدمة ----------
  Future<String> previewResetImpact({
    required String phone,
    required String accountNumber,
    required String targetType,
    required Map<String, dynamic> options,
  }) async {
    final WriteBatch batch = _db.batch();
    int affected = 0;
    final phones = <String>[];

    if (targetType == 'agent' || targetType == 'user') {
      String? docId = phone.isNotEmpty ? phone : null;
      if (docId == null && accountNumber.isNotEmpty) {
        final snap = await _db
            .collection('users')
            .where('accountNumber', isEqualTo: accountNumber)
            .limit(1)
            .get();
        if (snap.docs.isNotEmpty) docId = snap.docs.first.id;
      }
      if (docId != null) phones.add(docId);
    } else if (targetType == 'all_agents') {
      phones.addAll(_wallet.agentsList.map((a) => a['phone'].toString()));
    } else if (targetType == 'all_users') {
      phones.addAll(_wallet.usersList.map((u) => u['phone'].toString()));
    } else if (targetType == 'self') {
      phones.add(_auth.activeUserPhone ?? '');
    }

    for (final phone in phones) {
      if (options['resetBalance'] == true) {
        batch.update(_db.collection('users').doc(phone), {'balance': 0, 'wallets': {}});
        affected++;
      }
      if (options['resetNetworks'] == true) {
        final nets = await _db.collection('networks').where('agentPhone', isEqualTo: phone).get();
        for (final d in nets.docs) batch.delete(d.reference);
        affected += nets.size;
      }
      if (options['resetTransactions'] == true) {
        final txns = await _db.collection('transactions').where('fromPhone', isEqualTo: phone).get();
        for (final d in txns.docs) batch.delete(d.reference);
        final txns2 = await _db.collection('transactions').where('toPhone', isEqualTo: phone).get();
        for (final d in txns2.docs) if (!txns.docs.any((e) => e.id == d.id)) batch.delete(d.reference);
        affected += txns.size + txns2.size;
      }
      if (options['resetCards'] == true) {
        final cards = await _db.collection('cards').where('buyerPhone', isEqualTo: phone).get();
        for (final d in cards.docs) batch.delete(d.reference);
        affected += cards.size;
      }
      if (options['resetBankAccounts'] == true) {
        final banks = await _db.collection('agent_bank_accounts').where('agentPhone', isEqualTo: phone).get();
        for (final d in banks.docs) batch.delete(d.reference);
        affected += banks.size;
      }
      if (options['resetSubscriptions'] == true) {
        batch.update(_db.collection('users').doc(phone), {
          'subPlan': '',
          'subPrice': 0,
          'subStatus': 'ملغي',
          'subExpiry': '',
        });
        affected++;
      }
      if (options['deleteAccount'] == true) {
        affected += 5;
      }
    }
    return 'متوقع تأثر حوالي $affected مستند/حقل.';
  }

  Future<void> executeReset({
    required String phone,
    required String accountNumber,
    required String targetType,
    required Map<String, dynamic> options,
    required String adminPassword,
    String? renameTo,
    String? mergeFrom,
    String? mergeTo,
    bool exportBeforeDelete = false,
  }) async {
    final WriteBatch batch = _db.batch();
    final phones = <String>[];

    if (targetType == 'agent' || targetType == 'user') {
      String? docId = phone.isNotEmpty ? phone : null;
      if (docId == null && accountNumber.isNotEmpty) {
        final snap = await _db
            .collection('users')
            .where('accountNumber', isEqualTo: accountNumber)
            .limit(1)
            .get();
        if (snap.docs.isNotEmpty) docId = snap.docs.first.id;
      }
      if (docId != null) phones.add(docId);
    } else if (targetType == 'all_agents') {
      phones.addAll(_wallet.agentsList.map((a) => a['phone'].toString()));
    } else if (targetType == 'all_users') {
      phones.addAll(_wallet.usersList.map((u) => u['phone'].toString()));
    } else if (targetType == 'self') {
      phones.add(_auth.activeUserPhone ?? '');
    }

    for (final phone in phones) {
      if (options['resetBalance'] == true) {
        batch.update(_db.collection('users').doc(phone), {'balance': 0, 'wallets': {}});
      }
      if (options['resetNetworks'] == true) {
        final nets = await _db.collection('networks').where('agentPhone', isEqualTo: phone).get();
        for (final d in nets.docs) batch.delete(d.reference);
      }
      if (options['resetTransactions'] == true) {
        final txns = await _db.collection('transactions').where('fromPhone', isEqualTo: phone).get();
        for (final d in txns.docs) batch.delete(d.reference);
        final txns2 = await _db.collection('transactions').where('toPhone', isEqualTo: phone).get();
        for (final d in txns2.docs) if (!txns.docs.any((e) => e.id == d.id)) batch.delete(d.reference);
      }
      if (options['resetCards'] == true) {
        final cards = await _db.collection('cards').where('buyerPhone', isEqualTo: phone).get();
        for (final d in cards.docs) batch.delete(d.reference);
      }
      if (options['resetBankAccounts'] == true) {
        final banks = await _db.collection('agent_bank_accounts').where('agentPhone', isEqualTo: phone).get();
        for (final d in banks.docs) batch.delete(d.reference);
      }
      if (options['resetSubscriptions'] == true) {
        batch.update(_db.collection('users').doc(phone), {
          'subPlan': '',
          'subPrice': 0,
          'subStatus': 'ملغي',
          'subExpiry': '',
        });
      }
      if (options['renameAccount'] == true && renameTo != null && renameTo.isNotEmpty) {
        batch.update(_db.collection('users').doc(phone), {'name': renameTo});
      }
      if (options['deleteAccount'] == true) {
        batch.delete(_db.collection('users').doc(phone));
      }
    }

    if (options['mergeRecords'] == true && mergeFrom != null && mergeTo != null) {
      final fromTxns = await _db.collection('transactions').where('fromPhone', isEqualTo: mergeFrom).get();
      for (final d in fromTxns.docs) {
        batch.update(d.reference, {'fromPhone': mergeTo});
      }
      final toTxns = await _db.collection('transactions').where('toPhone', isEqualTo: mergeFrom).get();
      for (final d in toTxns.docs) {
        batch.update(d.reference, {'toPhone': mergeTo});
      }
    }

    await batch.commit();

    _logAction(
      action: 'إعادة تهيئة متقدمة',
      details: 'نوع الهدف: $targetType, الخيارات: $options',
      severity: 'critical',
    );
  }

  // ---------- دوال مساعدة ----------
  void _logAction({
    required String action,
    required String details,
    required String severity,
    String? targetPhone,
  }) async {
    if (_auth.activeUserPhone == null) return;
    try {
      final userDoc = await _db.collection('users').doc(_auth.activeUserPhone!).get();
      final userData = userDoc.data() ?? {};
      final now = DateTime.now();
      final formattedDate =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

      await _db.collection('audit_logs').add({
        'name': userData['name'] ?? 'غير معروف',
        'phone': _auth.activeUserPhone,
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
}
