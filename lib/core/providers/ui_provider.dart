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
    _initAudioPlayers();
    if (currentUserId != null) {
      _listenToNotifications(currentUserId);
    }
  }

  bool get isOnline => _isOnline;
  bool get hasNewNotifications => _hasNewNotifications;
  List<Map<String, dynamic>> get unreadNotifications => _unreadNotifications;
  String get globalSearchQuery => _globalSearchQuery;
  bool get isSoundsEnabled => _soundsEnabled;

  void _initAudioPlayers() {
    final audioContext = AudioContext(
      iOS: AudioContextIOS(
        category: AVAudioSessionCategory.playback,
        options: {AVAudioSessionOptions.mixWithOthers}, // ✅ Set بدلاً من List
      ),
      android: AudioContextAndroid(
        audioFocus: AndroidAudioFocus.gainTransientMayDuck,
        contentType: AndroidContentType.music,
        usageType: AndroidUsageType.game,
      ),
    );
    _clickPlayer.setAudioContext(audioContext);
    _successPlayer.setAudioContext(audioContext);
    _errorPlayer.setAudioContext(audioContext);
    _notifPlayer.setAudioContext(audioContext);
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

      final source = AssetSource(assetPath);
      switch (type) {
        case 'click':
          await _clickPlayer.play(source);
          break;
        case 'success':
          await _successPlayer.play(source);
          break;
        case 'error':
          await _errorPlayer.play(source);
          break;
        case 'notification':
          await _notifPlayer.play(source);
          break;
      }
    } catch (e) {
      debugPrint('تحذير الصوت: $e');
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
