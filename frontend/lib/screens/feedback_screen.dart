import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/generated/app_localizations.dart';
import '../providers/auth_provider.dart';
import '../services/feedback_service.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _contentCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _svc = FeedbackService();
  bool _sending = false;

  @override
  void dispose() {
    _contentCtrl.dispose();
    _contactCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final content = _contentCtrl.text.trim();
    if (content.isEmpty) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _sending = true);
    try {
      await _svc.submit(
        userId: context.read<AuthProvider>().userId,
        content: content,
        contact: _contactCtrl.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.feedbackSent)),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.feedbackFailed(e.toString()))),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final canSend = _contentCtrl.text.trim().isNotEmpty && !_sending;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.feedbackTitle)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: TextField(
                  controller: _contentCtrl,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  keyboardType: TextInputType.multiline,
                  onChanged: (_) => setState(() {}),  // refresh Send enablement
                  decoration: InputDecoration(
                    hintText: l10n.feedbackHint,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _contactCtrl,
                decoration: InputDecoration(
                  labelText: l10n.feedbackContactLabel,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 48,
                child: FilledButton.icon(
                  onPressed: canSend ? _submit : null,
                  icon: _sending
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.send),
                  label: Text(l10n.feedbackSubmit),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
