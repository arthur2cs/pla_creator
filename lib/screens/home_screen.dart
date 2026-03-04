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
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _PlaqueButton(
                label: 'Nouvelle Plaque',
                imagePath: 'assets/plaque_vierge.jpg',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const NouvellePlaqueScreen(),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              _PlaqueButton(
                label: 'Ancienne Plaque',
                imagePath: 'assets/plaque_ancien_vierge.jpg',
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

/// Plaque cliquable : image pleine largeur avec le label superposé en bold au centre.
class _PlaqueButton extends StatelessWidget {
  const _PlaqueButton({
    required this.label,
    required this.imagePath,
    required this.onTap,
  });

  final String label;
  final String imagePath;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10.0),
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Image pleine largeur, proportions préservées
            Image.asset(
              imagePath,
              width: double.infinity,
              fit: BoxFit.fitWidth,
            ),
            // Texte superposé sur la plaque
            Text(
              label,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
