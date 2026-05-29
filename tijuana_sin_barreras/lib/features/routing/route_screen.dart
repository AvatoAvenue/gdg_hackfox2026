import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/models/barrier_report.dart';
import '../../core/models/place_models.dart';
import '../../core/models/route_result.dart';
import '../../core/services/firebase_service.dart';
import '../../core/services/maps_service.dart';
import '../../core/services/tts_service.dart';
import '../../shared/widgets/place_search_field.dart';

class RouteScreen extends StatefulWidget {
  const RouteScreen({super.key});

  @override
  State<RouteScreen> createState() => _RouteScreenState();
}

class _RouteScreenState extends State<RouteScreen> {
  final _originCtrl = TextEditingController();
  final _destCtrl = TextEditingController();
  final _mapController = Completer<GoogleMapController>();

  // Lugares resueltos (coords exactas) elegidos del autocompletado.
  PlaceResult? _originPlace;
  PlaceResult? _destPlace;

  Set<Polyline> _polylines = {};
  Set<Marker> _markers = {};
  Set<Circle> _circles = {};
  bool _loading = false;
  bool _speaking = false;
  bool _locatingOrigin = false;
  String? _routeInfo;
  String? _avoidInfo;
  String? _error;

  static const _tijuanaCenter =
      LatLng(AppConstants.tijuanaLat, AppConstants.tijuanaLng);

  MapsService get _maps => context.read<MapsService>();
  FirebaseService get _firebase => context.read<FirebaseService>();

  @override
  void initState() {
    super.initState();
    _useCurrentLocationAsOrigin();
  }

  /// Al abrir la pantalla, intenta fijar el origen en la ubicación actual del
  /// usuario. Pide permiso, obtiene las coordenadas y arma un [PlaceResult]
  /// directo (sin geocodificación) para alimentar el cálculo de ruta. Si el
  /// permiso se niega o falla, deja el campo vacío para que el usuario escriba.
  Future<void> _useCurrentLocationAsOrigin() async {
    setState(() => _locatingOrigin = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) setState(() => _locatingOrigin = false);
        return;
      }

      final pos = await Geolocator.getCurrentPosition();
      if (!mounted) return;

      // Si el usuario ya escribió o eligió un origen mientras se obtenía la
      // ubicación, respetamos su elección y no la sobrescribimos.
      if (_originPlace != null || _originCtrl.text.trim().isNotEmpty) {
        setState(() => _locatingOrigin = false);
        return;
      }

