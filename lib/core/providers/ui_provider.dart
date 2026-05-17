import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UiProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 🔊 تجمعات صوتية بدلاً من مشغلات مفردة
  late final AudioPool _clickPool;
  late final AudioPool _successPool;
  late final AudioPool _errorPool;
  late final AudioPool _notifPool;

  bool _isOnline = true;
  List<Map<String, dynamic>> _unreadNotifications = [];
  bool _hasNewNotifications = false;
  String _globalSearchQuery = '';

  bool _soundsEnabled = true;
  String? _currentUserPhone;

  UiProvider(String? currentUserId) {
    _currentUserPhone = currentUserId;
    // إعداد المجمعات الصوتية (تدعم عدة مشغلات متزامنة)
    _clickPool = AudioPool.fromAsset(
      'sounds/click.mp3',
      maxPlayers: 3,   // يسمح بـ 3 نقرات متداخلة
    );
    _successPool = AudioPool.fromAsset(
      'sounds/success.mp3',
      maxPlayers: 2,
    );
    _errorPool = AudioPool.fromAsset(
      'sounds/error.mp3',
      maxPlayers: 2,
    );
    _notifPool = AudioPool.fromAsset(
      'sounds/notification.mp3',
      maxPlayers: 2,
    );

    _monitorInternetConnection();
    if (currentUserId != null) {
      _listenToNotifications(currentUserId);
    }
    _loadSoundSetting();
  }

  bool get isOnline => _isOnline;
  bool get hasNewNotifications => _hasNewNotifications;
  List<Map<String, dynamic>> get unreadNotifications => _unreadNotifications;
  String get globalSearchQuery => _globalSearchQuery;
  bool get isSoundsEnabled => _soundsEnabled;

  /// تحميل تفضيل الصوت من الذاكرة
  Future<void> _loadSoundSetting() async {
    final prefs = await SharedPreferences.getInstance();
    _soundsEnabled = prefs.getBool('global_sounds_enabled') ?? true;
    notifyListeners();
  }

  /// تحديث إعداد الصوت وحفظه
  Future<void> updateSoundSettings(bool value) async {
    if (_soundsEnabled == value) return;
    _soundsEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('global_sounds_enabled', value);
    notifyListeners();
    if (value) playSound('success');
  }

  /// 🔊 تشغيل الأصوات (مع احترام كتم الصوت)
  Future<void> playSound(String type) async {
    if (!_soundsEnabled) return;
    try {
      switch (type) {
        case 'click':
          await _clickPool.start(volume: 0.5);
          break;
        case 'success':
          await _successPool.start(volume: 1.0);
          break;
        case 'error':
          await _errorPool.start(volume: 0.8);
          break;
        case 'notification':
          await _notifPool.start(volume: 1.0);
          break;
      }
    } catch (e) {
      debugPrint('Sound error (usually browser policy): $e');
    }
  }

  void _monitorInternetConnection() {
    // في تطبيق حقيقي يمكن استخدام connectivity_plus
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
