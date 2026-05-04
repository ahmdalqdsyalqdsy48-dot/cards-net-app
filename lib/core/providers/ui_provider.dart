import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:audioplayers/audioplayers.dart';

class UiProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final AudioPlayer _clickPlayer = AudioPlayer();
  final AudioPlayer _successPlayer = AudioPlayer();
  final AudioPlayer _errorPlayer = AudioPlayer();
  final AudioPlayer _notifPlayer = AudioPlayer();

  bool _isOnline = true;
  List<Map<String, dynamic>> _unreadNotifications = [];
  bool _hasNewNotifications = false;
  String _globalSearchQuery = '';

  // الصوت مفتوح دائماً
  bool _soundsEnabled = true;

  // رقم هاتف المستخدم الحالي (يُستخدم في الإشعارات)
  String? _currentUserPhone;

  UiProvider(String? currentUserId) {
    _currentUserPhone = currentUserId;
    _monitorInternetConnection();
    if (currentUserId != null) {
      _listenToNotifications(currentUserId);
    }
  }

  bool get isOnline => _isOnline;
  bool get hasNewNotifications => _hasNewNotifications;
  List<Map<String, dynamic>> get unreadNotifications => _unreadNotifications;
  String get globalSearchQuery => _globalSearchQuery;
  bool get isSoundsEnabled => _soundsEnabled;

  Future<void> updateSoundSettings(bool value) async {
    _soundsEnabled = true; // الصوت مفتوح دائماً
    notifyListeners();
    if (value) playSound('success');
  }

  Future<void> playSound(String type) async {
    try {
      if (type == 'click') {
        await _clickPlayer.play(AssetSource('sounds/click.mp3'), volume: 0.5);
      } else if (type == 'success') {
        await _successPlayer.play(AssetSource('sounds/success.mp3'), volume: 1.0);
      } else if (type == 'error') {
        await _errorPlayer.play(AssetSource('sounds/error.mp3'), volume: 0.8);
      } else if (type == 'notification') {
        await _notifPlayer.play(AssetSource('sounds/notification.mp3'), volume: 1.0);
      }
    } catch (e) {
      debugPrint('تحذير الصوت (طبيعي في المتصفحات قبل التفاعل): $e');
    }
  }

  void _monitorInternetConnection() {
    _isOnline = true;
    notifyListeners();
  }

  void toggleOfflineModeForTesting(bool isOffline) {
    _isOnline = !isOffline;
    notifyListeners();
  }

  void _listenToNotifications(String userId) {
    _db
        .collection('notifications')
        .where('targetPhones', arrayContains: userId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen((snapshot) {
      bool hadNew = _hasNewNotifications;
      _unreadNotifications =
          snapshot.docs.map((doc) {
            final data = doc.data();
            final readBy = List<String>.from(data['readBy'] ?? []);
            final isReadLocal = readBy.contains(userId);
            return {'docId': doc.id, ...data, 'isReadLocal': isReadLocal};
          }).toList();
      _hasNewNotifications =
          _unreadNotifications.any((n) => n['isReadLocal'] == false);

      if (_hasNewNotifications && !hadNew) {
        playSound('notification');
      }

      notifyListeners();
    });
  }

  Future<void> markNotificationsAsRead() async {
    if (_unreadNotifications.isEmpty) return;
    final phone = _currentUserPhone;
    if (phone == null) return;
    WriteBatch batch = _db.batch();
    for (var notif in _unreadNotifications) {
      batch.update(
        _db.collection('notifications').doc(notif['docId']),
        {'readBy': FieldValue.arrayUnion([phone])},
      );
    }
    _unreadNotifications.clear();
    _hasNewNotifications = false;
    notifyListeners();
    try {
      await batch.commit();
    } catch (e) {
      debugPrint('خطأ: $e');
    }
  }

  void updateSearchQuery(String query) {
    _globalSearchQuery = query;
    notifyListeners();
  }
}
