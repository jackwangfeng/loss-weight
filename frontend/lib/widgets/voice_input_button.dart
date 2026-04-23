import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../l10n/generated/app_localizations.dart';
import '../services/ai_service.dart';

/// Cloud-based voice input. Records mic audio locally (`flutter_sound`)
/// then POSTs to the backend for Gemini transcription (and optionally
/// structured profile parsing in the same round-trip).
///
/// Two modes:
///   • Default (`targetController` only): call /v1/ai/transcribe — plain text
///     lands in the controller; caller's `onFinalized` fires once done.
///   • Profile mode (`onProfileParsed` provided): call
///     /v1/ai/transcribe-and-parse-profile — structured fields go to the
///     callback; transcript still fills the controller for user verification.
///
/// Why cloud: native STT (SFSpeechRecognizer / Android SpeechRecognizer)
/// is weak on CJK + mixed language + digits/units. Gemini 2.5 Flash audio
/// is ~$0.015/min and far more accurate for those cases.
class VoiceInputButton extends StatefulWidget {
  final TextEditingController targetController;
  final VoidCallback? onFinalized;
  final void Function(Map<String, dynamic> parsed)? onProfileParsed;
  final String localeId; // "zh-CN" / "en-US"

  const VoiceInputButton({
    Key? key,
    required this.targetController,
    this.onFinalized,
    this.onProfileParsed,
    this.localeId = 'en-US',
  }) : super(key: key);

  @override
  State<VoiceInputButton> createState() => _VoiceInputButtonState();
}

enum _VoiceState { idle, recording, uploading }

class _VoiceInputButtonState extends State<VoiceInputButton>
    with SingleTickerProviderStateMixin {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final AIService _ai = AIService();
  _VoiceState _state = _VoiceState.idle;
  String? _currentPath;
  bool _opened = false;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    if (_opened) {
      _recorder.closeRecorder();
    }
    super.dispose();
  }

  Future<void> _ensureOpen() async {
    if (_opened) return;
    await _recorder.openRecorder();
    _opened = true;
  }

  Future<void> _toggle() async {
    if (_state == _VoiceState.recording) {
      await _stopAndUpload();
    } else if (_state == _VoiceState.idle) {
      await _start();
    }
  }

  Future<void> _start() async {
    final l10n = AppLocalizations.of(context);
    try {
      // Android runtime permission for mic. iOS picks up NSMicrophoneUsageDescription
      // via flutter_sound; but permission_handler works on iOS too and gives
      // a consistent API.
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.voicePermissionDenied)),
          );
        }
        return;
      }
      await _ensureOpen();
      final tmp = await getTemporaryDirectory();
      _currentPath =
          '${tmp.path}/rec_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.startRecorder(
        toFile: _currentPath!,
        codec: Codec.aacMP4,     // .m4a container, Gemini audio/mp4 happy
        sampleRate: 16000,       // 16 kHz is plenty for speech, small payload
        numChannels: 1,
      );
      if (mounted) setState(() => _state = _VoiceState.recording);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('录音失败: $e')),
        );
      }
    }
  }

  Future<void> _stopAndUpload() async {
    setState(() => _state = _VoiceState.uploading);
    try {
      final path = await _recorder.stopRecorder() ?? _currentPath;
      if (path == null) {
        _reset();
        return;
      }
      final bytes = await File(path).readAsBytes();
      if (bytes.isEmpty) {
        _reset();
        return;
      }
      final localeShort = widget.localeId.split('-').first; // en-US → en

      if (widget.onProfileParsed != null) {
        final res = await _ai.transcribeAndParseProfile(
          audioBytes: bytes,
          mimeType: 'audio/mp4',
          locale: localeShort,
        );
        final transcript = (res['transcript'] as String?) ?? '';
        if (transcript.isNotEmpty) {
          widget.targetController.text = transcript;
        }
        widget.onProfileParsed!(res);
      } else {
        final res = await _ai.transcribe(
          audioBytes: bytes,
          mimeType: 'audio/mp4',
          locale: localeShort,
        );
        final text = (res['text'] as String?) ?? '';
        widget.targetController.text = text;
        widget.onFinalized?.call();
      }
      try {
        await File(path).delete();
      } catch (_) {}
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('语音识别失败: $e')),
        );
      }
    } finally {
      _reset();
    }
  }

  void _reset() {
    if (mounted) setState(() => _state = _VoiceState.idle);
    _currentPath = null;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget icon;
    VoidCallback? onPressed = _toggle;
    switch (_state) {
      case _VoiceState.idle:
        icon = Icon(Icons.mic, color: scheme.primary);
        break;
      case _VoiceState.recording:
        icon = AnimatedBuilder(
          animation: _pulse,
          builder: (_, __) => Icon(
            Icons.stop_circle,
            color: Color.lerp(scheme.primary, scheme.error, _pulse.value),
          ),
        );
        break;
      case _VoiceState.uploading:
        icon = const SizedBox(
          width: 20, height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
        onPressed = null;
        break;
    }
    return IconButton(icon: icon, onPressed: onPressed);
  }
}
