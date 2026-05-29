import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../shared/widgets/app_logo.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceNeutral,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _MainBar(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 40),
                    _buildHeroText(context),
                    const SizedBox(height: 40),
                    _buildActionCards(context),
                    const SizedBox(height: 32),
                    _buildFooter(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroText(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Movilidad\naccesible para todos',
          style: Theme.of(context)
              .textTheme
              .headlineLarge
              ?.copyWith(height: 1, fontSize: 42, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        Text(
          'Navega Tijuana sin obstáculos. Reporta barreras y ayuda a tu comunidad.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppColors.muted,
              ),
        ),
      ],
    );
  }

  Widget _buildActionCards(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _ActionCard(
            icon: Icons.map_rounded,
            color: AppColors.brandActive,
            title: 'Ver mapa accesible',
            subtitle: 'Explora barreras reportadas cerca de ti',
            onTap: () => Navigator.pushNamed(context, '/map'),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _ActionCard(
            icon: Icons.alt_route_rounded,
            color: AppColors.success,
            title: 'Calcular ruta accesible',
            subtitle: 'Encuentra el camino más seguro para llegar',
            onTap: () => Navigator.pushNamed(context, '/route'),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _ActionCard(
            icon: Icons.report_problem_rounded,
            color: AppColors.error,
            title: 'Reportar barrera',
            subtitle: 'Marca obstáculos y ayuda a otros ciudadanos',
            onTap: () => Navigator.pushNamed(context, '/report'),
          ),
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

// ─────────────────────────────────────────────────────────────────────────────
// Main bar
// ─────────────────────────────────────────────────────────────────────────────
class _MainBar extends StatelessWidget {
  const _MainBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.darkDeep,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Brand ────────────────────────────────────────────────────────
          const AppLogo(size: 38, tint: AppColors.brandPassive),
          const SizedBox(width: 12),
          Text(
            'Tijuana Sin Barreras',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.brandPassive,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
          ),

          const SizedBox(width: 970),

          // ── Nav items ────────────────────────────────────────────────────
          const _NavItem(
            label: 'Mapa',
            popupTitle: 'Ver mapa accesible',
            popupBody:
                'Explora barreras reportadas\ncerca de ti en tiempo real.',
            icon: Icons.map_rounded,
            accentColor: AppColors.brandActive,
          ),
          const _NavItem(
            label: 'Ruta',
            popupTitle: 'Calcular ruta accesible',
            popupBody:
                'Encuentra el camino más\nseguro para llegar a tu destino.',
            icon: Icons.alt_route_rounded,
            accentColor: AppColors.success,
          ),
          const _NavItem(
            label: 'Reportar',
            popupTitle: 'Reportar barrera',
            popupBody: 'Marca obstáculos y ayuda\na otros ciudadanos.',
            icon: Icons.report_problem_rounded,
            accentColor: AppColors.error,
          ),

          const Spacer(),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Nav item with hover pop-in popup (no navigation)
// ─────────────────────────────────────────────────────────────────────────────
class _NavItem extends StatefulWidget {
  final String label;
  final String popupTitle;
  final String popupBody;
  final IconData icon;
  final Color accentColor;

  const _NavItem({
    required this.label,
    required this.popupTitle,
    required this.popupBody,
    required this.icon,
    required this.accentColor,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  final _portalController = OverlayPortalController();
  final _layerLink = LayerLink();
  bool _hovered = false;

  void _onEnter() {
    setState(() => _hovered = true);
    _portalController.show();
  }

  void _onExit() {
    setState(() => _hovered = false);
    // Small delay lets the pop-out feel intentional before hiding
    Future.delayed(const Duration(milliseconds: 120), () {
      if (!_hovered && mounted) _portalController.hide();
    });
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: OverlayPortal(
        controller: _portalController,
        overlayChildBuilder: (_) => _NavPopup(
          layerLink: _layerLink,
          icon: widget.icon,
          title: widget.popupTitle,
          body: widget.popupBody,
          accentColor: widget.accentColor,
        ),
        child: MouseRegion(
          onEnter: (_) => _onEnter(),
          onExit: (_) => _onExit(),
          cursor: SystemMouseCursors.click,
          child: AnimatedScale(
            scale: _hovered ? 0.95 : 1.0,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutBack,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeInOut,
              padding: const EdgeInsets.symmetric(horizontal: 45, vertical: 8),
              decoration: BoxDecoration(
                color: _hovered
                    ? AppColors.darkDeep.withValues(alpha: 0.16)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _hovered ? AppColors.brandPassive : Colors.transparent,
                  width: 1.5,
                ),
                boxShadow: _hovered
                    ? [
                        BoxShadow(
                          color: AppColors.brandPassive.withValues(alpha: 0.25),
                          blurRadius: 22,
                          spreadRadius: 3,
                        ),
                      ]
                    : [],
              ),
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 160),
                style: GoogleFonts.lexend(
                  fontSize: 14,
                  fontWeight: _hovered ? FontWeight.w500 : FontWeight.w500,
                  color: _hovered ? Colors.white : AppColors.brandPassive,
                ),
                child: Text(widget.label),
              ),
            ), // cierra AnimatedContainer
          ), // cierra AnimatedScale
        ), // cierra MouseRegion
      ), // cierra OverlayPortal
    ); // cierra CompositedTransformTarget
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Popup card — positioned below the nav item via CompositedTransformFollower
// ─────────────────────────────────────────────────────────────────────────────
class _NavPopup extends StatelessWidget {
  final LayerLink layerLink;
  final IconData icon;
  final String title;
  final String body;
  final Color accentColor;

  const _NavPopup({
    required this.layerLink,
    required this.icon,
    required this.title,
    required this.body,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return CompositedTransformFollower(
      link: layerLink,
      showWhenUnlinked: false,
      targetAnchor: Alignment.bottomLeft,
      followerAnchor: Alignment.topLeft,
      offset: const Offset(-8, 8),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutBack,
        builder: (_, v, child) => Opacity(
          opacity: v.clamp(0.0, 1.0),
          child: Transform.scale(
            scale: 0.88 + 0.12 * v,
            alignment: Alignment.topLeft,
            child: child,
          ),
        ),
        // IntrinsicWidth shrinks the popup to its content width.
        // Align + IntrinsicWidth together prevent the Material from
        // expanding to fill the full-screen Overlay.
        child: Align(
          alignment: Alignment.topLeft,
          child: IntrinsicWidth(
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.darkMid,
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: accentColor.withValues(alpha: 0.40)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.28),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(icon, color: accentColor, size: 15),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          body,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.65),
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Action card
// ─────────────────────────────────────────────────────────────────────────────
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
        color: AppColors.darkMid,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border.all(
                color: AppColors.brandPassive.withValues(alpha: 0.25),
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 26),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.surfacePositive,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color:
                            AppColors.surfacePositive.withValues(alpha: 0.65),
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
