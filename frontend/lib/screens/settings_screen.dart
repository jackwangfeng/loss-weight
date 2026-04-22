import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/generated/app_localizations.dart';
import '../providers/locale_provider.dart';

/// Settings page. Currently only language selection; the page exists as the
/// landing surface for future preferences (theme, units, notifications, etc.).
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final localeProvider = context.watch<LocaleProvider>();

    // null = "follow system"; Locale('en')/Locale('zh') are explicit overrides.
    final current = localeProvider.locale?.languageCode;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionHeader(context, l10n.settingsLanguage),
          Card(
            child: Column(
              children: [
                _LanguageTile(
                  label: l10n.settingsLanguageSystem,
                  selected: current == null,
                  onTap: () => localeProvider.setLanguageCode(null),
                ),
                _divider(scheme),
                _LanguageTile(
                  label: l10n.settingsLanguageEnglish,
                  selected: current == 'en',
                  onTap: () => localeProvider.setLanguageCode('en'),
                ),
                _divider(scheme),
                _LanguageTile(
                  label: l10n.settingsLanguageChinese,
                  selected: current == 'zh',
                  onTap: () => localeProvider.setLanguageCode('zh'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              l10n.settingsLanguageDescription,
              style: TextStyle(
                fontSize: 12,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(BuildContext ctx, String label) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
        child: Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            letterSpacing: 0.8,
            color: Theme.of(ctx).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      );

  Widget _divider(ColorScheme s) =>
      Divider(height: 1, color: s.outlineVariant, indent: 16, endIndent: 16);
}

class _LanguageTile extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _LanguageTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      title: Text(label),
      trailing: selected
          ? Icon(Icons.check, color: scheme.primary)
          : const SizedBox(width: 20),
      onTap: onTap,
    );
  }
}
