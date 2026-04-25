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
  /// `true` (default) → small mic icon, sits next to a text field.
  /// `false` → full-width "按住说话" pill, voice-only chat input mode.
  final bool compact;

  /// `true` → press-and-hold to record, release to send. Best for chat-
  /// style short utterances (WeChat / Doubao style).
  /// `false` (default) → tap to start, tap again to stop. Better for
  /// "think while you speak" inputs (profile setup, food/exercise/weight
  /// logging) where holding the finger down through pauses is awkward and
  /// short pauses get clipped to "按住说话哦" errors.
  final bool pressToTalk;

  const VoiceInputButton({
    Key? key,
    required this.targetController,
    this.onFinalized,
    this.onProfileParsed,
    this.localeId = 'en-US',
    this.compact = true,
    this.pressToTalk = false,
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
  StreamSubscription<RecordingDisposition>? _ampSub;
  // Last ~30 amplitude samples (0..1 normalized from decibels). Drives the
  // floating waveform above the press-and-hold button.
  final List<double> _amplitudes = [];

  // Press + drag plumbing (Doubao-style slide-up-to-cancel).
  Offset? _pressStartGlobal;
  bool _willCancel = false;
  // Above the button by this many pixels = "release here to cancel".
  static const _cancelThresholdPx = 80.0;
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

  // ----- Press-and-hold (chat / Doubao style) -----
  //   tap-down  → start recording
  //   tap-up    → stop + finalize
  //   tap-cancel (drag away / system steal) → discard, restore text
  //
  // Releases shorter than 300ms get treated as accidental taps and aborted
  // with a "按住说话哦" hint. The release-before-start race is handled by
  // checking `_releasedDuringStart` after the awaits in _start() finish.
  static const _minHoldMs = 300;
  DateTime? _pressStart;
  bool _releasedDuringStart = false;

  void _onPressDown(_) {
    if (_state != _VoiceState.idle) return;
    _pressStart = DateTime.now();
    _releasedDuringStart = false;
    _start();
  }

  void _onPressUp(_) async {
    if (_state == _VoiceState.idle) {
      _releasedDuringStart = true;
      return;
    }
    if (_state != _VoiceState.recording) return;
    final held = _pressStart == null
        ? Duration.zero
        : DateTime.now().difference(_pressStart!);
    _pressStart = null;
    if (held.inMilliseconds < _minHoldMs) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('按住说话哦')),
        );
      }
      await _abortInFlight();
      return;
    }
    await _stop();
  }

  void _onPressCancel() async {
    if (_state == _VoiceState.idle) {
      _releasedDuringStart = true;
      return;
    }
    if (_state != _VoiceState.recording) return;
    _pressStart = null;
    await _abortInFlight();
  }

  // Pointer-event handlers for the Doubao-style press-and-drag (only used
  // when both `pressToTalk` and `!compact` — the chat voice bar). These
  // track Y movement so user can slide up to flag "release here = cancel".
  void _onPointerDown(PointerDownEvent e) {
    if (_state != _VoiceState.idle) return;
    _pressStartGlobal = e.position;
    _willCancel = false;
    _pressStart = DateTime.now();
    _releasedDuringStart = false;
    _start();
  }

  void _onPointerMove(PointerMoveEvent e) {
    if (_pressStartGlobal == null) return;
    final dy = e.position.dy - _pressStartGlobal!.dy; // negative = moved up
    final shouldCancel = dy < -_cancelThresholdPx;
    if (shouldCancel != _willCancel) {
      setState(() => _willCancel = shouldCancel);
    }
  }

  void _onPointerUp(PointerUpEvent e) async {
    if (_state == _VoiceState.idle) {
      _releasedDuringStart = true;
      _willCancel = false;
      return;
    }
    if (_state != _VoiceState.recording) return;
    if (_willCancel) {
      // User dragged up past threshold and released — discard.
      _pressStartGlobal = null;
      _pressStart = null;
      await _abortInFlight();
      return;
    }
    // Same as _onPressUp: enforce min hold, otherwise stop+finalize.
    final held = _pressStart == null
        ? Duration.zero
        : DateTime.now().difference(_pressStart!);
    _pressStart = null;
    _pressStartGlobal = null;
    if (held.inMilliseconds < _minHoldMs) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('按住说话哦')),
        );
      }
      await _abortInFlight();
      return;
    }
    await _stop();
  }

  void _onPointerCancel(PointerCancelEvent e) async {
    _pressStartGlobal = null;
    if (_state == _VoiceState.idle) {
      _releasedDuringStart = true;
      return;
    }
    _pressStart = null;
    await _abortInFlight();
  }

  // ----- Tap-to-toggle (form / profile style) -----
  Future<void> _onTapToggle() async {
    if (_state == _VoiceState.recording) {
      await _stop();
    } else if (_state == _VoiceState.idle) {
      await _start();
    }
    // uploading state: ignore taps until previous round resolves
  }

  Future<void> _abortInFlight() async {
    try {
      await _recorder.stopRecorder();
    } catch (_) {}
    if (widget.onProfileParsed != null) {
      _resetFile();
    } else {
      _resetStreaming(restoreText: true);
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
      // Press-and-hold race: user released finger while we were still
      // wiring up the recorder. Translate that into a normal stop+finalize
      // so the recorder doesn't stay open in the background.
      if (widget.pressToTalk && _releasedDuringStart) {
        _releasedDuringStart = false;
        await _stop();
        return;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('录音失败: $e')),
        );
      }
      _resetStreaming();
    }
  }

  void _startAmplitude() {
    // Sample at ~12Hz — fast enough for a smooth bar dance, sparse enough to
    // not flood setState. Normalize decibels (-60dB silence → 0,
    // -10dB shouted speech → 1) using a clamp; flutter_sound rarely emits
    // anything outside [-120, 0].
    _recorder.setSubscriptionDuration(const Duration(milliseconds: 80));
    _ampSub = _recorder.onProgress?.listen((e) {
      if (!mounted) return;
      final db = e.decibels ?? -60;
      final norm = ((db + 60) / 50).clamp(0.0, 1.0);
      setState(() {
        _amplitudes.add(norm);
        if (_amplitudes.length > 30) _amplitudes.removeAt(0);
      });
    });
  }

  void _stopAmplitude() {
    _ampSub?.cancel();
    _ampSub = null;
    _amplitudes.clear();
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
    _startAmplitude();
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
    _startAmplitude();
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
    _stopAmplitude();
    _willCancel = false;
    _pressStartGlobal = null;
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
    _stopAmplitude();
    _willCancel = false;
    _pressStartGlobal = null;
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
    // Three gesture flavors:
    //   • !pressToTalk      → onTap (tap to start, tap again to stop)
    //   • pressToTalk+compact → onTapDown/Up (small mic, no slide-cancel)
    //   • pressToTalk+!compact → Listener (chat voice bar, full Doubao UX:
    //       press, drag up to mark cancel, release to send/cancel)
    final showFloatingPanel =
        widget.pressToTalk && !widget.compact && _state == _VoiceState.recording;

    final core = !widget.pressToTalk
        ? GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _onTapToggle,
            child: _stateChild(scheme),
          )
        : widget.compact
            ? GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: _onPressDown,
                onTapUp: _onPressUp,
                onTapCancel: _onPressCancel,
                child: _stateChild(scheme),
              )
            : Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: _onPointerDown,
                onPointerMove: _onPointerMove,
                onPointerUp: _onPointerUp,
                onPointerCancel: _onPointerCancel,
                child: _stateChild(scheme),
              );

    if (!showFloatingPanel) return core;
    // Floating "press-to-talk" panel above the button while recording. Sits
    // in the same vertical column so AnimatedSize on the parent gives a
    // smooth height-grow when recording starts.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _floatingPanel(scheme),
        const SizedBox(height: 8),
        core,
      ],
    );
  }

  Widget _floatingPanel(ColorScheme scheme) {
    final cancelTint = _willCancel ? scheme.error : scheme.primary;
    final mainText = _willCancel ? '松开取消' : '松开发送';
    final hintText = _willCancel ? '↓ 移回继续' : '↑ 上移取消';
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: (_willCancel ? scheme.error : scheme.surfaceContainerHighest)
            .withValues(alpha: _willCancel ? 0.12 : 1.0),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: cancelTint.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Waveform — heights animate to current amplitude samples.
          SizedBox(
            height: 28,
            child: _Waveform(
              amplitudes: _amplitudes,
              color: cancelTint,
              cancelMode: _willCancel,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            mainText,
            style: TextStyle(
              color: cancelTint,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            hintText,
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _stateChild(ColorScheme scheme) {
    final idleHint = widget.pressToTalk ? '按住说话' : '点一下说话';
    final recHint = widget.pressToTalk ? '松开发送' : '点一下结束';
    return switch (_state) {
      _VoiceState.idle => Tooltip(
          key: const ValueKey('idle'),
          message: idleHint,
          child: widget.compact
              ? Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(Icons.mic, color: scheme.primary),
                )
              : Container(
                  // Doubao-style "按住说话" full-width pill, used when the
                  // chat input bar is in voice-only mode.
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.mic, size: 18, color: scheme.primary),
                      const SizedBox(width: 6),
                      Text(idleHint,
                          style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
        ),
      _VoiceState.recording => Container(
          key: const ValueKey('rec'),
          padding: EdgeInsets.symmetric(
              horizontal: widget.compact ? 10 : 16,
              vertical: widget.compact ? 8 : 12),
          decoration: BoxDecoration(
            color: scheme.error.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(widget.compact ? 20 : 24),
          ),
          child: Row(
            mainAxisAlignment: widget.compact
                ? MainAxisAlignment.start
                : MainAxisAlignment.center,
            mainAxisSize:
                widget.compact ? MainAxisSize.min : MainAxisSize.max,
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
              Text(
                recHint,
                style: TextStyle(
                  color: scheme.error,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      _VoiceState.uploading => Padding(
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
                '识别中${'.' * (1 + _tickCounter % 3)}',
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 13,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
    };
  }
}

/// Floating waveform on top of the press-and-hold pill. Renders 24 bars
/// whose heights map directly to the recent amplitude buffer. When
/// `cancelMode` is on we desaturate to grey-red and shrink so it visually
/// "deadens" — telling the user "you're about to throw this away".
class _Waveform extends StatelessWidget {
  final List<double> amplitudes;
  final Color color;
  final bool cancelMode;
  const _Waveform({
    required this.amplitudes,
    required this.color,
    required this.cancelMode,
  });

  static const _barCount = 24;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _WaveformPainter(
        // Right-align: newest samples on the right, older on the left, so
        // the waveform "scrolls" rightward like every other audio app.
        samples: _padOrTrim(amplitudes, _barCount),
        color: color,
        attenuate: cancelMode ? 0.4 : 1.0,
      ),
      size: const Size.fromHeight(28),
    );
  }

  static List<double> _padOrTrim(List<double> src, int n) {
    if (src.length >= n) return src.sublist(src.length - n);
    return List<double>.filled(n - src.length, 0) + src;
  }
}

class _WaveformPainter extends CustomPainter {
  final List<double> samples; // 0..1
  final Color color;
  final double attenuate;
  _WaveformPainter({
    required this.samples,
    required this.color,
    required this.attenuate,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final n = samples.length;
    final gap = 2.0;
    final barW = (size.width - gap * (n - 1)) / n;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    for (var i = 0; i < n; i++) {
      // Floor-clamp so silent passages still show a thin baseline tick —
      // makes the bar bank feel "alive" instead of "dead until you speak".
      final h = ((samples[i].clamp(0.0, 1.0) * 0.85 + 0.05) * size.height) *
          attenuate;
      final x = i * (barW + gap);
      final y = (size.height - h) / 2;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barW, h),
        const Radius.circular(2),
      );
      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter old) =>
      old.samples != samples ||
      old.color != color ||
      old.attenuate != attenuate;
}
