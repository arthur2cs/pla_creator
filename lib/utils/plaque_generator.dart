import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'constantes.dart';

/// Charge une image depuis les assets Flutter et la décode avec le package image.
Future<img.Image> _loadAssetImage(String assetPath) async {
  final ByteData data = await rootBundle.load(assetPath);
  final Uint8List bytes = data.buffer.asUint8List();
  final img.Image? decoded = img.decodeImage(bytes);
  if (decoded == null) throw Exception('Impossible de décoder : $assetPath');
  return decoded;
}

// ---------------------------------------------------------------------------
// NOUVELLE PLAQUE (SIV, format AA-123-BB)
// ---------------------------------------------------------------------------

/// Formate une saisie brute en numéro de plaque SIV (ex: "ab123cd" → "ab-123-cd").
/// Retourne une chaîne vide si la saisie ne fait pas 7 caractères alphanumériques.
String formatNouvelleImmatriculation(String raw) {
  final cleaned = raw.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toLowerCase();
  if (cleaned.length != 7) return '';
  return '${cleaned.substring(0, 2)}-${cleaned.substring(2, 5)}-${cleaned.substring(5, 7)}';
}

/// Génère le bitmap complet d'une nouvelle plaque SIV.
/// [immat]  : numéro formaté, ex "ab-123-cd"
/// [dept]   : numéro de département, ex "59"
Future<img.Image> generateNovellePlaqueBitmap(
  String immat,
  String dept,
) async {
  // --- Plaque de base ---
  final base = await _loadAssetImage('assets/plaque_vierge.jpg');
  final canvas = img.Image(width: base.width, height: base.height);
  img.compositeImage(canvas, base, dstX: 0, dstY: 0);

  // --- Caractères principaux (lettres_pleines_vignette) ---
  const charsFolder = 'assets/lettres_pleines_vignette/';
  const paddingLeft = 383;
  const paddingTop = 65;
  const charWidth = 238;
  int offsetX = 0;

  for (final ch in immat.split('')) {
    final charImg = await _loadAssetImage('$charsFolder$ch.jpg');
    img.compositeImage(canvas, charImg, dstX: paddingLeft + offsetX, dstY: paddingTop);
    offsetX += charWidth;
  }

  // --- Numéro de département (lettres_departement) ---
  const deptFolder = 'assets/lettres_departement/';
  const deptPaddingLeft = 2660;
  const deptPaddingTop = 340;
  const deptCharWidth = 124;
  int deptOffsetX = 0;

  for (final ch in dept.split('')) {
    final charImg = await _loadAssetImage('$deptFolder$ch.jpg');
    img.compositeImage(
      canvas,
      charImg,
      dstX: deptPaddingLeft + deptOffsetX,
      dstY: deptPaddingTop,
    );
    deptOffsetX += deptCharWidth;
  }

  // --- Logo région ---
  final region = departementRegion[dept];
  if (region != null) {
    const logoFolder = 'assets/logo_taille/';
    final logo = await _loadAssetImage('$logoFolder$region.jpg');
    final logoPaddingTop = 55 - (logo.height - 220) ~/ 2;
    img.compositeImage(canvas, logo, dstX: 2672, dstY: logoPaddingTop);
  }

  return canvas;
}

// ---------------------------------------------------------------------------
// ANCIENNE PLAQUE (FNI)
// ---------------------------------------------------------------------------

/// Formate une saisie brute en numéro de plaque FNI.
/// 8 alphanum → "ABC_123_AB"  (format 3+3+2)
/// 9 alphanum → "ABCD_123_AB" (format 4+3+2)
/// Retourne une chaîne vide si la longueur ne correspond pas.
String formatAncienneImmatriculation(String raw) {
  final cleaned = raw.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toLowerCase();
  if (cleaned.length == 8) {
    return '${cleaned.substring(0, 3)}_${cleaned.substring(3, 6)}_${cleaned.substring(6, 8)}';
  } else if (cleaned.length == 9) {
    return '${cleaned.substring(0, 4)}_${cleaned.substring(4, 7)}_${cleaned.substring(7, 9)}';
  }
  return '';
}

