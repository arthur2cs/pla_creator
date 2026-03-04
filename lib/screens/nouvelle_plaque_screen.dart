import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../utils/plaque_generator.dart';
import '../utils/constantes.dart';

class NouvellePlaqueScreen extends StatefulWidget {
  const NouvellePlaqueScreen({super.key});

  @override
  State<NouvellePlaqueScreen> createState() => _NouvellePlaqueScreenState();
}

class _NouvellePlaqueScreenState extends State<NouvellePlaqueScreen> {
  final _immatController = TextEditingController();
  final _deptController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void dispose() {
    _immatController.dispose();
    _deptController.dispose();
    super.dispose();
  }

  Future<void> _genererPdf() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final immatFormate = formatNouvelleImmatriculation(_immatController.text);
      final dept = _deptController.text.trim().toUpperCase();

      if (immatFormate.isEmpty) {
        _showError('Le numéro de plaque doit contenir exactement 7 caractères alphanumériques (ex: AB123CD).');
        return;
      }

      final bitmap = await generateNovellePlaqueBitmap(immatFormate, dept);
      final pdfBytes = await generatePdfFromBitmap(bitmap);

      if (!mounted) return;

      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: 'plaque_${immatFormate.toUpperCase()}.pdf',
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
    const accentColor = Color(0xFF6F90D6);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Nouvelle Plaque'),
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
                // Aperçu plaque vierge
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    'assets/plaque_vierge.jpg',
                    height: 80,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 32),

                // Champ numéro d'immatriculation
                TextFormField(
                  controller: _immatController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: _inputDecoration(
                    'Numéro de plaque',
                    'Ex : AB123CD',
                    accentColor,
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Champ obligatoire';
                    final cleaned = v.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
                    if (cleaned.length != 7) return '7 caractères alphanumériques requis';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Champ numéro de département
                TextFormField(
                  controller: _deptController,
                  keyboardType: TextInputType.text,
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 2,
                  decoration: _inputDecoration(
                    'Numéro de département',
                    'Ex : 59',
                    accentColor,
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Champ obligatoire';
                    final dept = v.trim().toUpperCase();
                    if (!departementRegion.containsKey(dept)) {
                      return 'Département inconnu (ex: 59, 75, 2A…)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),

                // Bouton Générer
                SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _genererPdf,
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
