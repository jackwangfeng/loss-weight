import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../l10n/generated/app_localizations.dart';
import '../services/ai_service.dart';

/// Cloud voice input with live UI feedback. Recording pulses + shows elapsed
/// time; uploading shows spinner + "识别中…" so the user knows the app is
/// alive during the 1-2s transcription wait (Deepgram nova-2/3).
///
/// Modes:
///   • Default (`targetController` only): call /v1/ai/transcribe — plain text
///     lands in the controller; caller's `onFinalized` fires once done.
///   • Profile mode (`onProfileParsed` provided): call
///     /v1/ai/transcribe-and-parse-profile — structured fields go to the
///     callback; transcript still fills the controller for user verification.
class VoiceInputButton extends StatefulWidget {
  final TextEditingController targetController;
  final VoidCallback? onFinalized;
  final void Function(Map<String, dynamic> parsed)? onProfileParsed;
  final String localeId;

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
  DateTime? _recordStart;
  Timer? _tickTimer;
  int _tickCounter = 0; // drives MM:SS refresh during recording + "…" during upload
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
    _tickTimer?.cancel();
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
        codec: Codec.aacMP4,
        sampleRate: 16000,
        numChannels: 1,
      );
      _recordStart = DateTime.now();
      _tickCounter = 0;
      _tickTimer?.cancel();
      _tickTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
        if (!mounted) return;
        setState(() => _tickCounter++);
      });
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
    _tickTimer?.cancel();
    setState(() {
      _state = _VoiceState.uploading;
      _tickCounter = 0;
    });
    // Dots animation tick during upload so the UI doesn't freeze-feel.
    _tickTimer = Timer.periodic(const Duration(milliseconds: 400), (_) {
      if (!mounted) return;
      setState(() => _tickCounter++);
    });
    try {
      final path = await _recorder.stopRecorder() ?? _currentPath;
      if (_opened) {
        try {
          await _recorder.closeRecorder();
        } catch (_) {}
        _opened = false;
      }
      if (path == null) {
        _reset();
        return;
      }
      final bytes = await File(path).readAsBytes();
      if (bytes.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('没录到声音，再试一次')),
          );
        }
        _reset();
        return;
      }
      final localeShort = widget.localeId.split('-').first;

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
        if (text.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('没听清，再说一遍')),
            );
          }
        } else {
          widget.targetController.text = text;
          widget.onFinalized?.call();
        }
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
    _tickTimer?.cancel();
    _recordStart = null;
    if (mounted) setState(() => _state = _VoiceState.idle);
    _currentPath = null;
  }

  String _elapsedStr() {
    final start = _recordStart;
    if (start == null) return '0:00';
    final d = DateTime.now().difference(start);
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '${m}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedSize(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      child: _buildCurrent(scheme),
    );
  }

  Widget _buildCurrent(ColorScheme scheme) {
    switch (_state) {
      case _VoiceState.idle:
        return IconButton(
          key: const ValueKey('idle'),
          icon: Icon(Icons.mic, color: scheme.primary),
          onPressed: _toggle,
        );
      case _VoiceState.recording:
        return InkWell(
          key: const ValueKey('rec'),
          borderRadius: BorderRadius.circular(20),
          onTap: _toggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: _pulse,
                  builder: (_, __) => Container(
                    width: 10, height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: scheme.error
                          .withValues(alpha: 0.5 + _pulse.value * 0.5),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _elapsedStr(),
                  style: TextStyle(
                    color: scheme.error,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 6),
                Icon(Icons.stop_circle, color: scheme.error, size: 20),
              ],
            ),
          ),
        );
      case _VoiceState.uploading:
        final dots = '.' * (1 + _tickCounter % 3);
        return Padding(
          key: const ValueKey('up'),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 14, height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor:
                      AlwaysStoppedAnimation(scheme.onSurfaceVariant),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '识别中$dots',
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 13,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        );
    }
  }
}
