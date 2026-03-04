import 'package:flutter/material.dart';
import 'nouvelle_plaque_screen.dart';
import 'ancienne_plaque_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Titre de l'appli
              const Text(
                'PLAcreator',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Générateur de plaques d\'immatriculation',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.black54),
              ),
              const SizedBox(height: 56),

              // Bouton Nouvelle Plaque
              _PlaqueButton(
                label: 'Nouvelle Plaque',
                subtitle: 'Format SIV — ex: AB-123-CD',
                imagePath: 'assets/plaque_vierge.jpg',
                color: const Color(0xFF6F90D6), // bleu foncé
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const NouvellePlaqueScreen(),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Bouton Ancienne Plaque
              _PlaqueButton(
                label: 'Ancienne Plaque',
                subtitle: 'Format FNI — ex: ABC 123 AB',
                imagePath: 'assets/plaque_ancien_vierge.jpg',
                color: const Color(0xFFF97163), // rose
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AnciennePlaqueScreen(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bouton avec aperçu de la plaque et label
class _PlaqueButton extends StatelessWidget {
  const _PlaqueButton({
    required this.label,
    required this.subtitle,
    required this.imagePath,
    required this.color,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final String imagePath;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: color, width: 2.5),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Aperçu de la plaque vierge
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  imagePath,
                  height: 70,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Colors.black45),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
