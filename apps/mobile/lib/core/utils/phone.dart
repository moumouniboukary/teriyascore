import 'package:flutter/services.dart';

/// 8 chiffres locaux : 01–07 (plan 2024) ou anciens 5x / 6x / 7x.
final _bfLocalRe = RegExp(r'^(0[1-7]|[5-7]\d)\d{6}$');

String bfLocalDigits(String raw) {
  var digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.startsWith('226')) {
    digits = digits.substring(3);
  }
  return digits;
}

bool isValidBfPhone(String raw) {
  final local = bfLocalDigits(raw);
  return local.length == 8 && _bfLocalRe.hasMatch(local);
}

/// E.164 `+226XXXXXXXX` si le numéro est un mobile BF valide.
String normalizeBfPhone(String raw) {
  final local = bfLocalDigits(raw);
  if (local.length == 8 && _bfLocalRe.hasMatch(local)) {
    return '+226$local';
  }
  return raw.trim();
}

/// Préfixe +226 fixe, 8 chiffres locaux, affichage `+226 XX XX XX XX`.
class BfPhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var local = bfLocalDigits(newValue.text);
    if (local.length > 8) local = local.substring(0, 8);
    final buf = StringBuffer('+226');
    for (var i = 0; i < local.length; i++) {
      if (i % 2 == 0) buf.write(' ');
      buf.write(local[i]);
    }
    final text = buf.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
