import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../shared/widgets/app_logo.dart';
import 'package:provider/provider.dart';
import '../../core/services/firebase_service.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceNeutral,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Barra superior full-width (sin el padding lateral del cuerpo).
            const _MainBar(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeroText(context),
                    const SizedBox(height: 40),
                    _buildActionCards(context),
                    const SizedBox(height: 40),
                    _buildFooter(),
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
    final cards = <Widget>[
      _ActionCard(
        icon: Icons.map_rounded,
        color: AppColors.brandActive,
        title: 'Ver mapa accesible',
        subtitle: 'Explora barreras reportadas cerca de ti',
        onTap: () => Navigator.pushNamed(context, '/map'),
      ),
      _ActionCard(
        icon: Icons.alt_route_rounded,
        color: AppColors.success,
        title: 'Calcular ruta accesible',
        subtitle: 'Encuentra el camino más seguro para llegar',
        onTap: () => Navigator.pushNamed(context, '/route'),
      ),
      _ActionCard(
        icon: Icons.report_problem_rounded,
        color: AppColors.error,
        title: 'Reportar barrera',
        subtitle: 'Marca obstáculos y ayuda a otros ciudadanos',
        onTap: () => _openReport(context),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        // En pantallas anchas: fila de 3 columnas. En móvil: apiladas.
        if (constraints.maxWidth >= 720) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                if (i > 0) const SizedBox(width: 14),
                Expanded(child: cards[i]),
              ],
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < cards.length; i++) ...[
              if (i > 0) const SizedBox(height: 14),
              cards[i],
            ],
          ],
        );
      },
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

/// Abre el reporte de barrera, exigiendo sesión primero. Función de archivo
/// para que la usen tanto las tarjetas de acción como el nav item "Reportar".
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

// ─────────────────────────────────────────────────────────────────────────────
// Main bar
// ─────────────────────────────────────────────────────────────────────────────
class _MainBar extends StatefulWidget {
  const _MainBar();

  @override
  State<_MainBar> createState() => _MainBarState();
}

class _MainBarState extends State<_MainBar> {
  int _hoveredIndex = -1;

  // Dock magnification: hovered item → 1.28×, direct neighbor → ~1.09×, rest → 1.0×
  double _scaleFor(int i) {
    if (_hoveredIndex < 0) return 1.0;
    final dist = (i - _hoveredIndex).abs().toDouble();
    return 1.0 + 0.28 * (1.0 - dist / 1.5).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.darkDeep,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final showNav = constraints.maxWidth >= 820;

          final navDefs = [
            (
              label: 'Mapa',
              onTap: () => Navigator.pushNamed(context, '/map'),
              popupTitle: 'Ver mapa accesible',
              popupBody:
                  'Explora barreras reportadas\ncerca de ti en tiempo real.',
              icon: Icons.map_rounded,
              accentColor: AppColors.brandActive,
            ),
            (
              label: 'Ruta',
              onTap: () => Navigator.pushNamed(context, '/route'),
              popupTitle: 'Calcular ruta accesible',
              popupBody:
                  'Encuentra el camino más\nseguro para llegar a tu destino.',
              icon: Icons.alt_route_rounded,
              accentColor: AppColors.success,
            ),
            (
              label: 'Reportar',
              onTap: () => _openReport(context),
              popupTitle: 'Reportar barrera',
              popupBody: 'Marca obstáculos y ayuda\na otros ciudadanos.',
              icon: Icons.report_problem_rounded,
              accentColor: AppColors.error,
            ),
          ];

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── Brand ──────────────────────────────────────────────────
              const AppLogo(size: 56),
              const Spacer(),
              // ── Nav items with dock magnification ──────────────────────
              if (showNav) ...[
                for (int i = 0; i < navDefs.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  AnimatedScale(
                    scale: _scaleFor(i),
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    child: _NavItem(
                      label: navDefs[i].label,
                      onTap: navDefs[i].onTap,
                      popupTitle: navDefs[i].popupTitle,
                      popupBody: navDefs[i].popupBody,
                      icon: navDefs[i].icon,
                      accentColor: navDefs[i].accentColor,
                      onHoverChange: (hovered) => setState(() {
                        if (hovered) {
                          _hoveredIndex = i;
                        } else if (_hoveredIndex == i) {
                          _hoveredIndex = -1;
                        }
                      }),
                    ),
                  ),
                ],
                const SizedBox(width: 12),
              ],
              // ── Cuenta (login / perfil) ────────────────────────────────
              const _AuthButton(),
            ],
          );
        },
      ),
    );
  }
}

/// Botón de cuenta para la barra oscura: perfil si hay sesión, login si no.
class _AuthButton extends StatelessWidget {
  const _AuthButton();

  @override
  Widget build(BuildContext context) {
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
              color: AppColors.brandPassive,
              size: 28,
            ),
            tooltip: signedIn ? 'Mi perfil' : 'Iniciar sesión',
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Nav item with hover pop-in popup (no navigation)
// ─────────────────────────────────────────────────────────────────────────────
class _NavItem extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final String popupTitle;
  final String popupBody;
  final IconData icon;
  final Color accentColor;
  final ValueChanged<bool> onHoverChange;

  const _NavItem({
    required this.label,
    required this.onTap,
    required this.popupTitle,
    required this.popupBody,
    required this.icon,
    required this.accentColor,
    required this.onHoverChange,
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
    widget.onHoverChange(true);
    _portalController.show();
  }

  void _onExit() {
    setState(() => _hovered = false);
    widget.onHoverChange(false);
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
          child: GestureDetector(
            onTap: widget.onTap,
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
                  fontWeight: FontWeight.w500,
                  color: _hovered ? Colors.white : AppColors.brandPassive,
                ),
                child: Text(widget.label),
              ),
            ), // cierra AnimatedContainer
          ), // cierra GestureDetector
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
                  border: Border.all(color: accentColor.withOpacity(0.40)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.28),
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
                            color: Colors.white.withOpacity(0.65),
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
                color: AppColors.brandPassive.withOpacity(0.25),
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
                    color: color.withOpacity(0.18),
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
                        color: AppColors.surfacePositive.withOpacity(0.65),
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
