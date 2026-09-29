import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localization/flutter_localization.dart';

import '../data/player_name_store.dart';
import '../l10n/app_locale.dart';

class NameEntryPage extends StatefulWidget {
  const NameEntryPage({super.key, required this.onSaved});

  final ValueChanged<String> onSaved;

  @override
  State<NameEntryPage> createState() => _NameEntryPageState();
}

class _NameEntryPageState extends State<NameEntryPage> {
  final TextEditingController _input = TextEditingController();
  final PlayerNameStore _store = PlayerNameStore();

  String? _errorKey;
  bool _saving = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
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
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      key: const ValueKey('name_entry_title'),
                      AppLocale.nameEntryTitle.getString(context),
                      style: theme.textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AppLocale.nameEntrySubtitle.getString(context),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.hintColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      key: const ValueKey('name_input'),
                      controller: _input,
                      autofocus: true,
                      autocorrect: false,
                      maxLength: maxPlayerNameLength,
                      textInputAction: TextInputAction.done,
                      inputFormatters: <TextInputFormatter>[
                        LengthLimitingTextInputFormatter(maxPlayerNameLength),
                      ],
                      onSubmitted: (_) => _submit(),
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
                    const SizedBox(height: 16),
                    FilledButton(
                      key: const ValueKey('name_continue_button'),
                      onPressed: _saving ? null : _submit,
                      child: Text(AppLocale.continueLabel.getString(context)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
