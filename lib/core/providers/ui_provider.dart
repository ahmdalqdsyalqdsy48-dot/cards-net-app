import 'package:flutter/material.dart';
import '../services/sound_service.dart';

class UiProvider extends ChangeNotifier {
  final SoundService? _soundService;

  bool _isOnline = true;
  String _globalSearchQuery = '';

  UiProvider({SoundService? soundService}) : _soundService = soundService;

  // ---------- Getters ----------
  bool get isOnline => _isOnline;
  String get globalSearchQuery => _globalSearchQuery;

  // ---------- حالة الاتصال ----------
  /// تعيين حالة الاتصال بالإنترنت مباشرة للاستخدام الإنتاجي.
  void setOnlineStatus(bool online) {
    if (_isOnline != online) {
      _isOnline = online;
      notifyListeners();
    }
  }

  // ---------- البحث العالمي ----------
  /// تحديث عبارة البحث العامة في التطبيق.
  void updateSearchQuery(String query) {
    if (_globalSearchQuery != query) {
      _globalSearchQuery = query;
      notifyListeners();
    }
  }

  // ---------- الصوت ----------
  /// تشغيل مؤثر صوتي باستخدام [SoundService] إن تم توفيره.
  void playSound(String type) {
    _soundService?.play(type);
  }
}
