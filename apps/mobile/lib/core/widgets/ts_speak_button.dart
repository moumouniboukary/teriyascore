import 'package:flutter/material.dart';

/// Ancien bouton assistance vocale — retiré (plus d'audio dans TeriyaScore).
class TsSpeakButton extends StatelessWidget {
  const TsSpeakButton({
    super.key,
    this.labelKey,
    this.text,
    this.vars = const {},
    this.alwaysShow = false,
    this.tooltip,
    this.compact = false,
  });

  final String? labelKey;
  final String? text;
  final Map<String, String> vars;
  final bool alwaysShow;
  final String? tooltip;
  final bool compact;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// En-tête sans bouton écoute.
class TsSpeakHeader extends StatelessWidget {
  const TsSpeakHeader({
    super.key,
    required this.titleKey,
    this.vars = const {},
    this.style,
  });

  final String titleKey;
  final Map<String, String> vars;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Text(
      titleKey,
      style: style ?? Theme.of(context).textTheme.titleLarge,
    );
  }
}

/// Passe-through — plus d'annonce vocale à l'ouverture.
class TsVoiceOnOpen extends StatelessWidget {
  const TsVoiceOnOpen({
    super.key,
    required this.child,
    this.labelKey,
    this.text,
  });

  final Widget child;
  final String? labelKey;
  final String? text;

  @override
  Widget build(BuildContext context) => child;
}
