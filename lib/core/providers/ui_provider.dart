import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:audioplayers/audioplayers.dart'; // 👈 استدعاء مكتبة الصوت
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart'; // 👈 لاستخدام أصوات نقرات النظام الافتراضية

class UiProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final AudioPlayer _audioPlayer = AudioPlayer(); // 👈 إنشاء مشغل الصوت

  bool _isOnline = true; 
  List<Map<String, dynamic>> _unreadNotifications = [];
  bool _hasNewNotifications = false;
  String _globalSearchQuery = '';
  
  bool _soundsEnabled = true; // 👈 حالة الأصوات

  UiProvider(String? currentUserId) {
    _monitorInternetConnection();
    _loadSoundSettings(); // 👈 جلب إعدادات الصوت عند بدء التشغيل
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
  // 🎵 محرك الأصوات الديناميكي
  // ==========================================
  Future<void> _loadSoundSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _soundsEnabled = prefs.getBool('soundsEnabled') ?? true;
    notifyListeners();
  }

  // يمكن استدعاء هذه الدالة من أي مكان في التطبيق لتشغيل الأصوات
  Future<void> playSound(String type) async {
    // التحقق أولاً: هل سمح المالك بتشغيل الأصوات؟
    if (!_soundsEnabled) return; 

    try {
      if (type == 'click') {
        // صوت نقرة خفيف من نظام الهاتف/المتصفح
        SystemSound.play(SystemSoundType.click);
      } else if (type == 'success') {
        // صوت نجاح عملية (تم الربط بأصوات جوجل الرسمية لتعمل مباشرة)
        await _audioPlayer.play(UrlSource('https://actions.google.com/sounds/v1/ui/succeed_bright.ogg'));
      } else if (type == 'error') {
        // صوت خطأ
        await _audioPlayer.play(UrlSource('https://actions.google.com/sounds/v1/alarms/error_beep.ogg'));
      } else if (type == 'notification') {
        // صوت إشعار جديد
        await _audioPlayer.play(UrlSource('https://actions.google.com/sounds/v1/alarms/message_alerts.ogg'));
      }
    } catch (e) {
      debugPrint('تعذر تشغيل الصوت: $e');
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

      // 👈 تشغيل صوت الإشعار فوراً إذا وصل إشعار جديد أثناء فتح التطبيق
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
