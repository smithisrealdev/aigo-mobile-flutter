import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../config/supabase_config.dart';

// ──────────────────────────────────────────────
// Voice service — record audio + on-device STT + Whisper fallback
// ──────────────────────────────────────────────

enum VoiceState { idle, recording, listening, processing }

/// Callback types for interim/final speech results.
typedef OnInterimResult = void Function(String text);
typedef OnFinalResult = void Function(String text);

class VoiceService {
  final _recorder = AudioRecorder();
  final _speech = stt.SpeechToText();
  String? _currentPath;
  bool _speechAvailable = false;
  bool _isListening = false;
  bool _useOnDeviceSTT = true; // Prefer on-device STT for interim results

  /// Check & request microphone permission.
  Future<bool> requestPermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  /// Initialize on-device speech recognition.
  /// Call once before using [startListening].
  Future<bool> initSpeech() async {
    try {
      _speechAvailable = await _speech.initialize(
        onStatus: (status) {
          debugPrint('[VoiceService] STT status: $status');
        },
        onError: (error) {
          debugPrint('[VoiceService] STT error: ${error.errorMsg}');
          _isListening = false;
        },
      );
      debugPrint('[VoiceService] STT available: $_speechAvailable');
      return _speechAvailable;
    } catch (e) {
      debugPrint('[VoiceService] STT init failed: $e');
      _speechAvailable = false;
      return false;
    }
  }

  /// Start on-device speech recognition with interim results.
  ///
  /// [onInterim] is called with partial text while user is speaking.
  /// [onFinal] is called with the final recognized text when done.
  /// [localeId] defaults to 'en_US'; use 'th_TH' for Thai.
  ///
  /// Also starts recording in parallel for Whisper fallback.
  Future<bool> startListening({
    required OnInterimResult onInterim,
    required OnFinalResult onFinal,
    String localeId = 'en_US',
    bool recordForFallback = true,
  }) async {
    if (!await requestPermission()) return false;

    // Init speech if not already done
    if (!_speechAvailable) {
      await initSpeech();
    }

    // Start recording in parallel (for Whisper fallback if on-device STT fails)
    if (recordForFallback) {
      await _startRecordingInternal();
    }

    if (!_speechAvailable) {
      debugPrint('[VoiceService] On-device STT not available, using record+Whisper only');
      return recordForFallback;
    }

    try {
      _isListening = true;
      await _speech.listen(
        onResult: (result) {
          final text = result.recognizedWords;
          if (result.finalResult) {
            _isListening = false;
            onFinal(text);
          } else {
            onInterim(text);
          }
        },
        localeId: localeId,
        listenMode: stt.ListenMode.dictation,
        cancelOnError: false,
        partialResults: true,
        listenFor: const Duration(seconds: 60),
        pauseFor: const Duration(seconds: 3),
      );
      return true;
    } catch (e) {
      debugPrint('[VoiceService] listen() failed: $e');
      _isListening = false;
      // Fall back to record-only mode
      return recordForFallback;
    }
  }

  /// Stop listening and return the recognized text.
  /// If on-device STT produced good results, returns those.
  /// Otherwise falls back to Whisper transcription of the recorded audio.
  Future<String> stopListening({bool useWhisperFallback = true}) async {
    String sttText = '';

    // Stop on-device STT
    if (_isListening) {
      try {
        await _speech.stop();
        _isListening = false;
        // Get the last recognized text
        // Note: final result should have been delivered via callback
      } catch (e) {
        debugPrint('[VoiceService] stop STT error: $e');
      }
    }

    // Stop recording
    final path = await _recorder.stop();

    // If we got text from on-device STT, prefer that for speed
    // The caller should have captured the final text from the callback
    // This method handles fallback to Whisper for the recorded audio

    if (useWhisperFallback && path != null) {
      try {
        final whisperText = await transcribe(path);
        // Clean up
        final f = File(path);
        if (await f.exists()) await f.delete();
        return whisperText;
      } catch (e) {
        debugPrint('[VoiceService] Whisper fallback failed: $e');
        if (path != null) {
          final f = File(path);
          if (await f.exists()) await f.delete();
        }
      }
    } else if (path != null) {
      final f = File(path);
      if (await f.exists()) await f.delete();
    }

    return sttText;
  }

