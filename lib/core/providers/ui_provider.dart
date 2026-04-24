import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  bool _soundsEnabled = true;

  UiProvider(String? currentUserId) {
    _monitorInternetConnection();
    _loadSoundSettings();
    // إعداد المشغلات الصوتية للتشغيل على الويب
    _setupAudioPlayers();
    if (currentUserId != null) {
      _listenToNotifications(currentUserId);
    }
  }

  bool get isOnline => _isOnline;
  bool get hasNewNotifications => _hasNewNotifications;
  List<Map<String, dynamic>> get unreadNotifications => _unreadNotifications;
  String get globalSearchQuery => _globalSearchQuery;
  bool get isSoundsEnabled => _soundsEnabled;

  void _setupAudioPlayers() {
    // تفعيل وضع التشغيل المنخفض لمنع التأخير على الويب
    _clickPlayer.setReleaseMode(ReleaseMode.stop);
    _successPlayer.setReleaseMode(ReleaseMode.stop);
    _errorPlayer.setReleaseMode(ReleaseMode.stop);
    _notifPlayer.setReleaseMode(ReleaseMode.stop);

    // تعيين حجم الصوت الافتراضي
    _clickPlayer.setVolume(0.5);
    _successPlayer.setVolume(1.0);
    _errorPlayer.setVolume(0.8);
    _notifPlayer.setVolume(1.0);
  }

  Future<void> _loadSoundSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _soundsEnabled = prefs.getBool('user_app_sounds') ?? true;
    notifyListeners();
  }

  Future<void> setSoundsEnabled(bool value) async {
    _soundsEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('user_app_sounds', value);
    notifyListeners();
    if (value) {
      playSound('success');
    }
  }

  Future<void> updateSoundSettings(bool value) async {
    await setSoundsEnabled(value);
  }

  Future<void> playSound(String type) async {
    if (!_soundsEnabled) return;

    try {
      String assetPath;
      switch (type) {
        case 'click':
          assetPath = 'sounds/click.mp3';
          break;
        case 'success':
          assetPath = 'sounds/success.mp3';
          break;
        case 'error':
          assetPath = 'sounds/error.mp3';
          break;
        case 'notification':
          assetPath = 'sounds/notification.mp3';
          break;
        default:
          return;
      }

      // استخدام اللاعب المناسب لكل نوع صوت
      switch (type) {
        case 'click':
          await _clickPlayer.play(AssetSource(assetPath));
          break;
        case 'success':
          await _successPlayer.play(AssetSource(assetPath));
          break;
        case 'error':
          await _errorPlayer.play(AssetSource(assetPath));
          break;
        case 'notification':
          await _notifPlayer.play(AssetSource(assetPath));
          break;
      }
    } catch (e) {
      debugPrint('تحذير الصوت (طبيعي في المتصفحات قبل التفاعل): $e');
    }
  }

  void _monitorInternetConnection() {
    _isOnline = true;
    notifyListeners();
    // يمكن إضافة مراقبة فعلية للاتصال إذا أردت
  }

  void toggleOfflineModeForTesting(bool isOffline) {
    _isOnline = !isOffline;
    notifyListeners();
  }

  void _listenToNotifications(String userId) {
    _db
        .collection('notifications')
        .where('targetUserId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen((snapshot) {
      bool hadNew = _hasNewNotifications;
      _unreadNotifications =
          snapshot.docs.map((doc) => {'docId': doc.id, ...doc.data()}).toList();
      _hasNewNotifications = _unreadNotifications.isNotEmpty;

      if (_hasNewNotifications && !hadNew) {
        playSound('notification');
      }

      notifyListeners();
    });
  }

  Future<void> markNotificationsAsRead() async {
    if (_unreadNotifications.isEmpty) return;
    WriteBatch batch = _db.batch();
    for (var notif in _unreadNotifications) {
      batch.update(_db.collection('notifications').doc(notif['docId']), {'isRead': true});
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
