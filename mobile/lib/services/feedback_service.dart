import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

/// Central service for haptic + audio feedback throughout the app.
class FeedbackService {
  FeedbackService._();

  static final AudioPlayer _player = AudioPlayer();
  static bool _playerReady = false;

  /// Call once at app startup to warm up the audio engine.
  static Future<void> init() async {
    try {
      await _player.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            isSpeakerphoneOn: false,
            stayAwake: false,
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.notificationRingtone,
            audioFocus: AndroidAudioFocus.gainTransientMayDuck,
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.ambient,
            options: {AVAudioSessionOptions.mixWithOthers},
          ),
        ),
      );
      _playerReady = true;
    } catch (_) {
      // Silently continue — audio context unavailable
    }
  }

  /// Light tap — for list items, chips, navigation.
  static void tap() {
    HapticFeedback.vibrate();
  }

  /// Medium impact — for primary action buttons.
  static void buttonPress() {
    HapticFeedback.vibrate();
  }

  /// Coin ding + haptic rolling pattern — for new expense saved.
  static Future<void> newExpense() async {
    _playHapticPattern();
    await _playSound();
  }

  /// Double light pulse — for general success confirmation.
  static Future<void> success() async {
    HapticFeedback.vibrate();
    await Future<void>.delayed(const Duration(milliseconds: 120));
    HapticFeedback.vibrate();
  }

  /// Heavy impact — for errors.
  static void error() {
    HapticFeedback.vibrate();
  }

  // ---------------------------------------------------------------------------

  static void _playHapticPattern() async {
    for (int i = 0; i < 4; i++) {
      HapticFeedback.vibrate();
      await Future<void>.delayed(const Duration(milliseconds: 60));
    }
    HapticFeedback.vibrate();
  }

  static Future<void> _playSound() async {
    try {
      if (!_playerReady) await init();
      await _player.play(AssetSource('sounds/coin.wav'));
    } catch (_) {
      // Silently ignore — e.g. silent mode or audio unavailable
    }
  }
}
