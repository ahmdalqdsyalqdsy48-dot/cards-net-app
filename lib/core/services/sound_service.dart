import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import '../providers/settings_provider.dart';

/// خدمة الصوت المركزية – تحاكي تماماً سلوك النظام القديم مع دعم الكتم
class SoundService {
  final SettingsProvider _settings;

  // عدة مشغلات لكل نوع (مثل النظام القديم)
  final List<AudioPlayer> _clickPlayers = [];
  final List<AudioPlayer> _successPlayers = [];
  final List<AudioPlayer> _errorPlayers = [];
  final List<AudioPlayer> _warningPlayers = [];
  final List<AudioPlayer> _tapPlayers = [];
  final List<AudioPlayer> _notifPlayers = [];

  int _clickIndex = 0;
  int _successIndex = 0;
  int _errorIndex = 0;
  int _warningIndex = 0;
  int _tapIndex = 0;
  int _notifIndex = 0;

  SoundService(this._settings) {
    // إعداد 3 مشغلات للنقر، ومشغلين اثنين لبقية الأصوات
    for (int i = 0; i < 3; i++) {
      _clickPlayers.add(AudioPlayer()..setSource(AssetSource('sounds/click.mp3')));
    }
    for (int i = 0; i < 2; i++) {
      _successPlayers.add(AudioPlayer()..setSource(AssetSource('sounds/success.mp3')));
      _errorPlayers.add(AudioPlayer()..setSource(AssetSource('sounds/error.mp3')));
      _warningPlayers.add(AudioPlayer()..setSource(AssetSource('sounds/warning.mp3')));
      _tapPlayers.add(AudioPlayer()..setSource(AssetSource('sounds/tap.mp3')));
      _notifPlayers.add(AudioPlayer()..setSource(AssetSource('sounds/notification.mp3')));
    }
  }

  /// تشغيل صوت حسب النوع
  Future<void> play(String type) async {
    if (!_settings.isSoundEnabled) return;

    try {
      switch (type) {
        case 'click':
          final player = _clickPlayers[_clickIndex % _clickPlayers.length];
          _clickIndex++;
          await player.stop();
          await player.play(AssetSource('sounds/click.mp3'), volume: 0.5);
          break;
        case 'success':
          final player = _successPlayers[_successIndex % _successPlayers.length];
          _successIndex++;
          await player.stop();
          await player.play(AssetSource('sounds/success.mp3'), volume: 1.0);
          break;
        case 'error':
          final player = _errorPlayers[_errorIndex % _errorPlayers.length];
          _errorIndex++;
          await player.stop();
          await player.play(AssetSource('sounds/error.mp3'), volume: 0.8);
          break;
        case 'warning':
          final player = _warningPlayers[_warningIndex % _warningPlayers.length];
          _warningIndex++;
          await player.stop();
          await player.play(AssetSource('sounds/warning.mp3'), volume: 0.9);
          break;
        case 'tap':
          final player = _tapPlayers[_tapIndex % _tapPlayers.length];
          _tapIndex++;
          await player.stop();
          await player.play(AssetSource('sounds/tap.mp3'), volume: 0.3);
          break;
        case 'notification':
          final player = _notifPlayers[_notifIndex % _notifPlayers.length];
          _notifIndex++;
          await player.stop();
          await player.play(AssetSource('sounds/notification.mp3'), volume: 1.0);
          break;
      }
    } catch (e) {
      debugPrint('SoundService error: $e');
    }
  }

  /// إيقاف جميع المشغلات
  Future<void> stopAll() async {
    for (final p in [
      ..._clickPlayers,
      ..._successPlayers,
      ..._errorPlayers,
      ..._warningPlayers,
      ..._tapPlayers,
      ..._notifPlayers
    ]) {
      await p.stop();
    }
  }

  /// تحرير الموارد
  void dispose() {
    for (final p in [
      ..._clickPlayers,
      ..._successPlayers,
      ..._errorPlayers,
      ..._warningPlayers,
      ..._tapPlayers,
      ..._notifPlayers
    ]) {
      p.dispose();
    }
  }
}
