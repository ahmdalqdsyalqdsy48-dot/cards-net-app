import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:audioplayers/audioplayers.dart'; 
import 'package:shared_preferences/shared_preferences.dart';

class UiProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  
  // مشغلات منفصلة لكل نوع صوت حتى لا تقطع بعضها في الويب
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
  // 🎵 محرك الأصوات الديناميكي (الأصوات المحلية 100%)
  // ==========================================
  Future<void> _loadSoundSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _soundsEnabled = prefs.getBool('soundsEnabled') ?? true;
    notifyListeners();
  }

  Future<void> updateSoundSettings(bool value) async {
    _soundsEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('soundsEnabled', value);
    notifyListeners();
    // تجربة الصوت فوراً عند التفعيل للتأكد من عمله
    if (value) playSound('success'); 
  }

  Future<void> playSound(String type) async {
    if (!_soundsEnabled) return; 

    try {
      // 👈 تم التعديل هنا: استخدام AssetSource ليقرأ الملفات من مشروعك مباشرة
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
