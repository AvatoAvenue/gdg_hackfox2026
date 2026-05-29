import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/firebase_service.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),
              _buildHeader(context),
              const SizedBox(height: 40),
              _buildHeroText(context),
              const SizedBox(height: 40),
              _buildActionCards(context),
              const Spacer(),
              _buildFooter(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.accessible_forward, color: Colors.white, size: 30),
        ),
        const SizedBox(width: 14),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tijuana',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.primary),
            ),
            Text(
              'Sin Barreras',
              style: TextStyle(fontSize: 13, color: AppColors.muted, letterSpacing: 0.5),
            ),
          ],
        ),
        const Spacer(),
        _buildAuthButton(context),
      ],
    );
  }

  /// Botón de cuenta: muestra avatar/perfil si hay sesión, o icono de login.
  Widget _buildAuthButton(BuildContext context) {
    final firebase = context.read<FirebaseService>();
    return StreamBuilder<User?>(
      stream: firebase.authState,
      builder: (context, snapshot) {
        final signedIn = snapshot.data != null;
        return Semantics(
          label: signedIn ? 'Mi perfil' : 'Iniciar sesión',
          button: true,
          child: IconButton(
            onPressed: () => Navigator.pushNamed(
              context,
              signedIn ? '/profile' : '/login',
            ),
            icon: Icon(
              signedIn ? Icons.account_circle : Icons.login,
              color: AppColors.primary,
              size: 30,
            ),
            tooltip: signedIn ? 'Mi perfil' : 'Iniciar sesión',
          ),
        );
      },
    );
  }

  /// Abre el reporte de barrera, exigiendo sesión primero.
  Future<void> _openReport(BuildContext context) async {
    final firebase = context.read<FirebaseService>();
    if (firebase.isSignedIn) {
      Navigator.pushNamed(context, '/report');
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Inicia sesión para reportar una barrera.')),
    );
    final loggedIn = await Navigator.pushNamed(context, '/login');
    if (loggedIn == true && context.mounted) {
      Navigator.pushNamed(context, '/report');
    }
  }

  Widget _buildHeroText(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Movilidad\naccesible para\ntodos',
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(height: 1.2),
        ),
        const SizedBox(height: 12),
        Text(
          'Navega Tijuana sin obstáculos. Reporta barreras y ayuda a tu comunidad.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.muted),
        ),
      ],
    );
  }

  Widget _buildActionCards(BuildContext context) {
    return Column(
      children: [
        _ActionCard(
          icon: Icons.map_rounded,
          color: AppColors.primary,
          title: 'Ver mapa accesible',
          subtitle: 'Explora barreras reportadas cerca de ti',
          onTap: () => Navigator.pushNamed(context, '/map'),
        ),
        const SizedBox(height: 14),
        _ActionCard(
          icon: Icons.alt_route_rounded,
          color: AppColors.secondary,
          title: 'Calcular ruta accesible',
          subtitle: 'Encuentra el camino más seguro para llegar',
          onTap: () => Navigator.pushNamed(context, '/route'),
        ),
        const SizedBox(height: 14),
        _ActionCard(
          icon: Icons.report_problem_rounded,
          color: AppColors.danger,
          title: 'Reportar barrera',
          subtitle: 'Marca obstáculos y ayuda a otros ciudadanos',
          onTap: () => _openReport(context),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return const Center(
      child: Text(
        'Chackethon Developers · HackFox 2026',
        style: TextStyle(fontSize: 12, color: AppColors.muted),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: title,
      button: true,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade200),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: const TextStyle(fontSize: 13, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: color.withOpacity(0.6)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
