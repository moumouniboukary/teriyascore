import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/tokens.dart';

/// Grand clavier numérique 3×4 (1-9, effacer, 0, retour) — pensé pour la
/// faible littératie : gros boutons, pas de saisie clavier système requise.
class TsNumericKeypad extends StatelessWidget {
  const TsNumericKeypad({
    super.key,
    required this.onDigit,
    required this.onBackspace,
    required this.onClear,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onClear;

  static const _keys = [
    '1',
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
    '9',
    'C',
    '0',
    '⌫',
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.7,
      children: _keys.map((k) {
        final isAction = k == 'C' || k == '⌫';
        return _NfKeypadButton(
          label: k,
          isAction: isAction,
          onTap: () {
            HapticFeedback.selectionClick();
            if (k == 'C') {
              onClear();
            } else if (k == '⌫') {
              onBackspace();
            } else {
              onDigit(k);
            }
          },
        );
      }).toList(),
    );
  }
}

class _NfKeypadButton extends StatelessWidget {
  const _NfKeypadButton({
    required this.label,
    required this.onTap,
    required this.isAction,
  });

  final String label;
  final VoidCallback onTap;
  final bool isAction;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isAction ? TsTokens.card2 : TsTokens.elevated,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: TsTokens.line),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: label == '⌫' ? 26 : 24,
              fontWeight: FontWeight.w800,
              color: isAction ? TsTokens.warn : TsTokens.text,
            ),
          ),
        ),
      ),
    );
  }
}

/// Champ montant en lecture seule + clavier numérique intégré — combine
/// affichage grande taille et [TsNumericKeypad], relié à un [TextEditingController].
class TsKeypadAmountField extends StatelessWidget {
  const TsKeypadAmountField({
    super.key,
    required this.controller,
    required this.label,
    this.maxDigits = 9,
    this.trailing,
  });

  final TextEditingController controller;
  final String label;
  final int maxDigits;
  final Widget? trailing;

  void _append(String digit) {
    if (controller.text.length >= maxDigits) return;
    controller.text += digit;
  }

  void _backspace() {
    if (controller.text.isEmpty) return;
    controller.text = controller.text.substring(0, controller.text.length - 1);
  }

  void _clear() {
    controller.text = '';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: TsTokens.textMute, fontSize: 13)),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          decoration: BoxDecoration(
            color: TsTokens.elevated,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: TsTokens.line),
          ),
          child: Row(
            children: [
              Expanded(
                child: AnimatedBuilder(
                  animation: controller,
                  builder: (context, _) {
                    final text = controller.text.isEmpty ? '0' : controller.text;
                    return Text(
                      text,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: TsTokens.brandSoft,
                      ),
                    );
                  },
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
        const SizedBox(height: 14),
        TsNumericKeypad(
          onDigit: _append,
          onBackspace: _backspace,
          onClear: _clear,
        ),
      ],
    );
  }
}
