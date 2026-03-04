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
  // Encode le bitmap en PNG pour l'intégrer dans le PDF
  final pngBytes = Uint8List.fromList(img.encodePng(plaqueBitmap));
  final pdfImage = pw.MemoryImage(pngBytes);

  const pageWidth = 595.0;  // A4 en points
  const pageHeight = 842.0;

  // Ratio d'échelle : on fait tenir la largeur de la plaque dans la hauteur A4
  // (comme Android : scale = pageHeight / bitmap.width * 520/297)
  final scale = pageHeight / plaqueBitmap.width * (520.0 / 297.0);
  final scaledWidth = plaqueBitmap.width * scale;
  final scaledHeight = plaqueBitmap.height * scale;

  // Décalage vertical pour chaque moitié (comme Android : newWidth * 112/520)
  final halfShift = scaledWidth * 112.0 / 520.0;

  // Centrage sur la page
  final dx = (pageWidth - scaledWidth) / 2;
  final dy = (pageHeight - scaledHeight) / 2;

  final pdf = pw.Document();

  for (final isTop in [true, false]) {
    pdf.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(pageWidth, pageHeight),
        build: (context) {
          return pw.Transform(
            transform: Matrix4.identity()
              // 1. Mise à l'échelle
              ..scaleByDouble(scale, scale, 1.0, 1.0)
              // 2. Centrage
              ..translateByDouble(dx / scale, dy / scale, 0.0, 1.0)
              // 3. Décalage haut/bas
              ..translateByDouble(0.0, (isTop ? halfShift : -halfShift) / scale, 0.0, 1.0),
            child: pw.Transform.rotate(
              angle: 3.14159265 / 2, // 90°
              alignment: pw.Alignment.center,
              child: pw.Image(pdfImage),
            ),
          );
        },
      ),
    );
  }

  return pdf.save();
}
