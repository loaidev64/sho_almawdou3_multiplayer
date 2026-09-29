import 'package:animated_theme_switcher/animated_theme_switcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localization/flutter_localization.dart';

import '../data/player_name_store.dart';
import '../data/theme_store.dart';
import '../l10n/app_locale.dart';
import '../theme/app_theme.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.initialName,
    required this.onSaved,
    this.sessionActive = false,
  });

  final String initialName;
  final ValueChanged<String> onSaved;
  final bool sessionActive;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _input = TextEditingController(
    text: widget.initialName,
  );
  final PlayerNameStore _store = PlayerNameStore();
  final ThemeStore _themeStore = ThemeStore();

  String? _errorKey;
  bool _saving = false;
  AppThemeMode _themeMode = AppThemeMode.system;

  @override
  void initState() {
    super.initState();
    _loadThemeMode();
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _loadThemeMode() async {
    final AppThemeMode mode = await _themeStore.load();
    if (!mounted) return;
    setState(() => _themeMode = mode);
  }

  Future<void> _save() async {
    if (_saving) return;
    final String? errorKey = validatePlayerName(_input.text);
    if (errorKey != null) {
      setState(() => _errorKey = errorKey);
      return;
    }
    setState(() => _saving = true);
    final String name = _input.text.trim();
    await _store.save(name);
    if (!mounted) return;
    widget.onSaved(name);
    Navigator.of(context).pop();
  }

  Future<void> _changeTheme(
    BuildContext switcherContext,
    AppThemeMode? value,
  ) async {
    final AppThemeMode mode = value ?? AppThemeMode.system;
    if (mode == _themeMode) return;
    await _themeStore.save(mode);
    if (!mounted) return;
    setState(() => _themeMode = mode);
    if (!switcherContext.mounted) return;
    final Brightness brightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    ThemeSwitcher.of(switcherContext)
        .changeTheme(theme: appTheme(mode, brightness));
  }

  Widget _buildThemeOption({
    required AppThemeMode mode,
    required IconData icon,
    required String label,
  }) {
    return RadioListTile<AppThemeMode>(
      key: ValueKey('theme_mode_${mode.name}'),
      value: mode,
      contentPadding: EdgeInsets.zero,
      secondary: Icon(icon),
      title: Text(label),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return ThemeSwitchingArea(
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: theme.colorScheme.inversePrimary,
          title: Text(AppLocale.settings.getString(context)),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                TextField(
                  key: const ValueKey('name_input'),
                  controller: _input,
                  autocorrect: false,
                  maxLength: maxPlayerNameLength,
                  textInputAction: TextInputAction.done,
                  inputFormatters: <TextInputFormatter>[
                    LengthLimitingTextInputFormatter(maxPlayerNameLength),
                  ],
                  onSubmitted: (_) => _save(),
                  onChanged: (_) {
                    if (_errorKey != null) {
                      setState(() => _errorKey = null);
                    }
                  },
                  decoration: InputDecoration(
                    labelText: AppLocale.playerName.getString(context),
                    hintText: AppLocale.nameHint.getString(context),
                    counterText: '',
                    errorText: _errorKey?.getString(context),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                if (widget.sessionActive) ...<Widget>[
                  const SizedBox(height: 8),
                  Text(
                    key: const ValueKey('name_session_hint'),
                    AppLocale.nameSessionHint.getString(context),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.hintColor,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton.icon(
                  key: const ValueKey('name_save_button'),
                  onPressed: _saving ? null : _save,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(AppLocale.save.getString(context)),
                ),
                const SizedBox(height: 24),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Text(
                  key: const ValueKey('theme_section_title'),
                  AppLocale.themeSection.getString(context),
                  style: theme.textTheme.titleMedium,
                ),
                ThemeSwitcher(
                  builder: (BuildContext switcherContext) =>
                      RadioGroup<AppThemeMode>(
                        groupValue: _themeMode,
                        onChanged: (AppThemeMode? value) =>
                            _changeTheme(switcherContext, value),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            _buildThemeOption(
                              mode: AppThemeMode.light,
                              icon: Icons.light_mode_outlined,
                              label: AppLocale.themeLight.getString(context),
                            ),
                            _buildThemeOption(
                              mode: AppThemeMode.dark,
                              icon: Icons.dark_mode_outlined,
                              label: AppLocale.themeDark.getString(context),
                            ),
                            _buildThemeOption(
                              mode: AppThemeMode.system,
                              icon: Icons.brightness_auto_outlined,
                              label: AppLocale.themeSystem.getString(context),
                            ),
                          ],
                        ),
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
