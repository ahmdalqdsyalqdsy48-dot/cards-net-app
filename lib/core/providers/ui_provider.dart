import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:audioplayers/audioplayers.dart'; 
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

class UiProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final AudioPlayer _audioPlayer = AudioPlayer(); 

  bool _isOnline = true; 
  List<Map<String, dynamic>> _unreadNotifications = [];
  bool _hasNewNotifications = false;
  String _globalSearchQuery = '';
  
  bool _soundsEnabled = true;

  UiProvider(String? currentUserId) {
    _monitorInternetConnection();
    _loadSoundSettings();
    if (currentUserId != null) {
      _listenToNotifications(currentUserId);
    }
  }

  bool get isOnline => _isOnline;
  bool get hasNewNotifications => _hasNewNotifications;
  List<Map<String, dynamic>> get unreadNotifications => _unreadNotifications;
  String get globalSearchQuery => _globalSearchQuery;
  bool get isSoundsEnabled => _soundsEnabled;

  // ==========================================
  // 🎵 محرك الأصوات المطور (إصلاح جذري للويب)
  // ==========================================
  Future<void> _loadSoundSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _soundsEnabled = prefs.getBool('soundsEnabled') ?? true;
    notifyListeners();
  }

  // 👈 دالة هامة لتحديث الحالة فوراً عند ضغط الزر في الإعدادات
  Future<void> updateSoundSettings(bool value) async {
    _soundsEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('soundsEnabled', value);
    notifyListeners();
  }

  Future<void> playSound(String type) async {
    if (!_soundsEnabled) return; 

    try {
      // إيقاف أي صوت شغال حالياً للبدء فوراً (مهم للسرعة)
      await _audioPlayer.stop();

      if (type == 'click') {
        await SystemSound.play(SystemSoundType.click);
      } else if (type == 'success') {
        // رابط MP3 مستقر جداً لصوت النجاح
        await _audioPlayer.play(UrlSource('https://www.soundjay.com/buttons/sounds/button-37.mp3'));
      } else if (type == 'error') {
        // صوت تنبيه خطأ
        await _audioPlayer.play(UrlSource('https://www.soundjay.com/buttons/sounds/button-10.mp3'));
      } else if (type == 'notification') {
        // صوت إشعار احترافي
        await _audioPlayer.play(UrlSource('https://www.soundjay.com/misc/sounds/bell-ringing-05.mp3'));
      }
    } catch (e) {
      debugPrint('تنبيه: المتصفح قد يحظر الصوت قبل التفاعل الأول $e');
    }
  }

  // ==========================================
  // 🌐 إدارة الاتصال والإشعارات
  // ==========================================
  void _monitorInternetConnection() {
    _isOnline = true;
    notifyListeners();
  }

  void toggleOfflineModeForTesting(bool isOffline) {
    _isOnline = !isOffline;
    notifyListeners();
  }

  void _listenToNotifications(String userId) {
    _db.collection('notifications')
        .where('targetUserId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .orderBy('timestamp', descending: true)
        .snapshots().listen((snapshot) {
      
      bool hadNew = _hasNewNotifications;
      _unreadNotifications = snapshot.docs.map((doc) => {'docId': doc.id, ...doc.data()}).toList();
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
    try { await batch.commit(); } catch (e) { debugPrint('خطأ: $e'); }
  }

  void updateSearchQuery(String query) {
    _globalSearchQuery = query;
    notifyListeners();
  }
}
