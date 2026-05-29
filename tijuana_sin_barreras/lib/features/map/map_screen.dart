import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/models/barrier_report.dart';
import '../../core/models/emergency_alert.dart';
import '../../core/services/firebase_service.dart';
import '../../core/services/geo_utils.dart';
import '../../core/services/tts_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen>
    with SingleTickerProviderStateMixin {
  final _mapController = Completer<GoogleMapController>();
  Set<Marker> _barrierMarkers = {};
  Set<Marker> _emergencyMarkers = {};
  BarrierReport? _selectedBarrier;
  LatLng _center =
      const LatLng(AppConstants.tijuanaLat, AppConstants.tijuanaLng);
  LatLng? _userPosition;

  // SOS
  String? _activeAlertId;
  bool _sendingAlert = false;
  bool _dialogVisible = false;
  final Set<String> _seenAlertIds = {};
  StreamSubscription<List<EmergencyAlert>>? _alertsSub;

  // Animaciones del botón SOS
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;   // activo: escala 0.92→1.0
  late Animation<double> _breatheAnim; // inactivo: respiro sutil 0.977→1.0

  @override
  void initState() {
    super.initState();
    _goToUserLocation();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _breatheAnim = Tween<double>(begin: 0.977, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _listenToEmergencyAlerts());
  }

  @override
  void dispose() {
    _alertsSub?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Stream de alertas SOS
  // ---------------------------------------------------------------------------

  void _listenToEmergencyAlerts() {
    if (!mounted) return;
    final firebase = context.read<FirebaseService>();
    _alertsSub = firebase.getActiveEmergencyAlerts().listen((alerts) {
      if (!mounted) return;

      final markers = alerts
          .map((a) => Marker(
                markerId: MarkerId('sos_${a.id}'),
                position: LatLng(a.lat, a.lng),
                icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueRed),
                infoWindow: InfoWindow(
                  title: '🚨 Emergencia SOS',
                  snippet: a.userName != null
                      ? 'Reportado por ${a.userName}'
                      : 'Persona necesita ayuda',
                ),
              ))
          .toSet();

      setState(() => _emergencyMarkers = markers);

      // Detección de alertas cercanas (solo las de otros usuarios)
      final myId = firebase.currentUserId;
      if (_userPosition == null) return;
      for (final alert in alerts) {
        if (alert.userId == myId) continue;
        if (_seenAlertIds.contains(alert.id)) continue;
        final dist = GeoUtils.haversineMeters(
          _userPosition!,
          LatLng(alert.lat, alert.lng),
        );
        if (dist <= 500) {
          _seenAlertIds.add(alert.id);
          _showNearbyEmergencyDialog(alert, dist.round());
        }
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Ubicación del usuario
  // ---------------------------------------------------------------------------

  Future<void> _goToUserLocation() async {
    final permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

    final pos = await Geolocator.getCurrentPosition();
    final latLng = LatLng(pos.latitude, pos.longitude);
    if (mounted) {
      setState(() {
        _center = latLng;
        _userPosition = latLng;
      });
    }
    final ctrl = await _mapController.future;
    ctrl.animateCamera(CameraUpdate.newLatLng(latLng));
  }

  // ---------------------------------------------------------------------------
  // Marcadores de barreras
  // ---------------------------------------------------------------------------

  Set<Marker> _buildBarrierMarkers(List<BarrierReport> barriers) {
    return barriers.map((b) {
      return Marker(
        markerId: MarkerId(b.id),
        position: LatLng(b.lat, b.lng),
        icon: BitmapDescriptor.defaultMarkerWithHue(_hueFor(b)),
        infoWindow: InfoWindow(title: b.type),
        onTap: () => setState(() => _selectedBarrier = b),
      );
    }).toSet();
  }

  double _hueFor(BarrierReport b) {
    if (b.status == 'resolved') return BitmapDescriptor.hueGreen;
    return switch (b.type) {
      'Rampa faltante' => BitmapDescriptor.hueOrange,
      'Banqueta dañada' => BitmapDescriptor.hueRed,
      'Semáforo sin sonido' => BitmapDescriptor.hueViolet,
      _ => BitmapDescriptor.hueYellow,
    };
  }

  // ---------------------------------------------------------------------------
  // Lógica SOS
  // ---------------------------------------------------------------------------

  Future<void> _confirmSendAlert() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.sos, color: AppColors.danger, size: 28),
            SizedBox(width: 8),
            Text('Enviar Alerta SOS'),
          ],
        ),
        content: const Text(
          '¿Necesitas ayuda de emergencia?\n\n'
          'Las personas con la app cercanas a tu ubicación serán notificadas de inmediato.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            child: const Text('Enviar SOS'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    await _sendEmergencyAlert();
  }

  Future<void> _sendEmergencyAlert() async {
    // Capturar servicios y messenger ANTES de cualquier await
    final firebase = context.read<FirebaseService>();
    final tts = context.read<TtsService>();
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _sendingAlert = true);
    try {
      final pos = await Geolocator.getCurrentPosition();
      final profile = await firebase.getCurrentProfile();
      final id = await firebase.sendEmergencyAlert(
        lat: pos.latitude,
        lng: pos.longitude,
        userName: profile?.displayName,
      );
      if (!mounted) return;
      setState(() {
        _activeAlertId = id;
        _sendingAlert = false;
        _userPosition = LatLng(pos.latitude, pos.longitude);
      });
      tts.speak(
        'Alerta de emergencia enviada. Las personas cercanas han sido notificadas.',
      );
      messenger.showSnackBar(
        const SnackBar(
          content:
              Text('🚨 Alerta SOS enviada. Personas cercanas notificadas.'),
          backgroundColor: AppColors.danger,
          duration: Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _sendingAlert = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Error al enviar alerta: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  Future<void> _cancelEmergencyAlert() async {
    if (_activeAlertId == null) return;
    final firebase = context.read<FirebaseService>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await firebase.cancelEmergencyAlert(_activeAlertId!);
      if (!mounted) return;
      setState(() => _activeAlertId = null);
      messenger.showSnackBar(
        const SnackBar(content: Text('Alerta SOS cancelada.')),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
            content: Text('Error al cancelar: $e'),
            backgroundColor: AppColors.danger),
      );
    }
  }

  void _showNearbyEmergencyDialog(EmergencyAlert alert, int distMeters) {
    // Evitar apilar múltiples diálogos si llegan varias alertas simultáneas.
    if (_dialogVisible) return;
    _dialogVisible = true;

    context.read<TtsService>().speak(
          'Alerta de emergencia. '
          'Hay una persona que necesita ayuda a $distMeters metros de ti.',
        );

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_rounded, color: AppColors.danger, size: 28),
            SizedBox(width: 8),
            Text('¡Emergencia cercana!'),
          ],
        ),
        content: Text(
          'Hay una persona que necesita ayuda a $distMeters m de tu ubicación.\n\n'
          '¿Puedes acercarte a ayudar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('No puedo'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _moveCameraToAlert(alert);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            child: const Text('Ir a ayudar'),
          ),
        ],
      ),
    ).whenComplete(() => _dialogVisible = false);
  }

  Future<void> _moveCameraToAlert(EmergencyAlert alert) async {
    try {
      final ctrl = await _mapController.future;
      await ctrl.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(alert.lat, alert.lng), 17),
      );
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final firebase = context.read<FirebaseService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa de Barreras'),
        backgroundColor: AppColors.primary,
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            tooltip: 'Mi ubicación',
            onPressed: _goToUserLocation,
          ),
        ],
      ),
      body: StreamBuilder<List<BarrierReport>>(
        stream: firebase.getBarriers(),
        builder: (ctx, snap) {
          if (snap.hasData) {
            _barrierMarkers = _buildBarrierMarkers(snap.data!);
          }

          return Stack(
            children: [
              GoogleMap(
                initialCameraPosition:
                    CameraPosition(target: _center, zoom: 14),
                onMapCreated: _mapController.complete,
                markers: {..._barrierMarkers, ..._emergencyMarkers},
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                onTap: (_) => setState(() => _selectedBarrier = null),
              ),
              _buildLegend(),
              if (snap.connectionState == ConnectionState.waiting)
                const Center(child: CircularProgressIndicator()),
              if (_selectedBarrier != null)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: _BarrierSheet(
                    barrier: _selectedBarrier!,
                    onClose: () => setState(() => _selectedBarrier = null),
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _buildSosButton(),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'report',
            onPressed: () => Navigator.pushNamed(context, '/report'),
            icon: const Icon(Icons.add_location_alt),
            label: const Text('Reportar'),
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            tooltip: 'Reportar una barrera de accesibilidad',
          ),
        ],
      ),
    );
  }

  Widget _buildSosButton() {
    final isActive = _activeAlertId != null;

    // Accesibilidad para daltonismo: el estado se comunica por
    // FORMA del ícono (▲ vs ✕), TEXTO y ANIMACIÓN, no solo por color.
    return AnimatedBuilder(
      animation: isActive ? _pulseAnim : _breatheAnim,
      builder: (context, child) => Transform.scale(
        scale: isActive ? _pulseAnim.value : _breatheAnim.value,
        child: child,
      ),
      child: Semantics(
        label: isActive
            ? 'Cancelar alerta de emergencia activa'
            : 'Botón SOS: pedir ayuda de emergencia',
        button: true,
        child: GestureDetector(
          onTap: isActive
              ? _cancelEmergencyAlert
              : (_sendingAlert ? null : _confirmSendAlert),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeInOut,
            constraints: const BoxConstraints(minWidth: 165),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
            decoration: BoxDecoration(
              // Gradiente naranja-ámbar (distinguible en protanopia/deuteranopia)
              // Estado activo → ámbar; inactivo → naranja profundo
              gradient: LinearGradient(
                colors: isActive
                    ? [const Color(0xFFFFB300), const Color(0xFFFF8F00)]
                    : [const Color(0xFFFF6D00), const Color(0xFFE64A19)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(32),
              // Borde blanco grueso: legible sin visión del color
              border: Border.all(color: Colors.white, width: 3.5),
              boxShadow: [
                BoxShadow(
                  color: (isActive
                          ? const Color(0xFFFFB300)
                          : const Color(0xFFFF6D00))
                      .withValues(alpha: 0.55),
                  blurRadius: 18,
                  spreadRadius: 2,
                  offset: const Offset(0, 4),
                ),
                const BoxShadow(
                  color: Colors.black26,
                  blurRadius: 6,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Ícono cambia de FORMA según el estado (no solo de color)
                // ▲ triángulo de advertencia → inactivo (pedir ayuda)
                // ✕ círculo con X       → activo   (cancelar)
                _sendingAlert
                    ? const SizedBox(
                        width: 30,
                        height: 30,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5),
                      )
                    : Icon(
                        isActive
                            ? Icons.cancel_outlined   // ✕  forma clara
                            : Icons.warning_rounded,  // ▲  forma clara
                        color: Colors.white,
                        size: 32,
                      ),
                const SizedBox(width: 11),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Texto principal en mayúsculas + espaciado → legible sin color
                    Text(
                      isActive ? 'CANCELAR' : 'SOS',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                        letterSpacing: 3.0,
                        height: 1.1,
                      ),
                    ),
                    Text(
                      isActive
                          ? 'Detener alerta'
                          : (_sendingAlert ? 'Enviando...' : 'Pedir ayuda'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.3,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return Positioned(
      top: 12,
      right: 12,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _LegendRow(color: Colors.orange, label: 'Rampa faltante'),
            _LegendRow(color: Colors.red, label: 'Banqueta dañada'),
            _LegendRow(color: Colors.purple, label: 'Semáforo'),
            _LegendRow(color: Colors.amber, label: 'Otro'),
            _LegendRow(color: Colors.green, label: 'Resuelto'),
            _LegendRow(color: AppColors.danger, label: '🚨 SOS'),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Widgets privados
// ---------------------------------------------------------------------------

class _LegendRow extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendRow({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }
}

class _BarrierSheet extends StatefulWidget {
  final BarrierReport barrier;
  final VoidCallback onClose;

  const _BarrierSheet({required this.barrier, required this.onClose});

  @override
  State<_BarrierSheet> createState() => _BarrierSheetState();
}

class _BarrierSheetState extends State<_BarrierSheet> {
  bool _speaking = false;

  Future<void> _toggleSpeak() async {
    final tts = context.read<TtsService>();
    if (_speaking) {
      await tts.stop();
      if (mounted) setState(() => _speaking = false);
      return;
    }
    setState(() => _speaking = true);
    await tts.speak(_buildSpeechText(widget.barrier));
    if (mounted) setState(() => _speaking = false);
  }

  String _buildSpeechText(BarrierReport b) {
    final parts = <String>['Barrera: ${b.type}'];
    if (b.description.isNotEmpty) parts.add(b.description);
    if (b.geminiAnalysis != null) {
      parts.add(b.geminiAnalysis!.replaceAll(RegExp(r'[\[\]→]'), ''));
    }
    parts.add(switch (b.status) {
      'resolved' => 'Estado: resuelto',
      'verified' => 'Estado: verificado',
      _ => 'Estado: pendiente de revisión',
    });
    return parts.join('. ');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 16, offset: Offset(0, -2))
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.barrier.type,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                onPressed: _toggleSpeak,
                icon: Icon(_speaking
                    ? Icons.stop_circle_outlined
                    : Icons.volume_up_outlined),
                color: AppColors.primary,
                tooltip:
                    _speaking ? 'Detener lectura' : 'Escuchar barrera',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 4),
              IconButton(
                onPressed: widget.onClose,
                icon: const Icon(Icons.close),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Cerrar',
              ),
            ],
          ),
          if (widget.barrier.description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(widget.barrier.description,
                style:
                    const TextStyle(color: AppColors.muted, fontSize: 14)),
          ],
          if (widget.barrier.photoBytes != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(
                widget.barrier.photoBytes!,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ],
          if (widget.barrier.geminiAnalysis != null) ...[
            const SizedBox(height: 12),
            _GeminiAnalysisBadge(analysis: widget.barrier.geminiAnalysis!),
          ],
          const SizedBox(height: 12),
          _StatusBadge(status: widget.barrier.status),
        ],
      ),
    );
  }
}

class _GeminiAnalysisBadge extends StatelessWidget {
  final String analysis;
  const _GeminiAnalysisBadge({required this.analysis});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.auto_awesome, color: AppColors.primary, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              analysis,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.onSurface, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'resolved' => ('Resuelto', AppColors.secondary),
      'verified' => ('Verificado', AppColors.primary),
      _ => ('Pendiente revisión', AppColors.warning),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600)),
    );
  }
}
