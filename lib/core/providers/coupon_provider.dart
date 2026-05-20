import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CouponProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  List<Map<String, dynamic>> _coupons = [];

  CouponProvider() {
    _initCouponsListener();
  }

  void _initCouponsListener() {
    _db
        .collection('coupons')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) {
      _coupons = snapshot.docs
          .map((doc) => {'docId': doc.id, ...doc.data()})
          .toList();
      notifyListeners();
    });
  }

  // ---------- Getters ----------
  List<Map<String, dynamic>> get coupons => _coupons;

  // ---------- دوال الكوبونات ----------

  /// إنشاء كوبون خصم جديد
  Future<void> createSmartCoupon({
    required String code,
    required String discountDetails,
    required int maxUses,
    required String sendMethod,
  }) async {
    try {
      // التحقق من عدم وجود الكود مسبقاً
      final existing =
          await _db.collection('coupons').where('code', isEqualTo: code).get();
      if (existing.docs.isNotEmpty) throw 'كود الكوبون مستخدم مسبقاً!';

      // إضافة الكوبون
      await _db.collection('coupons').add({
        'code': code.toUpperCase(),
        'discountDetails': discountDetails,
        'maxUses': maxUses,
        'usedCount': 0,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // تسجيل رسالة صادرة (لأغراض التواصل مع الوكلاء)
      await _db.collection('outbox_messages').add({
        'type': sendMethod,
        'content': 'تم إصدار كوبون جديد: $code بخصم $discountDetails',
        'target': 'all_agents',
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'sent'
      });

      // إرسال إشعار لكل الوكلاء
      await _db.collection('notifications').add({
        'targetPhones': ['all_agents'],
        'title': 'كوبون جديد متاح! 🎟️',
        'body': 'استخدم الكود $code للحصول على $discountDetails',
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'readBy': [],
      });
    } catch (e) {
      throw 'فشل إنشاء الكوبون: $e';
    }
  }

  /// إيقاف كوبون (تعطيله)
  Future<void> deactivateCoupon(String docId, String code) async {
    try {
      await _db.collection('coupons').doc(docId).update({'isActive': false});
    } catch (e) {
      throw 'فشل إيقاف الكوبون: $e';
    }
  }
}
