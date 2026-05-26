import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import '../providers/settings_provider.dart';

class SoundService {
  final SettingsProvider _settings;

  // عدة مشغلات لكل نوع (مثل النظام القديم الناجح)
  final List<AudioPlayer> _clickPlayers = [];
  final List<AudioPlayer> _successPlayers = [];
  final List<AudioPlayer> _errorPlayers = [];
  final List<AudioPlayer> _warningPlayers = [];
  final List<AudioPlayer> _tapPlayers = [];
  final List<AudioPlayer> _notifPlayers = [];

  int _clickIdx = 0, _succIdx = 0, _errIdx = 0, _warnIdx = 0, _tapIdx = 0, _notifIdx = 0;

  SoundService(this._settings) {
    _initPlayers();
  }

  void _initPlayers() {
    // 3 مشغلات للنقر، 2 للبقية
    for (int i = 0; i < 3; i++) {
      _clickPlayers.add(AudioPlayer());
    }
    for (int i = 0; i < 2; i++) {
      _successPlayers.add(AudioPlayer());
      _errorPlayers.add(AudioPlayer());
      _warningPlayers.add(AudioPlayer());
      _tapPlayers.add(AudioPlayer());
      _notifPlayers.add(AudioPlayer());
    }
    _preloadAll();
  }

  Future<void> _preloadAll() async {
    final sources = {
      _clickPlayers: 'sounds/click.mp3',
      _successPlayers: 'sounds/success.mp3',
      _errorPlayers: 'sounds/error.mp3',
      _warningPlayers: 'sounds/warning.mp3',
      _tapPlayers: 'sounds/tap.mp3',
      _notifPlayers: 'sounds/notification.mp3',
    };
    for (final entry in sources.entries) {
      for (final player in entry.key) {
        await player.setSource(AssetSource(entry.value));
      }
    }
  }

  Future<void> play(String type) async {
    if (!_settings.isSoundEnabled) return;

    List<AudioPlayer>? players;
    int? index;
    double volume;
    String? assetPath;

    switch (type) {
      case 'click':
        players = _clickPlayers;
        index = _clickIdx++ % players.length;
        volume = 0.5;
        assetPath = 'sounds/click.mp3';
        break;
      case 'success':
        players = _successPlayers;
        index = _succIdx++ % players.length;
        volume = 1.0;
        assetPath = 'sounds/success.mp3';
        break;
      case 'error':
        players = _errorPlayers;
        index = _errIdx++ % players.length;
        volume = 0.8;
        assetPath = 'sounds/error.mp3';
        break;
      case 'warning':
        players = _warningPlayers;
        index = _warnIdx++ % players.length;
        volume = 0.9;
        assetPath = 'sounds/warning.mp3';
        break;
      case 'tap':
        players = _tapPlayers;
        index = _tapIdx++ % players.length;
        volume = 0.3;
        assetPath = 'sounds/tap.mp3';
        break;
      case 'notification':
        players = _notifPlayers;
        index = _notifIdx++ % players.length;
        volume = 1.0;
        assetPath = 'sounds/notification.mp3';
        break;
      default:
        return;
    }

    final player = players.elementAt(index);
    try {
      await player.stop();
      await player.play(AssetSource(assetPath!), volume: volume);
    } catch (e) {
      debugPrint('SoundService error ($type): $e');
    }
  }

  void dispose() {
    for (final list in [_clickPlayers, _successPlayers, _errorPlayers, _warningPlayers, _tapPlayers, _notifPlayers]) {
      for (final p in list) p.dispose();
    }
  }
}
