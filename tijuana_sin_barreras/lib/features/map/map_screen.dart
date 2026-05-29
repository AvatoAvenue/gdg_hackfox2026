import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/models/barrier_report.dart';
import '../../core/services/firebase_service.dart';
import '../../core/services/tts_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _mapController = Completer<GoogleMapController>();
  Set<Marker> _markers = {};
  BarrierReport? _selectedBarrier;
  LatLng _center = const LatLng(AppConstants.tijuanaLat, AppConstants.tijuanaLng);

  @override
  void initState() {
    super.initState();
    _goToUserLocation();
  }

  Future<void> _goToUserLocation() async {
    final permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

    final pos = await Geolocator.getCurrentPosition();
    final userLatLng = LatLng(pos.latitude, pos.longitude);
    setState(() => _center = userLatLng);

    final ctrl = await _mapController.future;
    ctrl.animateCamera(CameraUpdate.newLatLng(userLatLng));
  }

  Set<Marker> _buildMarkers(List<BarrierReport> barriers) {
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
            _markers = _buildMarkers(snap.data!);
          }

          return Stack(
            children: [
              GoogleMap(
                initialCameraPosition: CameraPosition(target: _center, zoom: 14),
                onMapCreated: _mapController.complete,
                markers: _markers,
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, '/report'),
        icon: const Icon(Icons.add_location_alt),
        label: const Text('Reportar'),
        backgroundColor: AppColors.danger,
        foregroundColor: Colors.white,
        tooltip: 'Reportar una barrera de accesibilidad',
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
          ],
        ),
      ),
    );
  }
}

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
    final text = _buildSpeechText(widget.barrier);
    await tts.speak(text);
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
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 16, offset: Offset(0, -2))],
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
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                onPressed: _toggleSpeak,
                icon: Icon(_speaking ? Icons.stop_circle_outlined : Icons.volume_up_outlined),
                color: AppColors.primary,
                tooltip: _speaking ? 'Detener lectura' : 'Escuchar barrera',
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
            Text(widget.barrier.description, style: const TextStyle(color: AppColors.muted, fontSize: 14)),
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
        color: AppColors.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.auto_awesome, color: AppColors.primary, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              analysis,
              style: const TextStyle(fontSize: 12, color: AppColors.onSurface, height: 1.4),
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
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
    );
  }
}
