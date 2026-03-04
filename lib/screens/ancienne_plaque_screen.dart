import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../utils/plaque_generator.dart';
import '../utils/plaque_input_formatters.dart';
import '../widgets/plaque_preview.dart';

class AnciennePlaqueScreen extends StatefulWidget {
  const AnciennePlaqueScreen({super.key});

  @override
  State<AnciennePlaqueScreen> createState() => _AnciennePlaqueScreenState();
}

class _AnciennePlaqueScreenState extends State<AnciennePlaqueScreen> {
  final _immatController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _immatController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _immatController.dispose();
    super.dispose();
  }

  bool get _saisieValide {
    final len = _immatController.text
        .replaceAll(RegExp(r'[^A-Za-z0-9]'), '')
        .length;
    return len == 8 || len == 9;
  }

  Future<void> _genererPdf() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Le formatter a déjà inséré les espaces, on les remplace par '_'
      // pour correspondre au nom de fichier '_.jpg' dans les assets
      final immatFormate = _immatController.text.toLowerCase().replaceAll(' ', '_');

      final bitmap = await generateAnciennePlaqueBitmap(immatFormate);
      final pdfBytes = await generatePdfFromBitmap(bitmap);

      if (!mounted) return;

      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: 'plaque_ancienne_${immatFormate.toUpperCase().replaceAll('_', '-')}.pdf',
      );
    } catch (e) {
      if (mounted) _showError('Erreur lors de la génération : $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  @override
  Widget build(BuildContext context) {
    const accentColor = Color(0xFFF97163);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Ancienne Plaque'),
        backgroundColor: accentColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Aperçu dynamique de la plaque
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AnciennePlaquePreview(
                    immat: _immatController.text,
                  ),
                ),
                const SizedBox(height: 16),

                // Aide sur les formats
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: accentColor.withValues(alpha: 0.3)),
                  ),
                  child: const Text(
                    'Formats acceptés :\n'
                    '• 8 caractères : ABC123AB  →  ABC 123 AB\n'
                    '• 9 caractères : ABCD123AB  →  ABCD 123 AB',
                    style: TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                ),
                const SizedBox(height: 24),

                // Champ numéro d'immatriculation
                TextFormField(
                  controller: _immatController,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [AncienneImmatFormatter()],
                  decoration: _inputDecoration(
                    'Numéro de plaque',
                    'Ex : ABC 123 AB',
                    accentColor,
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Champ obligatoire';
                    final cleaned = v.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
                    if (cleaned.length != 8 && cleaned.length != 9) {
                      return 'Format incomplet (ex : ABC 123 AB ou ABCD 123 AB)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),

                // Bouton Générer
                SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading || !_saisieValide ? null : _genererPdf,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.picture_as_pdf),
                    label: Text(_isLoading ? 'Génération…' : 'Générer le PDF'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: Colors.white,
                      textStyle: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

InputDecoration _inputDecoration(String label, String hint, Color color) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    labelStyle: TextStyle(color: color),
    focusedBorder: OutlineInputBorder(
      borderSide: BorderSide(color: color, width: 2),
      borderRadius: BorderRadius.circular(12),
    ),
    enabledBorder: OutlineInputBorder(
      borderSide: BorderSide(color: color.withValues(alpha: 0.4)),
      borderRadius: BorderRadius.circular(12),
    ),
    errorBorder: OutlineInputBorder(
      borderSide: const BorderSide(color: Colors.redAccent),
      borderRadius: BorderRadius.circular(12),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderSide: const BorderSide(color: Colors.redAccent, width: 2),
      borderRadius: BorderRadius.circular(12),
    ),
    filled: true,
    fillColor: Colors.grey.shade50,
  );
}