/// Génère le bitmap complet d'une ancienne plaque FNI.
/// [immat] : numéro formaté avec '_' comme séparateur
Future<img.Image> generateAnciennePlaqueBitmap(String immat) async {
  // --- Plaque de base ---
  final base = await _loadAssetImage('assets/plaque_ancien_vierge.jpg');
  final canvas = img.Image(width: base.width, height: base.height);
  img.compositeImage(canvas, base, dstX: 0, dstY: 0);

  // --- Caractères ---
  const charsFolder = 'assets/lettres_pleine_vignette_ancien/';
  // Centrage selon longueur totale (10 = format court, 11 = format long)
  final paddingLeft = immat.length == 10 ? 401 : 282;
  const paddingTop = 65;
  const charWidth = 238;
  const charHeight = 464;
  const separatorWidth = 150;
  int offsetX = 0;

  for (final ch in immat.split('')) {
    if (ch == '_') {
      offsetX += separatorWidth;
      continue;
    }
    final charImg = await _loadAssetImage('$charsFolder$ch.jpg');
    final scaled = img.copyResize(charImg, width: charWidth, height: charHeight);
    img.compositeImage(canvas, scaled, dstX: paddingLeft + offsetX, dstY: paddingTop);
    offsetX += charWidth;
  }

  return canvas;
}

// ---------------------------------------------------------------------------
// GÉNÉRATION PDF (commun aux deux types de plaque)
// ---------------------------------------------------------------------------
// Le PDF A4 contient 2 pages :
//   - Page 1 : moitié haute de la plaque (pivotée 90°, mise à l'échelle A4)
//   - Page 2 : moitié basse
// Cela correspond exactement au comportement de l'appli Android originale.

/// Génère un PDF en mémoire à partir d'un [plaqueBitmap] et retourne les bytes.
///
/// Chaque demi-plaque (260 × 110 mm) est imprimée **verticalement** sur une
/// page A4 portrait (210 × 297 mm) :
///   - la longueur de 260 mm est orientée dans le sens de la hauteur (297 mm)
///   - la hauteur de 110 mm est centrée dans la largeur (210 mm)
/// En imprimant les deux feuilles et en les collant, on obtient la plaque
/// complète au format réel 520 × 110 mm.
Future<Uint8List> generatePdfFromBitmap(img.Image plaqueBitmap) async {
  final jpegBytes = Uint8List.fromList(img.encodeJpg(plaqueBitmap, quality: 95));

  // 1 mm = 2.8346 points PDF
  const mm = 2.8346;

  // Page A4 portrait
  const pageW = 210.0 * mm; // ≈ 595.3 pts
  const pageH = 297.0 * mm; // ≈ 841.9 pts

  // Plaque réelle : 520 mm de long → scale basé sur la largeur du bitmap
  const plaqueW = 520.0 * mm; // ≈ 1474.0 pts (longueur totale)

  final double bmpW = plaqueBitmap.width.toDouble();
  final double bmpH = plaqueBitmap.height.toDouble();

  // Scale : bmpW pixels → 520 mm
  final double scale = plaqueW / bmpW;

  // Après scale :
  //   longueur totale  = plaqueW      (≈ 1474 pts)
  //   demi-longueur    = plaqueW / 2  (≈  737 pts = 260 mm)
  //   hauteur de plaque = bmpH * scale (≈  299 pts ≈ 105 mm)
  final double halfW   = plaqueW / 2;
  final double rendH   = bmpH * scale;

  // Rotation +90° (CCW) : le bitmap couché passe en portrait sur la page.
  // Transformation appliquée : translate(cx, cy) → rotateZ(+π/2) → scale(s,s)
  // Un point (x, y) du bitmap arrive en page à :
  //   page_x = cx - y * scale
  //   page_y = cy + x * scale
  //
  // On veut :
  //   - la hauteur de la plaque (axe Y bitmap, 0..bmpH) centrée en X page
  //     => cx = (pageW + rendH) / 2
  //   - la demi-longueur (axe X bitmap) centrée en Y page
  //     => cy = (pageH - halfW) / 2
  //   - Page 1 : affiche x = 0..bmpW/2  → cy = margin_y
  //   - Page 2 : affiche x = bmpW/2..bmpW → cy = margin_y - halfW
  final double cx       = (pageW + rendH) / 2;
  final double marginY  = (pageH - halfW) / 2;
  final cys = [marginY, marginY - halfW];

  final pdf = pw.Document();
  final pdfDoc = pdf.document;
  final pdfImage = PdfImage.jpeg(pdfDoc, image: jpegBytes);

  for (final cy in cys) {
    final page = PdfPage(
      pdfDoc,
      pageFormat: const PdfPageFormat(pageW, pageH),
    );
    final g = page.getGraphics();

    g.saveContext();
    g.setTransform(
      Matrix4.identity()
        ..translateByDouble(cx, cy, 0.0, 1.0)
        ..rotateZ(math.pi / 2)   // +90° CCW
        ..scaleByDouble(scale, scale, 1.0, 1.0),
    );
    // drawImage en coordonnées locales (bitmap entier, le clip est géré par la page)
    g.drawImage(pdfImage, 0, 0, bmpW, bmpH);
    g.restoreContext();
  }

  return pdfDoc.save();
}
