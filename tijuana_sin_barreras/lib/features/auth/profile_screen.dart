import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/user_profile.dart';
import '../../core/services/firebase_service.dart';

/// Pantalla de perfil del usuario autenticado.
/// Muestra datos del perfil, el rol (ciudadano/moderador) y permite cerrar sesión.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final firebase = context.read<FirebaseService>();

    return Scaffold(
      backgroundColor: AppColors.surfaceNeutral,
      appBar: AppBar(
        title: const Text('Mi perfil'),
      ),
      body: StreamBuilder<UserProfile?>(
        stream: firebase.watchCurrentProfile(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final profile = snapshot.data;
          if (profile == null) {
            return _buildSignedOut(context, firebase);
          }
          return _buildProfile(context, firebase, profile);
        },
      ),
    );
  }

  Widget _buildSignedOut(BuildContext context, FirebaseService firebase) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.person_off_outlined, size: 48, color: AppColors.brandPassive),
            const SizedBox(height: 16),
            Text(
              'No has iniciado sesión',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(color: AppColors.darkDeep),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
              child: const Text('Iniciar sesión'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfile(
    BuildContext context,
    FirebaseService firebase,
    UserProfile profile,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          _buildAvatar(profile),
          const SizedBox(height: 16),
          Center(
            child: Text(
              profile.displayName,
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(color: AppColors.darkDeep),
            ),
          ),
          if (profile.email != null) ...[
            const SizedBox(height: 4),
            Center(
              child: Text(
                profile.email!,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.darkMid),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Center(child: _buildRoleBadge(profile)),
          const SizedBox(height: 32),
          _buildInfoTile(
            context: context,
            icon: Icons.calendar_today_outlined,
            label: 'Miembro desde',
            value: _formatDate(profile.createdAt),
          ),
          _buildInfoTile(
            context: context,
            icon: Icons.shield_outlined,
            label: 'Rol',
            value: profile.isModerator ? 'Moderador' : 'Ciudadano',
          ),
          const SizedBox(height: 32),
          OutlinedButton.icon(
            onPressed: () => _confirmSignOut(context, firebase),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 56),
              foregroundColor: AppColors.error,
              side: const BorderSide(color: AppColors.error),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.logout),
            label: const Text(
              'Cerrar sesión',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(UserProfile profile) {
    return Center(
      child: CircleAvatar(
        radius: 48,
        backgroundColor: AppColors.brandActive,
        backgroundImage:
            profile.photoUrl != null ? NetworkImage(profile.photoUrl!) : null,
        child: profile.photoUrl == null
            ? Text(
                _initials(profile.displayName),
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildRoleBadge(UserProfile profile) {
    final isMod = profile.isModerator;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfacePositive,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isMod ? Icons.verified : Icons.person,
            size: 16,
            color: AppColors.darkDeep,
          ),
          const SizedBox(width: 6),
          Text(
            isMod ? 'Moderador' : 'Ciudadano',
            style: const TextStyle(
              color: AppColors.darkDeep,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.darkMid,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: AppColors.brandPassive.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.brandPassive, size: 22),
          const SizedBox(width: 14),
          Text(
            label,
            style: const TextStyle(
                color: AppColors.surfacePositive, fontSize: 14),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: AppColors.surfacePositive,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmSignOut(
    BuildContext context,
    FirebaseService firebase,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Seguro que quieres salir de tu cuenta?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Salir'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    await firebase.signOut();
    if (context.mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
    }
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  String _formatDate(DateTime date) {
    const months = [
      'ene', 'feb', 'mar', 'abr', 'may', 'jun',
      'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
