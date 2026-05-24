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
  void toggleOfflineModeForTesting(bool isOffline) {
    _isOnline = !isOffline;
    notifyListeners();
  }

  // ---------- البحث ----------
  void updateSearchQuery(String query) {
    _globalSearchQuery = query;
    notifyListeners();
  }

  // ---------- صوت (جسر مؤقت للشاشات القديمة) ----------
  /// يُشغّل صوتاً باستخدام [SoundService] إن وُجد.
  /// الشاشات القديمة التي تستدعي uiProvider.playSound(...) ستستمر بالعمل.
  void playSound(String type) {
    _soundService?.play(type);
  }
}
