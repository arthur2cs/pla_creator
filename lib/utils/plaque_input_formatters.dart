import 'package:flutter/services.dart';

/// Formatte en temps réel une immatriculation SIV : AB-123-CD
///
/// Règles :
/// - Les caractères alphanumériques sont extraits et mis en majuscules.
/// - Les tirets sont insérés automatiquement après le 2ème et le 5ème char utile.
/// - Si le user tape lui-même un tiret à la bonne position, il est accepté
///   (pas de double-tiret, pas de tiret parasite).
/// - Longueur max : 9 caractères affichés (AA-123-BB).
class NouvelleImmatFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Extrait uniquement les alphanum en majuscules
    final raw = newValue.text.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();

    // Limite à 7 caractères utiles
    final limited = raw.length > 7 ? raw.substring(0, 7) : raw;

    // Reconstruit avec tirets automatiques
    final buffer = StringBuffer();
    for (int i = 0; i < limited.length; i++) {
      if (i == 2 || i == 5) buffer.write('-');
      buffer.write(limited[i]);
    }

    // Cas spécial : si le user vient de taper un tiret à la bonne position
    // (ex: "AB-" alors que raw="AB"), on le conserve pour ne pas bloquer la frappe.
    String formatted = buffer.toString();
    final newRaw = newValue.text.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    if (newValue.text.endsWith('-') &&
        (newRaw.length == 2 || newRaw.length == 5) &&
        !formatted.endsWith('-')) {
      formatted = '$formatted-';
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// Formatte en temps réel une immatriculation FNI : ABC 123 AB ou ABCD 123 AB
///
/// Règles :
/// - Les caractères alphanumériques sont extraits et mis en majuscules.
/// - Les espaces sont insérés automatiquement aux bonnes positions.
/// - Si le user tape lui-même un espace à la bonne position, il est accepté.
/// - Le format (3+3+2 ou 4+3+2) est déterminé dès le 4ème caractère.
/// - Longueur max : 11 caractères affichés (ABCD 123 AB).
class AncienneImmatFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final raw = newValue.text.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();

    // Limite à 9 caractères utiles
    final limited = raw.length > 9 ? raw.substring(0, 9) : raw;
    final len = limited.length;

    // Détermine les positions des séparateurs dès que le 4ème char est connu
    int? sep1;
    int? sep2;
    if (len >= 4) {
      final isLong = RegExp(r'[A-Z]').hasMatch(limited[3]);
      sep1 = isLong ? 4 : 3;
      sep2 = isLong ? 7 : 6;
    }

    final buffer = StringBuffer();
    for (int i = 0; i < len; i++) {
      if (sep1 != null && i == sep1) buffer.write(' ');
      if (sep2 != null && i == sep2) buffer.write(' ');
      buffer.write(limited[i]);
    }

    // Cas spécial : si le user vient de taper un espace à la bonne position,
    // on le conserve pour ne pas bloquer la frappe.
    String formatted = buffer.toString();
    if (newValue.text.endsWith(' ') && sep1 != null) {
      final rawLen = raw.length;
      if ((rawLen == sep1 || rawLen == sep2) && !formatted.endsWith(' ')) {
        formatted = '$formatted ';
      }
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
