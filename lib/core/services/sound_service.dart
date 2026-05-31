import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import '../providers/settings_provider.dart';

class SoundService {
  final SettingsProvider _settings;

  // عدة مشغلات لكل نوع لمنع تداخل الأصوات
  final List<AudioPlayer> _clickPlayers = [];
  final List<AudioPlayer> _successPlayers = [];
  final List<AudioPlayer> _errorPlayers = [];
  final List<AudioPlayer> _warningPlayers = [];
  final List<AudioPlayer> _tapPlayers = [];
  final List<AudioPlayer> _notifPlayers = [];

  int _clickIdx = 0, _succIdx = 0, _errIdx = 0, _warnIdx = 0, _tapIdx = 0, _notifIdx = 0;

  SoundService(this._settings) {
    // 3 مشغلات للأصوات المتكررة جداً (النقر)
    for (int i = 0; i < 3; i++) {
      _clickPlayers.add(AudioPlayer());
    }
    // مشغلان لكل نوع آخر
    for (int i = 0; i < 2; i++) {
      _successPlayers.add(AudioPlayer());
      _errorPlayers.add(AudioPlayer());
      _warningPlayers.add(AudioPlayer());
      _tapPlayers.add(AudioPlayer());
      _notifPlayers.add(AudioPlayer());
    }
  }

  /// تشغيل صوت حسب النوع. لا يفعل شيئاً إذا كان الصوت معطلاً في الإعدادات.
  Future<void> play(String type) async {
    if (!_settings.isSoundEnabled) return;

    AudioPlayer player;
    double volume;
    String fileName;

    switch (type) {
      case 'click':
        player = _clickPlayers[_clickIdx++ % _clickPlayers.length];
        volume = 0.5;
        fileName = 'click.mp3';
        break;
      case 'success':
        player = _successPlayers[_succIdx++ % _successPlayers.length];
        volume = 1.0;
        fileName = 'success.mp3';
        break;
      case 'error':
        player = _errorPlayers[_errIdx++ % _errorPlayers.length];
        volume = 0.8;
        fileName = 'error.mp3';
        break;
      case 'warning':
        player = _warningPlayers[_warnIdx++ % _warningPlayers.length];
        volume = 0.9;
        fileName = 'warning.mp3';
        break;
      case 'tap':
        player = _tapPlayers[_tapIdx++ % _tapPlayers.length];
        volume = 0.3;
        fileName = 'tap.mp3';
        break;
      case 'notification':
        player = _notifPlayers[_notifIdx++ % _notifPlayers.length];
        volume = 1.0;
        fileName = 'notification.mp3';
        break;
      default:
        return; // نوع غير معروف، لا يفعل شيئاً
    }

    try {
      // إيقاف المشغل أولاً (ضروري للويب)، ثم تعيين المصدر وتشغيله
      await player.stop();
      await player.setSource(AssetSource('sounds/$fileName'));
      await player.play(AssetSource('sounds/$fileName'), volume: volume);
    } catch (e) {
      debugPrint('SoundService error ($type): $e');
    }
  }

  /// تنظيف جميع المشغلات عند عدم الحاجة للخدمة
  void dispose() {
    for (final list in [
      _clickPlayers,
      _successPlayers,
      _errorPlayers,
      _warningPlayers,
      _tapPlayers,
      _notifPlayers
    ]) {
      for (final p in list) {
        p.dispose();
      }
    }
  }
}