      final latLng = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _originPlace = PlaceResult(
          placeId: '',
          name: 'Mi ubicación actual',
          address: 'Ubicación actual',
          latLng: latLng,
        );
        _originCtrl.text = 'Mi ubicación actual';
        _locatingOrigin = false;
      });
    } catch (_) {
      if (mounted) setState(() => _locatingOrigin = false);
    }
  }

  /// Resuelve un extremo: usa el lugar elegido en el autocompletado; si el
  /// usuario escribió sin elegir de la lista, cae al Text Search.
  Future<PlaceResult?> _resolveEndpoint(
    PlaceResult? selected,
    String typed,
  ) async {
    if (selected != null) return selected;
    if (typed.trim().isEmpty) return null;
    return _maps.searchText('$typed Tijuana');
  }

  Future<void> _calcRoute() async {
    final originTyped = _originCtrl.text.trim();
    final destTyped = _destCtrl.text.trim();

    if ((_originPlace == null && originTyped.isEmpty) ||
        (_destPlace == null && destTyped.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor ingresa origen y destino')),
      );
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _routeInfo = null;
      _avoidInfo = null;
      _polylines = {};
      _markers = {};
      _circles = {};
    });

    try {
      final origin = await _resolveEndpoint(_originPlace, originTyped);
      final dest = await _resolveEndpoint(_destPlace, destTyped);

      if (origin == null || dest == null) {
        setState(() {
          _error =
              'No se encontraron las ubicaciones. Elige una opción de la lista.';
          _loading = false;
        });
        return;
      }

      // Obstáculos activos a evitar (lectura puntual de Firestore). Si falla,
      // seguimos sin evasión en vez de romper el cálculo de ruta.
      List<BarrierReport> barriers = [];
      try {
        barriers = await _firebase.getActiveBarriersOnce();
      } catch (_) {}

      final result = await _maps.getRoutesAvoidingBarriers(
        origin: origin.latLng,
        destination: dest.latLng,
        barriers: barriers,
      );

      if (result == null) {
        setState(() {
          _error = 'No se pudo calcular la ruta. Verifica las ubicaciones.';
          _loading = false;
        });
        return;
      }

      final points = result.best.points;

      setState(() {
        _polylines = _buildPolylines(result);
        _markers = {
          Marker(
            markerId: const MarkerId('origin'),
            position: origin.latLng,
            icon:
                BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
            infoWindow: InfoWindow(title: 'Inicio: ${origin.name}'),
          ),
          Marker(
            markerId: const MarkerId('dest'),
            position: dest.latLng,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            infoWindow: InfoWindow(title: 'Destino: ${dest.name}'),
          ),
          ..._buildBarrierMarkers(result),
        };
        _circles = _buildBarrierCircles(result);
        _routeInfo =
            '${result.best.distanceKm.toStringAsFixed(1)} km · ~${result.best.durationMinutes} min caminando';
        _avoidInfo = _buildAvoidInfo(result);
        _loading = false;
      });

      _speakRouteInfo();

      // Encuadrar la ruta en el mapa. Va en su propio try/catch: en web
      // animateCamera(newLatLngBounds) puede lanzar y NO debe ocultar una
      // ruta que sí se calculó y dibujó correctamente.
      try {
        final ctrl = await _mapController.future;
        // Encuadra la ruta completa: usa todos los puntos de la polyline para
        // que el zoom abarque también las curvas, no solo origen y destino.
        final lats = points.map((p) => p.latitude);
        final lngs = points.map((p) => p.longitude);
        final bounds = LatLngBounds(
          southwest: LatLng(
            lats.reduce((a, b) => a < b ? a : b),
            lngs.reduce((a, b) => a < b ? a : b),
          ),
          northeast: LatLng(
            lats.reduce((a, b) => a > b ? a : b),
            lngs.reduce((a, b) => a > b ? a : b),
          ),
        );
        await ctrl.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
      } catch (_) {
        // El encuadre falló (p.ej. mapa no listo en web). La ruta ya está
        // dibujada; ignoramos el error de cámara.
      }
    } catch (e) {
      setState(() {
        _error = 'Error inesperado: $e';
        _loading = false;
      });
    }
  }

  /// Dibuja la ruta elegida (verde). Si se reencaminó para evitar obstáculos,
  /// dibuja además la ruta directa por defecto en gris translúcido como
  /// referencia visual de "lo que se evitó".
  Set<Polyline> _buildPolylines(RouteResult result) {
    final lines = <Polyline>{};

    if (result.didReroute) {
      lines.add(Polyline(
        polylineId: const PolylineId('route_default'),
        points: result.defaultOption.points,
        color: AppColors.muted.withOpacity(0.5),
        width: 4,
        patterns: [PatternItem.dash(20), PatternItem.gap(12)],
      ));
    }

    lines.add(Polyline(
      polylineId: const PolylineId('route_best'),
      points: result.best.points,
      color: AppColors.secondary,
      width: 6,
    ));

    return lines;
  }

  /// Marcadores para los obstáculos cercanos a la ruta.
  Set<Marker> _buildBarrierMarkers(RouteResult result) {
    final remainingIds = result.remainingBarriers.map((b) => b.id).toSet();
    return result.nearbyBarriers.map((b) {
      final onRoute = remainingIds.contains(b.id);
      final emoji = AppConstants.barrierTypeEmoji[b.type] ?? '📍';
      return Marker(
        markerId: MarkerId('barrier_${b.id}'),
        position: LatLng(b.lat, b.lng),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          onRoute ? BitmapDescriptor.hueRed : BitmapDescriptor.hueOrange,
        ),
        infoWindow: InfoWindow(
          title: '$emoji ${b.type}',
          snippet: onRoute ? 'En la ruta' : 'Evitado',
        ),
      );
    }).toSet();
  }

  /// Círculos de radio para resaltar obstáculos: rojo = en la ruta elegida,
  /// verde = evitado al reencaminar, naranja tenue = otros cercanos.
  Set<Circle> _buildBarrierCircles(RouteResult result) {
    final remainingIds = result.remainingBarriers.map((b) => b.id).toSet();
    final avoidedIds = result.avoidedBarriers.map((b) => b.id).toSet();

    return result.nearbyBarriers.map((b) {
      final Color color;
      if (remainingIds.contains(b.id)) {
        color = AppColors.danger;
      } else if (avoidedIds.contains(b.id)) {
        color = AppColors.secondary;
      } else {
        color = Colors.orange;
      }
      return Circle(
        circleId: CircleId('barrier_circle_${b.id}'),
        center: LatLng(b.lat, b.lng),
        radius: 25,
        fillColor: color.withOpacity(0.18),
        strokeColor: color.withOpacity(0.7),
        strokeWidth: 2,
      );
    }).toSet();
  }

  /// Texto resumen de la evasión de obstáculos para la barra de info.
  String _buildAvoidInfo(RouteResult result) {
    final avoided = result.avoidedBarriers.length;
    final remaining = result.remainingBarriers.length;

    if (avoided == 0 && remaining == 0) {
      return 'Sin obstáculos reportados en esta ruta';
    }
    if (avoided > 0 && remaining == 0) {
      return 'Ruta reencaminada: evita $avoided ${_obstWord(avoided)}';
    }
    if (avoided > 0 && remaining > 0) {
      return 'Evita $avoided ${_obstWord(avoided)} · quedan $remaining sin esquivar';
    }
    return '$remaining ${_obstWord(remaining)} en la ruta (sin alternativa mejor)';
  }

  String _obstWord(int n) => n == 1 ? 'obstáculo' : 'obstáculos';

  Future<void> _speakRouteInfo() async {
    if (_routeInfo == null) return;
    final tts = context.read<TtsService>();
    if (_speaking) {
      await tts.stop();
      if (mounted) setState(() => _speaking = false);
      return;
    }
    setState(() => _speaking = true);
    final text =
        '${_routeInfo!.replaceAll('·', ',')}. ${_avoidInfo ?? ''}'.trim();
    await tts.speak(text);
    if (mounted) setState(() => _speaking = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ruta Accesible'),
        backgroundColor: AppColors.secondary,
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Datos de demo',
            icon: const Icon(Icons.science_outlined),
            onSelected: _onDemoMenu,
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'seed',
                child: ListTile(
                  leading: Icon(Icons.add_location_alt_outlined),
                  title: Text('Sembrar obstáculos demo'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'clear',
                child: ListTile(
                  leading: Icon(Icons.delete_sweep_outlined),
                  title: Text('Borrar obstáculos demo'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchPanel(),
          if (_routeInfo != null) _buildRouteInfoBar(),
          if (_avoidInfo != null) _buildAvoidInfoBar(),
          if (_error != null) _buildErrorBar(),
          Expanded(
            child: GoogleMap(
              initialCameraPosition:
                  const CameraPosition(target: _tijuanaCenter, zoom: 13),
              onMapCreated: _mapController.complete,
              polylines: _polylines,
              markers: _markers,
              circles: _circles,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              zoomControlsEnabled: false,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchPanel() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        children: [
          PlaceSearchField(
            mapsService: _maps,
            controller: _originCtrl,
            hintText: 'Origen  (ej. Centro Cívico)',
            icon: Icons.trip_origin,
            iconColor: AppColors.secondary,
            onSelected: (place) => setState(() => _originPlace = place),
            onCleared: () => setState(() => _originPlace = null),
            // Si el usuario edita el texto puesto automáticamente ("Mi
            // ubicación actual"), invalidamos el origen fijado para que valga
            // lo que escriba o elija del autocompletado.
            onTextChanged: (value) {
              if (_originPlace != null && value != _originPlace!.name) {
                setState(() => _originPlace = null);
              }
            },
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _locatingOrigin ? null : _useCurrentLocationAsOrigin,
              icon: _locatingOrigin
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location, size: 18),
              label: Text(
                _locatingOrigin
                    ? 'Obteniendo ubicación...'
                    : 'Usar mi ubicación actual',
              ),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.secondary,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 36),
              ),
            ),
          ),
          const SizedBox(height: 8),
          PlaceSearchField(
            mapsService: _maps,
            controller: _destCtrl,
            hintText: 'Destino  (ej. Hospital General)',
            icon: Icons.location_on,
            iconColor: AppColors.danger,
            onSelected: (place) => setState(() => _destPlace = place),
            onCleared: () => setState(() => _destPlace = null),
          ),
          const SizedBox(height: 12),
          _buildDemoChips(),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _loading ? null : _calcRoute,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.secondary,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
            ),
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.alt_route),
            label: Text(_loading ? 'Calculando...' : 'Calcular ruta accesible'),
          ),
        ],
      ),
    );
  }

  Widget _buildDemoChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: AppConstants.demoLocations.map((loc) {
          final short = loc.split(',').first;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ActionChip(
              label: Text(short, style: const TextStyle(fontSize: 12)),
              onPressed: () => _applyDemoLocation(short),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Rellena origen o destino con un lugar de demo, resolviendo sus coordenadas
  /// directamente (sin que el usuario escriba) para que la ruta funcione.
  Future<void> _applyDemoLocation(String short) async {
    final isOrigin = _originCtrl.text.isEmpty;
    final ctrl = isOrigin ? _originCtrl : _destCtrl;
    ctrl.text = short;

    final result = await _maps.searchText('$short Tijuana');
    if (result == null) return;
    setState(() {
      if (isOrigin) {
        _originPlace = result;
      } else {
        _destPlace = result;
      }
    });
  }

  /// Siembra o borra los obstáculos de demo desde el menú.
  Future<void> _onDemoMenu(String action) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Procesando obstáculos de demo...')),
    );
    try {
      if (action == 'seed') {
        final n = await _firebase.seedDemoBarriers();
        messenger.showSnackBar(
          SnackBar(
            backgroundColor: AppColors.secondary,
            content: Text(
                '$n obstáculos de demo sembrados. Ábrelos en "Mapa de Barreras" '
                'o calcula una ruta para verlos.'),
            duration: const Duration(seconds: 4),
          ),
        );
      } else if (action == 'clear') {
        final n = await _firebase.clearDemoBarriers();
        messenger.showSnackBar(
          SnackBar(content: Text('$n obstáculos de demo borrados.')),
        );
      }
    } catch (e) {
      // Surface real errors (p.ej. reglas de Firestore o sesión cerrada) en vez
      // de fallar en silencio.
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: AppColors.danger,
          content: Text('No se pudo completar: $e'),
          duration: const Duration(seconds: 8),
        ),
      );
    }
  }

  /// Barra que resume cuántos obstáculos esquiva la ruta elegida.
  Widget _buildAvoidInfoBar() {
    final rerouted = _avoidInfo!.startsWith('Ruta reencaminada') ||
        _avoidInfo!.startsWith('Evita');
    final color = rerouted ? AppColors.secondary : AppColors.muted;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: color.withOpacity(0.08),
      child: Row(
        children: [
          Icon(rerouted ? Icons.alt_route : Icons.info_outline,
              color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _avoidInfo!,
              style: TextStyle(
                  fontSize: 13, color: color, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteInfoBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AppColors.secondary.withOpacity(0.1),
      child: Row(
        children: [
          const Icon(Icons.accessible, color: AppColors.secondary, size: 20),
          const SizedBox(width: 8),
          Text(
            _routeInfo!,
            style: const TextStyle(
                fontWeight: FontWeight.w600, color: AppColors.secondary),
          ),
          const Spacer(),
          const Icon(Icons.check_circle_outline,
              color: AppColors.secondary, size: 16),
          const SizedBox(width: 4),
          const Text(
            'Ruta peatonal',
            style: TextStyle(fontSize: 12, color: AppColors.secondary),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _speakRouteInfo,
            icon: Icon(
              _speaking ? Icons.stop_circle_outlined : Icons.volume_up_outlined,
            ),
            color: AppColors.secondary,
            iconSize: 20,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: _speaking ? 'Detener lectura' : 'Escuchar ruta',
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AppColors.danger.withOpacity(0.1),
      child: Row(
        children: [
          const Icon(Icons.warning_amber, color: AppColors.danger, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _error!,
              style: const TextStyle(fontSize: 13, color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _originCtrl.dispose();
    _destCtrl.dispose();
    super.dispose();
  }
}
