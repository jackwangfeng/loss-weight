import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../l10n/generated/app_localizations.dart';

/// 语音输入按钮：点一下开始，再点一下停止；转写过程中实时写入
/// 绑定的 TextEditingController，结束后可触发 onFinalized 回调（一般用于
/// 自动跑 AI 估算/解析）。
///
/// 三端支持：
///   - iOS / Android：native SFSpeechRecognizer / SpeechRecognizer
///   - Web：浏览器 SpeechRecognition API（Chrome/Edge 原生，Firefox 需要 flag）
class VoiceInputButton extends StatefulWidget {
  final TextEditingController targetController;
  final VoidCallback? onFinalized;
  final String localeId;
  const VoiceInputButton({
    Key? key,
    required this.targetController,
    this.onFinalized,
    this.localeId = 'en-US',
  }) : super(key: key);

  @override
  State<VoiceInputButton> createState() => _VoiceInputButtonState();
}

class _VoiceInputButtonState extends State<VoiceInputButton>
    with SingleTickerProviderStateMixin {
  final stt.SpeechToText _speech = stt.SpeechToText();
  late final AnimationController _pulse;
  bool _initialized = false;
  bool _available = false;
  bool _listening = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _init();
  }

  Future<void> _init() async {
    try {
      _available = await _speech.initialize(
        onStatus: (s) {
          if ((s == 'notListening' || s == 'done') && mounted) {
            setState(() => _listening = false);
          }
        },
        onError: (err) {
          if (!mounted) return;
          setState(() => _listening = false);
          // error_no_match / error_speech_timeout 算常见情况，不弹
          if (err.errorMsg.contains('no_match') ||
              err.errorMsg.contains('no_speech') ||
              err.errorMsg.contains('timeout')) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Voice recognition error: ${err.errorMsg}')),
          );
        },
      );
    } catch (_) {
      _available = false;
    }
    if (mounted) setState(() => _initialized = true);
  }

  Future<void> _toggle() async {
    if (!_initialized) return;
    if (!_available) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).voiceNotAvailable)),
      );
      return;
    }
    if (_listening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
      if (widget.targetController.text.trim().isNotEmpty) {
        widget.onFinalized?.call();
      }
      return;
    }
    setState(() => _listening = true);
    await _speech.listen(
      onResult: (result) {
        widget.targetController.text = result.recognizedWords;
        widget.targetController.selection = TextSelection.collapsed(
          offset: result.recognizedWords.length,
        );
        if (result.finalResult) {
          if (mounted) setState(() => _listening = false);
          if (result.recognizedWords.trim().isNotEmpty) {
            widget.onFinalized?.call();
          }
        }
      },
      localeId: widget.localeId,
      partialResults: true,
      listenMode: stt.ListenMode.dictation,
      pauseFor: const Duration(seconds: 3),
      listenFor: const Duration(seconds: 30),
    );
  }

  @override
  void dispose() {
    _speech.stop();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const IconButton(
        icon: SizedBox(
          width: 16, height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        onPressed: null,
      );
    }
    final l10n = AppLocalizations.of(context);
    return IconButton(
      tooltip: _listening ? l10n.voiceTapToStop : l10n.voiceTapToSpeak,
      onPressed: _available ? _toggle : null,
      icon: AnimatedBuilder(
        animation: _pulse,
        builder: (ctx, _) {
          final listeningColor = Color.lerp(
            Colors.red.shade700,
            Colors.red.shade300,
            _pulse.value,
          );
          return Stack(
            alignment: Alignment.center,
            children: [
              if (_listening)
                Container(
                  width: 32 + 8 * _pulse.value,
                  height: 32 + 8 * _pulse.value,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.red.withValues(alpha: 0.15 * _pulse.value),
                  ),
                ),
              Icon(
                _listening ? Icons.mic : Icons.mic_none,
                color: _listening ? listeningColor : null,
              ),
            ],
          );
        },
      ),
    );
  }
}
