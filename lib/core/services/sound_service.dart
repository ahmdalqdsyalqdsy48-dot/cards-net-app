import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import '../providers/settings_provider.dart';

/// خدمة الصوت المركزية – مسؤولة عن جميع أصوات التطبيق
class SoundService {
  final AudioPlayer _player = AudioPlayer();
  final SettingsProvider _settings;
  bool _isInitialized = false;

  /// المسارات النسبية للملفات داخل assets/sounds/
  static const Map<String, String> _paths = {
    'click': 'assets/sounds/click.mp3',
    'success': 'assets/sounds/success.mp3',
    'error': 'assets/sounds/error.mp3',
    'warning': 'assets/sounds/warning.mp3',
    'tap': 'assets/sounds/tap.mp3',
    'notification': 'assets/sounds/notification.mp3',
  };

  SoundService(this._settings);

  /// تشغيل صوت حسب النوع. لا يفعل شيئاً إذا كان الصوت مكتوماً.
  Future<void> play(String type) async {
    // احترام إعداد كتم الصوت من UiProvider أو SettingsProvider
    if (!_settings.isSoundEnabled) return;

    final path = _paths[type];
    if (path == null) {
      debugPrint('SoundService: نوع صوت غير معروف -> $type');
      return;
    }

    try {
      await _player.stop();                         // إيقاف أي صوت سابق (منع تداخل)
      await _player.play(AssetSource(path));        // AssetSource لأن الملفات داخل assets/
    } catch (e) {
      debugPrint('SoundService: فشل تشغيل $type -> $e');
    }
  }

  /// إيقاف أي صوت يعمل حالياً
  Future<void> stop() async {
    await _player.stop();
  }

  /// تحرير الموارد (اختياري)
  void dispose() {
    _player.dispose();
  }
}
