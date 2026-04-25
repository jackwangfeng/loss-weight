import 'dart:async';
import 'dart:convert' hide Codec;
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as ws_status;

import '../l10n/generated/app_localizations.dart';
import '../services/ai_service.dart';
import '../services/api_service.dart';

/// Cloud voice input. Two paths:
///
///   • **Default mode** (no `onProfileParsed`): streams raw PCM 16kHz mono
///     over WebSocket to /v1/ai/transcribe/stream → paraformer-realtime-v2.
///     Partial text lands in the input field as the user is still speaking;
///     finalized ~0.5s after they release. Replaces the old batch HTTP path
///     which had a 4-5s post-release wait.
///   • **Profile mode** (`onProfileParsed` set): keeps the legacy HTTP
///     /v1/ai/transcribe-and-parse-profile flow because the upstream
///     LLM parse step needs the full audio + structured-output prompt
///     and isn't streamable today. Slower but rare-path (one-time setup).
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

  // Streaming-mode plumbing (default path).
  WebSocketChannel? _ws;
  StreamSubscription? _wsSub;
  StreamController<Uint8List>? _audioCtrl;
  StreamSubscription<Uint8List>? _audioSub;
  // Snapshot of the controller's text at recording start, so we restore it
  // if the user cancels mid-recording (errors / disconnect).
  String _textSnapshot = '';
  // Partial-text accumulator we keep separate from the controller so
  // higher-up code (e.g. existing typed text) isn't accidentally clobbered.
  String _liveTranscript = '';

  // Profile-mode plumbing (legacy file-based path).
  String? _currentPath;
  bool _opened = false;

  DateTime? _recordStart;
  Timer? _tickTimer;
  int _tickCounter = 0;
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
    _audioSub?.cancel();
    _audioCtrl?.close();
    _wsSub?.cancel();
    _ws?.sink.close(ws_status.normalClosure);
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
      await _stop();
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

      if (widget.onProfileParsed != null) {
        // Profile mode keeps the legacy file → HTTP flow.
        await _startFileRecording();
      } else {
        // Default mode: open WS + start PCM streaming.
        await _startStreamingRecording();
      }

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
      _resetStreaming();
    }
  }

  Future<void> _startStreamingRecording() async {
    final wsUrl = _streamUrl();
    _ws = WebSocketChannel.connect(wsUrl);
    _wsSub = _ws!.stream.listen(
      _onWsMessage,
      onError: (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('语音通道断开: $e')),
        );
        _resetStreaming(restoreText: true);
      },
      onDone: () {
        // If WS closed before we got a final, fall through to upload state
        // briefly so user can see something happened, then reset.
        if (!mounted) return;
        if (_state == _VoiceState.recording || _state == _VoiceState.uploading) {
          _finalizeIfNeeded();
        }
      },
      cancelOnError: true,
    );

    _textSnapshot = widget.targetController.text;
    _liveTranscript = '';

    _audioCtrl = StreamController<Uint8List>();
    _audioSub = _audioCtrl!.stream.listen((chunk) {
      // Forward each PCM chunk as a binary frame straight to the proxy.
      try {
        _ws?.sink.add(chunk);
      } catch (_) {
        // Sink closed under us — recording will stop on the next tick.
      }
    });

    await _recorder.startRecorder(
      toStream: _audioCtrl!.sink,
      codec: Codec.pcm16,
      sampleRate: 16000,
      numChannels: 1,
    );
  }

  Future<void> _startFileRecording() async {
    final tmp = await getTemporaryDirectory();
    _currentPath =
        '${tmp.path}/rec_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.startRecorder(
      toFile: _currentPath!,
      codec: Codec.aacMP4,
      sampleRate: 16000,
      numChannels: 1,
    );
  }

  Uri _streamUrl() {
    // Reuse ApiService's resolved base URL (handles dev/prod/web). Convert
    // http→ws / https→wss; append the stream endpoint.
    final base = Uri.parse(ApiService().baseUrl);
    final wsScheme = base.scheme == 'https' ? 'wss' : 'ws';
    return base.replace(
      scheme: wsScheme,
      path: '${base.path}/ai/transcribe/stream',
    );
  }

  void _onWsMessage(dynamic msg) {
    if (msg is! String) return;
    Map<String, dynamic> data;
    try {
      data = jsonDecode(msg) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    if (data['partial'] is String) {
      _liveTranscript = data['partial'] as String;
      _writeLive();
    } else if (data['final'] is String) {
      _liveTranscript = data['final'] as String;
      _writeLive();
      widget.onFinalized?.call();
      _resetStreaming();
    } else if (data['error'] is String) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('语音识别失败: ${data['error']}')),
        );
      }
      _resetStreaming(restoreText: true);
    }
  }

  void _writeLive() {
    if (!mounted) return;
    final base = _textSnapshot;
    final glue = base.isNotEmpty && !base.endsWith(' ') ? ' ' : '';
    final composed = '$base$glue$_liveTranscript';
    widget.targetController.value = TextEditingValue(
      text: composed,
      selection: TextSelection.collapsed(offset: composed.length),
    );
  }

  Future<void> _stop() async {
    if (widget.onProfileParsed != null) {
      await _stopAndUploadFile();
    } else {
      await _stopStreaming();
    }
  }

  Future<void> _stopStreaming() async {
    _tickTimer?.cancel();
    if (mounted) {
      setState(() {
        _state = _VoiceState.uploading;
        _tickCounter = 0;
      });
    }
    _tickTimer = Timer.periodic(const Duration(milliseconds: 400), (_) {
      if (!mounted) return;
      setState(() => _tickCounter++);
    });

    try {
      await _recorder.stopRecorder();
    } catch (_) {}
    await _audioSub?.cancel();
    _audioSub = null;
    await _audioCtrl?.close();
    _audioCtrl = null;

    // Signal to server: speech ended, please flush the last partial as final.
    try {
      _ws?.sink.add('finish');
    } catch (_) {}

    // _onWsMessage will fire `final` and call _resetStreaming(). If the
    // server doesn't respond within 5s, force-close anyway.
    Timer(const Duration(seconds: 5), () {
      if (_state != _VoiceState.idle) {
        _finalizeIfNeeded();
      }
    });
  }

  void _finalizeIfNeeded() {
    if (_liveTranscript.isNotEmpty) {
      widget.onFinalized?.call();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('没听清，再说一遍')),
      );
    }
    _resetStreaming();
  }

  void _resetStreaming({bool restoreText = false}) {
    if (restoreText && mounted) {
      widget.targetController.text = _textSnapshot;
    }
    _tickTimer?.cancel();
    _audioSub?.cancel();
    _audioSub = null;
    _audioCtrl?.close();
    _audioCtrl = null;
    _wsSub?.cancel();
    _wsSub = null;
    try {
      _ws?.sink.close(ws_status.normalClosure);
    } catch (_) {}
    _ws = null;
    _recordStart = null;
    if (mounted) setState(() => _state = _VoiceState.idle);
  }

  // ---------------------------------------------------------------
  // Profile-mode (legacy file → HTTP) — kept verbatim from before, just
  // factored out so the streaming code can sit beside it cleanly.
  // ---------------------------------------------------------------
  Future<void> _stopAndUploadFile() async {
    _tickTimer?.cancel();
    setState(() {
      _state = _VoiceState.uploading;
      _tickCounter = 0;
    });
    _tickTimer = Timer.periodic(const Duration(milliseconds: 400), (_) {
      if (!mounted) return;
      setState(() => _tickCounter++);
    });
    try {
      final path = await _recorder.stopRecorder() ?? _currentPath;
      if (path == null) {
        _resetFile();
        return;
      }
      final bytes = await File(path).readAsBytes();
      if (bytes.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('没录到声音，再试一次')),
          );
        }
        _resetFile();
        return;
      }
      final localeShort = widget.localeId.split('-').first;
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
      _resetFile();
    }
  }

  void _resetFile() {
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
