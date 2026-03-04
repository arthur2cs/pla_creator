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
Future<Uint8List> generatePdfFromBitmap(img.Image plaqueBitmap) async {
  // Encode le bitmap en JPEG pour l'intégrer dans le PDF
  final jpegBytes = Uint8List.fromList(img.encodeJpg(plaqueBitmap, quality: 95));

  const pageWidth = 595.0; // A4 en points (portrait)
  const pageHeight = 842.0;

  // Même calcul que l'Android original :
  // scale = pageHeight / bitmap.width * 520/297
  final double bmpW = plaqueBitmap.width.toDouble();
  final double bmpH = plaqueBitmap.height.toDouble();
  final double scale = pageHeight / bmpW * (520.0 / 297.0);

  // Taille de la plaque après mise à l'échelle (avant rotation)
  final double scaledW = bmpW * scale; // correspond à la "largeur" une fois pivotée → hauteur sur la page

  // Décalage pour chaque moitié (comme Android : newWidth * 112/520)
  final double halfShift = scaledW * 112.0 / 520.0;

  final pdf = pw.Document();
  final pdfDoc = pdf.document;

  // Crée l'image PDF une seule fois
  final pdfImage = PdfImage.jpeg(pdfDoc, image: jpegBytes);

  for (final isTop in [true, false]) {
    final page = PdfPage(pdfDoc, pageFormat: const PdfPageFormat(pageWidth, pageHeight));
    final g = page.getGraphics();

    // Le package `pdf` utilise un repère Y inversé (origine en bas à gauche).
    // On reproduit les 4 transformations Android :
    //   1. Rotation 90° autour du centre de la page
    //   2. Mise à l'échelle
    //   3. Centrage
    //   4. Décalage haut/bas selon la moitié

    g.saveContext();

    // Origine au centre de la page
    g.setTransform(
      Matrix4.identity()
        // Déplace l'origine au centre de la page (repère PDF bas-gauche)
        ..translateByDouble(pageWidth / 2, pageHeight / 2, 0.0, 1.0)
        // Rotation -90° (sens trigo → sens horaire en PDF)
        ..rotateZ(-math.pi / 2)
        // Décalage haut/bas pour la moitié concernée (axe Y post-rotation)
        ..translateByDouble(0.0, isTop ? halfShift : -halfShift, 0.0, 1.0)
        // Mise à l'échelle
        ..scaleByDouble(scale, scale, 1.0, 1.0)
        // Ramène le coin haut-gauche du bitmap à l'origine locale
        ..translateByDouble(-bmpW / 2, -bmpH / 2, 0.0, 1.0),
    );

    // Dessine le bitmap à (0,0) dans le repère local
    g.drawImage(pdfImage, 0, 0, bmpW * scale, bmpH * scale);

    g.restoreContext();
  }

  return pdfDoc.save();
}
