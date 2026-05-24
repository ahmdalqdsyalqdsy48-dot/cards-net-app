import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_provider.dart';
import '../services/sound_service.dart';

class NotificationProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final AuthProvider _auth;
  final SoundService _soundService;

  List<Map<String, dynamic>> _notifications = [];
  StreamSubscription? _notificationSubscription;

  /// لتتبع الإشعارات السابقة ومنع تكرار الصوت عند التحميل الأول
  Set<String> _previousDocIds = {};

  NotificationProvider(this._auth, this._soundService) {
    _auth.addListener(_onAuthChanged);
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
      _previousDocIds = {};
      notifyListeners();
    }
  }

  void _startListening() {
    _cancelSubscription();

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

      // جمع معرّفات الإشعارات الحالية
      final Set<String> currentIds = _notifications
          .map((n) => n['docId'] as String)
          .toSet();

      // في أول تحميل، نخزن المعرّفات ولا نشغل صوت
      if (_previousDocIds.isEmpty) {
        _previousDocIds = currentIds;
      } else {
        // الإشعارات الجديدة = الموجودة الآن وغير موجودة سابقاً
        final newIds = currentIds.difference(_previousDocIds);

        // تشغيل صوت لكل إشعار جديد يظهر
        for (final _ in newIds) {
          _soundService.play('notification');
        }

        _previousDocIds = currentIds;
      }

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
