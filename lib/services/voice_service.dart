import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import '../config/supabase_config.dart';

// ──────────────────────────────────────────────
// Voice service — record audio + send to edge function
// ──────────────────────────────────────────────

enum VoiceState { idle, recording, processing }

class VoiceService {
  final _recorder = AudioRecorder();
  String? _currentPath;

  /// Check & request microphone permission.
  Future<bool> requestPermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  /// Start recording audio to a temp file.
  Future<bool> startRecording() async {
    if (!await requestPermission()) return false;

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