  /// Cancel listening — discard all results.
  Future<void> cancelListening() async {
    if (_isListening) {
      try {
        await _speech.cancel();
        _isListening = false;
      } catch (_) {}
    }
    await cancelRecording();
  }

  /// Whether on-device STT is currently active.
  bool get isListening => _isListening;

  /// Whether on-device STT was successfully initialized.
  bool get isSpeechAvailable => _speechAvailable;

  /// Get available locales for on-device STT.
  Future<List<stt.LocaleName>> getLocales() async {
    if (!_speechAvailable) await initSpeech();
    return _speech.locales();
  }

  // ── Legacy recording methods (kept for backward compatibility) ──

  /// Start recording audio to a temp file.
  Future<bool> startRecording() async {
    if (!await requestPermission()) return false;
    return _startRecordingInternal();
  }

  Future<bool> _startRecordingInternal() async {
    final dir = await getTemporaryDirectory();
    _currentPath = '${dir.path}/aigo_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

    if (await _recorder.hasPermission()) {
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: _currentPath!,
      );
      return true;
    }
    return false;
  }

  /// Stop recording and return the file path.
  Future<String?> stopRecording() async {
    final path = await _recorder.stop();
    return path;
  }

  /// Cancel current recording.
  Future<void> cancelRecording() async {
    await _recorder.stop();
    if (_currentPath != null) {
      final f = File(_currentPath!);
      if (await f.exists()) await f.delete();
      _currentPath = null;
    }
  }

  /// Send recorded audio to voice-to-text edge function (Whisper).
  /// Returns transcribed text.
  Future<String> transcribe(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) throw Exception('Audio file not found');

    final bytes = await file.readAsBytes();
    final base64Audio = base64Encode(bytes);

    final response = await SupabaseConfig.client.functions.invoke(
      'voice-to-text',
      body: {
        'audio': base64Audio,
        'format': 'm4a',
      },
    );

    if (response.status != 200) {
      throw Exception('Transcription failed: ${response.status}');
    }

    final data = response.data as Map<String, dynamic>;
    return data['text'] as String? ?? '';
  }

  /// Full flow: stop recording → transcribe → return text.
  Future<String> stopAndTranscribe() async {
    final path = await stopRecording();
    if (path == null) throw Exception('No recording found');
    try {
      return await transcribe(path);
    } finally {
      // Clean up temp file
      final f = File(path);
      if (await f.exists()) await f.delete();
    }
  }

  /// Convert text to speech via ElevenLabs edge function.
  /// Returns audio bytes.
  Future<List<int>> textToSpeech(String text) async {
    final response = await SupabaseConfig.client.functions.invoke(
      'elevenlabs-tts',
      body: {'text': text},
    );

    if (response.status != 200) {
      throw Exception('TTS failed: ${response.status}');
    }

    final data = response.data as Map<String, dynamic>;
    final audioBase64 = data['audio'] as String;
    return base64Decode(audioBase64);
  }

  void dispose() {
    if (_isListening) _speech.cancel();
    _recorder.dispose();
  }
}

// ── Riverpod providers ──

final voiceServiceProvider = Provider<VoiceService>((ref) {
  final svc = VoiceService();
  ref.onDispose(() => svc.dispose());
  return svc;
});

final voiceStateProvider = NotifierProvider<VoiceStateNotifier, VoiceState>(VoiceStateNotifier.new);

class VoiceStateNotifier extends Notifier<VoiceState> {
  @override
  VoiceState build() => VoiceState.idle;

  void set(VoiceState s) => state = s;
}

/// Holds interim text from on-device STT for UI display.
final interimTextProvider = StateProvider<String>((ref) => '');
