import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/tokens.dart';

/// Bouton retour AppBar — pop si possible, sinon fallback.
Widget tsBackButton(
  BuildContext context, {
  String fallbackLocation = '/',
  VoidCallback? onPressed,
}) {
  return IconButton(
    icon: const Icon(Icons.arrow_back),
    tooltip: 'Retour',
    onPressed: onPressed ??
        () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go(fallbackLocation);
          }
        },
  );
}

class TsPrimaryButton extends StatelessWidget {
  const TsPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        child: loading
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(label),
      ),
    );
  }
}

class TsSegmented extends StatelessWidget {
  const TsSegmented({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final List<(String value, String label)> options;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((o) {
        final selected = o.$1 == value;
        return ChoiceChip(
          label: Text(o.$2),
          selected: selected,
          onSelected: (_) => onChanged(o.$1),
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          selectedColor: TsTokens.brand.withValues(alpha: 0.35),
          labelStyle: TextStyle(
            color: selected ? TsTokens.brandSoft : TsTokens.textMute,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
          side: BorderSide(
            color: selected ? TsTokens.brand : TsTokens.line,
          ),
          backgroundColor: TsTokens.card2,
        );
      }).toList(),
    );
  }
}

/// État vide / hors ligne sans cache local (première sync manquante).
class TsOfflineEmpty extends StatelessWidget {
  const TsOfflineEmpty({
    super.key,
    required this.message,
    this.icon = Icons.cloud_off_outlined,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 48),
        Icon(icon, size: 48, color: TsTokens.textMute),
        const SizedBox(height: 16),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: TsTokens.textMute, height: 1.4),
        ),
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(height: 20),
          TsPrimaryButton(label: actionLabel!, onPressed: onAction),
        ],
      ],
    );
  }
}
