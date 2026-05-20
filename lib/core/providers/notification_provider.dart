import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_provider.dart';

class NotificationProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final AuthProvider _auth;

  List<Map<String, dynamic>> _notifications = [];
  StreamSubscription? _notificationSubscription;

  NotificationProvider(this._auth) {
    // استمع لتغيرات AuthProvider لتحديث المستمعين عند تسجيل الدخول/الخروج
    _auth.addListener(_onAuthChanged);
    // إذا كان المستخدم مسجلاً بالفعل، قم بتشغيل المستمعين
    if (_auth.activeUserPhone != null) {
      _startListening();
    }
  }

  @override
  void dispose() {
    _cancelSubscription();
    _auth.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    if (_auth.activeUserPhone != null) {
      _startListening();
    } else {
      _cancelSubscription();
      _notifications = [];
      notifyListeners();
    }
  }

  void _startListening() {
    _cancelSubscription(); // إلغاء أي مستمع سابق

    _notificationSubscription = _db
        .collection('notifications')
        .where('targetPhones', arrayContainsAny: [
          _auth.activeUserPhone,
          'all',
          _auth.currentUserRole == 'agent' ? 'all_agents' : 'all_staff'
        ])
        .orderBy('timestamp', descending: true)
        .limit(30)
        .snapshots()
        .listen((snapshot) {
      _notifications = snapshot.docs.map((doc) {
        final data = doc.data();
        List readBy = data['readBy'] ?? [];
        bool isRead = readBy.contains(_auth.activeUserPhone) ||
            data['isRead'] == true;
        return {'docId': doc.id, ...data, 'isReadLocal': isRead};
      }).toList();
      notifyListeners();
    });
  }

  void _cancelSubscription() {
    _notificationSubscription?.cancel();
    _notificationSubscription = null;
  }

  // ---------- Getters ----------
  List<Map<String, dynamic>> get notifications => _notifications;

  int get unreadNotificationsCount =>
      _notifications.where((n) => n['isReadLocal'] == false).length;

  // ---------- دوال الإشعارات ----------

  /// تعليم جميع الإشعارات الحالية كمقروءة
  Future<void> markNotificationsAsRead() async {
    if (_auth.activeUserPhone == null) return;

    WriteBatch batch = _db.batch();
    for (var notif in _notifications) {
      if (notif['isReadLocal'] == false) {
        DocumentReference ref =
            _db.collection('notifications').doc(notif['docId']);
        batch.update(
            ref, {'readBy': FieldValue.arrayUnion([_auth.activeUserPhone])});
      }
    }
    await batch.commit();
  }

  /// إرسال إشعار جديد (تستخدمه المزودات الأخرى)
  Future<void> sendNotification({
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
}
