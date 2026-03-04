import 'package:flutter/material.dart';
import '../utils/constantes.dart';

// ─────────────────────────────────────────────────────────────────────────────
// NOUVELLE PLAQUE (SIV) — preview en temps réel
// ─────────────────────────────────────────────────────────────────────────────

/// Preview d'une plaque SIV (AA-123-BB) avec logo région.
/// Affiche la plaque vierge tant que l'immatriculation n'est pas complète.
///
/// [immat] : valeur du champ (ex "AB-123-CD"), peut être partielle
/// [dept]  : numéro de département (ex "59"), peut être vide
class NouvellePlaquePreview extends StatelessWidget {
  final String immat;
  final String dept;

  const NouvellePlaquePreview({
    super.key,
    required this.immat,
    required this.dept,
  });

  @override
  Widget build(BuildContext context) {
    // Extraire les caractères utiles (alphanum + tirets)
    final chars =
        immat.replaceAll(RegExp(r'[^A-Za-z0-9\-]'), '').toLowerCase().split('');
    final deptClean = dept.trim().toUpperCase();
    final deptChars = deptClean.split('');
    final region = departementRegion[deptClean];

    // Dimensions de référence du bitmap original : 2909 × 590 px
    // Toutes les constantes ci-dessous sont proportionnelles à ces valeurs.
    const bmpW = 2909.0;
    const bmpH = 590.0;

    // Positions des éléments principaux (calquées sur generateNovellePlaqueBitmap)
    const charLeft = 383.0; // paddingLeft des chars principaux
    const charTop = 65.0;
    const charW = 238.0; // largeur d'un char principal
    const charH = 460.0; // hauteur approximative (bitmap source)

    const deptLeft = 2660.0;
    const deptTop = 340.0;
    const deptCharW = 124.0;
    const deptCharH = 215.0; // hauteur approximative

    const logoLeft = 2672.0;
    const logoTop = 55.0;
    const logoW = 200.0;
    const logoH = 220.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = constraints.maxWidth / bmpW;
        final widgetH = bmpH * scale;

        return SizedBox(
          width: constraints.maxWidth,
          height: widgetH,
          child: Stack(
            children: [
              // Plaque de fond
              Positioned.fill(
                child: Image.asset(
                  'assets/plaque_vierge.jpg',
                  fit: BoxFit.fill,
                ),
              ),

              // Caractères principaux
              for (int i = 0; i < chars.length; i++)
                Positioned(
                  left: (charLeft + i * charW) * scale,
                  top: charTop * scale,
                  width: charW * scale,
                  height: charH * scale,
                  child: Image.asset(
                    'assets/lettres_pleines_vignette/${chars[i]}.jpg',
                    fit: BoxFit.fill,
                  ),
                ),

              // Chiffres de département
              for (int i = 0; i < deptChars.length; i++)
                Positioned(
                  left: (deptLeft + i * deptCharW) * scale,
                  top: deptTop * scale,
                  width: deptCharW * scale,
                  height: deptCharH * scale,
                  child: Image.asset(
                    'assets/lettres_departement/${deptChars[i].toLowerCase()}.jpg',
                    fit: BoxFit.fill,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),

              // Logo région
              if (region != null)
                Positioned(
                  left: logoLeft * scale,
                  top: logoTop * scale,
                  width: logoW * scale,
                  height: logoH * scale,
                  child: Image.asset(
                    'assets/logo_taille/$region.jpg',
                    fit: BoxFit.contain,
                    alignment: Alignment.topLeft,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ANCIENNE PLAQUE (FNI) — preview en temps réel
// ─────────────────────────────────────────────────────────────────────────────

/// Preview d'une plaque FNI (ABC 123 AB ou ABCD 123 AB).
/// Affiche la plaque vierge tant que l'immatriculation n'est pas complète.
///
/// [immat] : valeur du champ (ex "ABC 123 AB"), peut être partielle
class AnciennePlaquePreview extends StatelessWidget {
  final String immat;

  const AnciennePlaquePreview({
    super.key,
    required this.immat,
  });

  @override
  Widget build(BuildContext context) {
    // Convertit en format interne : espaces → '_'
    final raw = immat.toLowerCase().replaceAll(' ', '_');

    // Dimensions bitmap original : 2909 × 590 px (même base)
    const bmpW = 2909.0;
    const bmpH = 590.0;

    // Constantes calquées sur generateAnciennePlaqueBitmap
    const charW = 238.0;
    const charH = 464.0;
    const charTop = 65.0;
    const separatorW = 150.0;

    // Le paddingLeft dépend du format (10 ou 11 chars avec séparateurs)
    final double paddingLeft = raw.length == 11 ? 282.0 : 401.0;

    // Construire la liste de (char, offsetX)
    final List<(String, double)> drawItems = [];
    double offsetX = 0;
    for (final ch in raw.split('')) {
      if (ch == '_') {
        offsetX += separatorW;
      } else {
        drawItems.add((ch, offsetX));
        offsetX += charW;
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = constraints.maxWidth / bmpW;
        final widgetH = bmpH * scale;

        return SizedBox(
          width: constraints.maxWidth,
          height: widgetH,
          child: Stack(
            children: [
              // Plaque de fond
              Positioned.fill(
                child: Image.asset(
                  'assets/plaque_ancien_vierge.jpg',
                  fit: BoxFit.fill,
                ),
              ),

              // Caractères
              for (final (ch, ox) in drawItems)
                Positioned(
                  left: (paddingLeft + ox) * scale,
                  top: charTop * scale,
                  width: charW * scale,
                  height: charH * scale,
                  child: Image.asset(
                    'assets/lettres_pleine_vignette_ancien/$ch.jpg',
                    fit: BoxFit.fill,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
