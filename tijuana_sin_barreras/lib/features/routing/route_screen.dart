import 'dart:async';
import 'dart:ui' as ui;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:tijuana_sin_barreras/shared/widgets/app_logo_2.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/models/barrier_report.dart';
import '../../core/models/emergency_alert.dart';
import '../../core/models/place_models.dart';
import '../../core/models/route_result.dart';
import '../../core/services/firebase_service.dart';
import '../../core/services/geo_utils.dart';
import '../../core/services/maps_service.dart';
import '../../core/services/tts_service.dart';
import '../../shared/widgets/place_search_field.dart';

const _kMapStyle = '''[
  {"elementType":"geometry","stylers":[{"color":"#1a2b3c"}]},
  {"elementType":"labels.icon","stylers":[{"visibility":"off"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#a0d3cd"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#1a2b3c"}]},
  {"featureType":"administrative","elementType":"geometry","stylers":[{"color":"#2a3d4f"}]},
  {"featureType":"administrative.locality","elementType":"labels.text.fill","stylers":[{"color":"#289f91"}]},
  {"featureType":"poi","elementType":"labels.text.fill","stylers":[{"color":"#289f91"}]},
  {"featureType":"poi.park","elementType":"geometry","stylers":[{"color":"#1c3a2e"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#2a3d4f"}]},
  {"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#a0d3cd"}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#289f91"}]},
  {"featureType":"road.highway","elementType":"geometry.stroke","stylers":[{"color":"#1c7269"}]},
  {"featureType":"road.highway","elementType":"labels.text.fill","stylers":[{"color":"#e8f7f5"}]},
  {"featureType":"transit","elementType":"geometry","stylers":[{"color":"#2a3d4f"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#0d1b2a"}]},
  {"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#289f91"}]}
]''';

class RouteScreen extends StatefulWidget {
  const RouteScreen({super.key});

  @override
  State<RouteScreen> createState() => _RouteScreenState();
}

class _RouteScreenState extends State<RouteScreen>
    with TickerProviderStateMixin {
  // ---------------------------------------------------------------------------
  // Route state (from original RouteScreen)
  // ---------------------------------------------------------------------------
  final _originCtrl = TextEditingController();
  final _destCtrl = TextEditingController();
  final _mapController = Completer<GoogleMapController>();

  PlaceResult? _originPlace;
  PlaceResult? _destPlace;

  Set<Polyline> _polylines = {};
  Set<Marker> _routeMarkers = {};
  Set<Circle> _circles = {};
  bool _loading = false;
  bool _speaking = false;
  bool _locatingOrigin = false;
  String? _routeInfo;
  String? _avoidInfo;
  String? _error;

  // ---------------------------------------------------------------------------
  // Map/barrier state (from MapScreen)
  // ---------------------------------------------------------------------------
  Set<Marker> _barrierMapMarkers = {};
  Set<Marker> _emergencyMarkers = {};
  BarrierReport? _selectedBarrier;
  EmergencyAlert? _selectedEmergency;
  LatLng _center = const LatLng(
    AppConstants.tijuanaLat,
    AppConstants.tijuanaLng,
  );
  LatLng? _userPosition;
  String? _activeAlertId;
  bool _sendingAlert = false;
  bool _dialogVisible = false;
  final Set<String> _seenAlertIds = {};
  StreamSubscription<List<EmergencyAlert>>? _alertsSub;

  // Animations for SOS button
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;
  late Animation<double> _breatheAnim;

  // Animated polyline draw
  late AnimationController _drawCtrl;
  late Animation<double> _drawAnim;
  RouteResult? _lastResult;
  int _drawnPointCount = 0;

  // Cached endpoints for the route card bottom sheet
  PlaceResult? _lastOrigin;
  PlaceResult? _lastDest;

  // Legend expand toggle
  bool _legendExpanded = false;

  // Custom marker icon cache
  final Map<String, BitmapDescriptor> _iconCache = {};

  MapsService get _maps => context.read<MapsService>();
  FirebaseService get _firebase => context.read<FirebaseService>();

  Set<Marker> get _allMarkers => {
    ..._routeMarkers,
    ..._barrierMapMarkers,
    ..._emergencyMarkers,
  };

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _loadMarkerIcons();
    _goToUserLocation();
    _useCurrentLocationAsOrigin();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(
      begin: 0.92,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _breatheAnim = Tween<double>(
      begin: 0.977,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    // Polyline draw animation: traces the route from origin to destination.
    // Duration scales with route complexity; 1 400 ms feels natural on web.
    _drawCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _drawAnim = CurvedAnimation(parent: _drawCtrl, curve: Curves.easeOut)
      ..addListener(_onDrawTick);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _listenToEmergencyAlerts(),
    );
  }

  @override
  void dispose() {
    _alertsSub?.cancel();
    _pulseCtrl.dispose();
    _drawCtrl.dispose();
    _originCtrl.dispose();
    _destCtrl.dispose();
    super.dispose();
  }

  // Called on every animation frame — slices the best-route points list so
  // the polyline "draws itself" from origin to destination.
  void _onDrawTick() {
    final result = _lastResult;
    if (result == null) return;
    final total = result.best.points.length;
    final count = (_drawAnim.value * total).round().clamp(0, total);
    if (count != _drawnPointCount) {
      setState(() {
        _drawnPointCount = count;
        _polylines = _buildPolylines(result, drawnCount: count);
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Marker icon loading (from MapScreen)
  // ---------------------------------------------------------------------------

  Future<void> _loadMarkerIcons() async {
    final results = await Future.wait([
      _buildIconBitmap(Icons.accessible_forward, AppColors.warning),
      _buildIconBitmap(Icons.warning_rounded, AppColors.error),
      _buildIconBitmap(Icons.traffic, const Color(0xFF9334E6)),
      _buildIconBitmap(Icons.check_circle_outline, AppColors.success),
      _buildIconBitmap(Icons.report_problem_rounded, const Color(0xFF29B6F6)),
    ]);
    _iconCache['Rampa faltante'] = results[0];
    _iconCache['Banqueta dañada'] = results[1];
    _iconCache['Semáforo sin sonido'] = results[2];
    _iconCache['resolved'] = results[3];
    _iconCache['other'] = results[4];
    if (mounted) setState(() {});
  }

  Future<BitmapDescriptor> _buildIconBitmap(IconData icon, Color bg) async {
    const size = 48.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, size, size));
    canvas.drawCircle(
      const Offset(size / 2, size / 2),
      size / 2,
      Paint()..color = bg,
    );
    final tp =
        TextPainter(textDirection: TextDirection.ltr)
          ..text = TextSpan(
            text: String.fromCharCode(icon.codePoint),
            style: TextStyle(
              fontSize: 26,
              fontFamily: icon.fontFamily,
              package: icon.fontPackage,
              color: Colors.white,
            ),
          )
          ..layout();
    tp.paint(canvas, Offset((size - tp.width) / 2, (size - tp.height) / 2));
    final image = await recorder.endRecording().toImage(
      size.toInt(),
      size.toInt(),
    );
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(data!.buffer.asUint8List());
  }

  BitmapDescriptor _iconFor(BarrierReport b) {
    if (b.status == 'resolved') {
      return _iconCache['resolved'] ??
          BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
    }
    return _iconCache[b.type] ??
        _iconCache['other'] ??
        BitmapDescriptor.defaultMarker;
  }

  // ---------------------------------------------------------------------------
  // Barrier markers from Firestore stream (from MapScreen — renamed)
  // ---------------------------------------------------------------------------

  Set<Marker> _buildMapBarrierMarkers(List<BarrierReport> barriers) {
    return barriers.map((b) {
      return Marker(
        markerId: MarkerId(b.id),
        position: LatLng(b.lat, b.lng),
        icon: _iconFor(b),
        infoWindow: InfoWindow(title: b.type),
        onTap: () => setState(() => _selectedBarrier = b),
      );
    }).toSet();
  }

  // ---------------------------------------------------------------------------
  // User location (from MapScreen)
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
  // Emergency alert stream (from MapScreen)
  // ---------------------------------------------------------------------------

  void _listenToEmergencyAlerts() {
    if (!mounted) return;
    final firebase = context.read<FirebaseService>();
    _alertsSub = firebase.getActiveEmergencyAlerts().listen((alerts) {
      if (!mounted) return;

      final markers =
          alerts
              .map(
                (a) => Marker(
                  markerId: MarkerId('sos_${a.id}'),
                  position: LatLng(a.lat, a.lng),
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueRed,
                  ),
                  onTap: () => setState(() => _selectedEmergency = a),
                ),
              )
              .toSet();

      setState(() => _emergencyMarkers = markers);

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
  // SOS logic (from MapScreen)
  // ---------------------------------------------------------------------------

  Future<void> _confirmSendAlert() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.sos, color: AppColors.error, size: 28),
                SizedBox(width: 8),
                Text('Enviar Alerta SOS'),
              ],
            ),
            content: const Text(
              'Necesitas ayuda de emergencia?\n\n'
              'Las personas con la app cercanas a tu ubicacion seran notificadas de inmediato.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                ),
                child: Text('Enviar SOS', style: GoogleFonts.lexend()),
              ),
            ],
          ),
    );
    if (confirm != true || !mounted) return;
    await _sendEmergencyAlert();
  }

  Future<void> _sendEmergencyAlert() async {
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
          content: Text('Alerta SOS enviada. Personas cercanas notificadas.'),
          backgroundColor: AppColors.error,
          duration: Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _sendingAlert = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Error al enviar alerta: $e'),
          backgroundColor: AppColors.error,
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
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _showNearbyEmergencyDialog(EmergencyAlert alert, int distMeters) {
    if (_dialogVisible) return;
    _dialogVisible = true;

    context.read<TtsService>().speak(
      'Alerta de emergencia. '
      'Hay una persona que necesita ayuda a $distMeters metros de ti.',
    );

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder:
          (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.warning_rounded, color: AppColors.error, size: 28),
                SizedBox(width: 8),
                Text('Emergencia cercana!'),
              ],
            ),
            content: Text(
              'Hay una persona que necesita ayuda a $distMeters m de tu ubicacion.\n\n'
              'Puedes acercarte a ayudar?',
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
                  backgroundColor: AppColors.error,
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
  // Route calculation (from original RouteScreen — _markers renamed to _routeMarkers,
  // _buildBarrierMarkers(RouteResult) renamed to _buildRouteBarrierMarkers)
  // ---------------------------------------------------------------------------

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
      _routeMarkers = {};
      _circles = {};
    });

    try {
      final origin = await _resolveEndpoint(_originPlace, originTyped);
      final dest = await _resolveEndpoint(_destPlace, destTyped);

      if (origin == null || dest == null) {
        setState(() {
          _error =
              'No se encontraron las ubicaciones. Elige una opcion de la lista.';
          _loading = false;
        });
        return;
      }

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

      _lastResult = result;
      _lastOrigin = origin;
      _lastDest = dest;
      _drawnPointCount = 0;

      setState(() {
        _polylines = {}; // start empty — animation fills it in
        _routeMarkers = {
          Marker(
            markerId: const MarkerId('origin'),
            position: origin.latLng,
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueGreen,
            ),
            infoWindow: InfoWindow(title: 'Inicio: ${origin.name}'),
          ),
          Marker(
            markerId: const MarkerId('dest'),
            position: dest.latLng,
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueRed,
            ),
            infoWindow: InfoWindow(title: 'Destino: ${dest.name}'),
          ),
          ..._buildRouteBarrierMarkers(result),
        };
        _circles = _buildBarrierCircles(result);
        _routeInfo =
            '${result.best.distanceKm.toStringAsFixed(1)} km · ~${result.best.durationMinutes} min caminando';
        _avoidInfo = _buildAvoidInfo(result);
        _loading = false;
      });

      _speakRouteInfo();

      // Kick off the polyline draw animation.
      _drawCtrl
        ..reset()
        ..forward();

      try {
        final ctrl = await _mapController.future;
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
      } catch (_) {}

      // Show the route card after the camera settles and the polyline starts drawing.
      if (mounted) {
        Future.delayed(const Duration(milliseconds: 700), () {
          if (mounted) _showRouteSheet();
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error inesperado: $e';
        _loading = false;
      });
    }
  }

  Set<Polyline> _buildPolylines(RouteResult result, {int? drawnCount}) {
    final lines = <Polyline>{};

    // Avoided route (original path with barriers) — always shown in full, faded.
    if (result.didReroute) {
      lines.add(
        Polyline(
          polylineId: const PolylineId('route_default'),
          points: result.defaultOption.points,
          color: AppColors.brandPassive.withValues(alpha: 0.5),
          width: 4,
          patterns: [PatternItem.dash(20), PatternItem.gap(12)],
        ),
      );
    }

    // Best route — sliced to drawnCount during animation, full when done.
    final allPoints = result.best.points;
    final visiblePoints =
        (drawnCount != null && drawnCount < allPoints.length)
            ? allPoints.sublist(0, drawnCount.clamp(1, allPoints.length))
            : allPoints;

    if (visiblePoints.isNotEmpty) {
      lines.add(
        Polyline(
          polylineId: const PolylineId('route_best'),
          points: visiblePoints,
          color: AppColors.success,
          width: 6,
        ),
      );
    }

    return lines;
  }

  /// Barrier markers for nearby obstacles along the route.
  /// Uses custom circular bitmap icons — no default Google Maps pins here.
  Set<Marker> _buildRouteBarrierMarkers(RouteResult result) {
    final remainingIds = result.remainingBarriers.map((b) => b.id).toSet();
    return result.nearbyBarriers.map((b) {
      final onRoute = remainingIds.contains(b.id);
      final emoji = AppConstants.barrierTypeEmoji[b.type] ?? '';
      return Marker(
        markerId: MarkerId('barrier_${b.id}'),
        position: LatLng(b.lat, b.lng),
        icon: _iconFor(b),
        infoWindow: InfoWindow(
          title: '$emoji ${b.type}',
          snippet: onRoute ? 'En la ruta' : 'Evitado',
        ),
      );
    }).toSet();
  }

  Set<Circle> _buildBarrierCircles(RouteResult result) {
    final remainingIds = result.remainingBarriers.map((b) => b.id).toSet();
    final avoidedIds = result.avoidedBarriers.map((b) => b.id).toSet();

    return result.nearbyBarriers.map((b) {
      final Color color;
      if (remainingIds.contains(b.id)) {
        color = AppColors.error;
      } else if (avoidedIds.contains(b.id)) {
        color = AppColors.success;
      } else {
        color = Colors.orange;
      }
      return Circle(
        circleId: CircleId('barrier_circle_${b.id}'),
        center: LatLng(b.lat, b.lng),
        radius: 25,
        fillColor: color.withValues(alpha: 0.18),
        strokeColor: color.withValues(alpha: 0.7),
        strokeWidth: 2,
      );
    }).toSet();
  }

  String _buildAvoidInfo(RouteResult result) {
    final avoided = result.avoidedBarriers.length;
    final remaining = result.remainingBarriers.length;

    if (avoided == 0 && remaining == 0) {
      return 'Sin obstaculos reportados en esta ruta';
    }
    if (avoided > 0 && remaining == 0) {
      return 'Ruta reencaminada: evita $avoided ${_obstWord(avoided)}';
    }
    if (avoided > 0 && remaining > 0) {
      return 'Evita $avoided ${_obstWord(avoided)} · quedan $remaining sin esquivar';
    }
    return '$remaining ${_obstWord(remaining)} en la ruta (sin alternativa mejor)';
  }

  String _obstWord(int n) => n == 1 ? 'obstaculo' : 'obstaculos';

  void _showRouteSheet() {
    final result = _lastResult;
    final origin = _lastOrigin;
    final dest = _lastDest;
    if (result == null || origin == null || dest == null) return;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (_) => _RouteCard(
            result: result,
            origin: origin,
            dest: dest,
            onStartNavigation: () {
              Navigator.pop(context);
              _speakRouteInfo();
            },
          ),
    );
  }

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

  Future<void> _onDemoMenu(String action) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Procesando obstaculos de demo...')),
    );
    try {
      if (action == 'seed') {
        final n = await _firebase.seedDemoBarriers();
        messenger.showSnackBar(
          SnackBar(
            backgroundColor: AppColors.success,
            content: Text(
              '$n obstaculos de demo sembrados. Abrelos en el mapa '
              'o calcula una ruta para verlos.',
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      } else if (action == 'clear') {
        final n = await _firebase.clearDemoBarriers();
        messenger.showSnackBar(
          SnackBar(content: Text('$n obstaculos de demo borrados.')),
        );
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: AppColors.error,
          content: Text('No se pudo completar: $e'),
          duration: const Duration(seconds: 8),
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final firebase = context.read<FirebaseService>();
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppLogo2(size: 48),
            const SizedBox(width: 8),
            Text(
              'Senda',
              style: GoogleFonts.lexend(color: AppColors.brandPassive),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _goToUserLocation,
            tooltip: 'Mi ubicacion',
          ),
          PopupMenuButton<String>(
            tooltip: 'Datos de demo',
            icon: const Icon(Icons.science_outlined),
            onSelected: _onDemoMenu,
            itemBuilder:
                (_) => const [
                  PopupMenuItem(
                    value: 'seed',
                    child: ListTile(
                      leading: Icon(Icons.add_location_alt_outlined),
                      title: Text('Sembrar obstaculos demo'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'clear',
                    child: ListTile(
                      leading: Icon(Icons.delete_sweep_outlined),
                      title: Text('Borrar obstaculos demo'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
          ),
          const _AuthButton(),
        ],
      ),
      body: StreamBuilder<List<BarrierReport>>(
        stream: firebase.getBarriers(),
        builder: (ctx, snap) {
          if (snap.hasData) {
            _barrierMapMarkers = _buildMapBarrierMarkers(snap.data!);
          }
          return Column(
            children: [
              _buildSearchPanel(),
              if (_routeInfo != null) _buildRouteInfoBar(),
              if (_avoidInfo != null) _buildAvoidInfoBar(),
              if (_error != null) _buildErrorBar(),
              Expanded(
                child: Stack(
                  children: [
                    GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: _center,
                        zoom: 13,
                      ),
                      onMapCreated: _mapController.complete,
                      style: _kMapStyle,
                      markers: _allMarkers,
                      polylines: _polylines,
                      circles: _circles,
                      myLocationEnabled: true,
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: false,
                      onTap:
                          (_) => setState(() {
                            _selectedBarrier = null;
                            _selectedEmergency = null;
                          }),
                    ),
                    _buildLegend(),
                    if (snap.connectionState == ConnectionState.waiting)
                      const Center(child: CircularProgressIndicator()),
                    if (_selectedBarrier != null)
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: _BarrierSheet(
                          barrier: _selectedBarrier!,
                          onClose:
                              () => setState(() => _selectedBarrier = null),
                        ),
                      ),
                    if (_selectedEmergency != null)
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: _SosSheet(
                          alert: _selectedEmergency!,
                          onClose:
                              () => setState(() => _selectedEmergency = null),
                        ),
                      ),
                  ],
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
            backgroundColor: AppColors.brandActive,
            foregroundColor: Colors.white,
            tooltip: 'Reportar una barrera de accesibilidad',
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // UI helpers — search panel & info bars (from original RouteScreen)
  // ---------------------------------------------------------------------------

  Widget _buildSearchPanel() {
    final sw = MediaQuery.sizeOf(context).width;
    final r = (sw / 390).clamp(0.9, 1.6);

    return Container(
      color: AppColors.darkDeep,
      padding: EdgeInsets.fromLTRB(16 * r, 6 * r, 16 * r, 10 * r),
      child: Column(
        children: [
          SizedBox(
            height: 24 * r,
            child: PlaceSearchField(
              mapsService: _maps,
              controller: _originCtrl,
              hintText: 'Origen  (ej. Centro Cívico)',
              icon: Icons.trip_origin,
              iconColor: AppColors.success,
              onSelected: (place) => setState(() => _originPlace = place),
              onCleared: () => setState(() => _originPlace = null),
              onTextChanged: (value) {
                if (_originPlace != null && value != _originPlace!.name) {
                  setState(() => _originPlace = null);
                }
              },
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _locatingOrigin ? null : _useCurrentLocationAsOrigin,
              icon:
                  _locatingOrigin
                      ? SizedBox(
                        width: 14 * r,
                        height: 5 * r,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.brandPassive,
                        ),
                      )
                      : Icon(Icons.my_location, size: 16 * r),
              label: Text(
                _locatingOrigin
                    ? 'Obteniendo ubicación...'
                    : 'Usar mi ubicación',
              ),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.brandPassive,
                padding: EdgeInsets.symmetric(horizontal: 4 * r),
                minimumSize: Size(0, 19 * r),
                textStyle: TextStyle(fontSize: 10 * r),
              ),
            ),
          ),
          SizedBox(height: 4 * r),
          SizedBox(
            height: 24 * r,
            child: PlaceSearchField(
              mapsService: _maps,
              controller: _destCtrl,
              hintText: 'Destino  (ej. Hospital General)',
              icon: Icons.location_on,
              iconColor: AppColors.error,
              onSelected: (place) => setState(() => _destPlace = place),
              onCleared: () => setState(() => _destPlace = null),
            ),
          ),
          SizedBox(height: 5 * r),
          ElevatedButton.icon(
            onPressed: _loading ? null : _calcRoute,
            style: ElevatedButton.styleFrom(
              minimumSize: Size(double.infinity, 32 * r),
              backgroundColor: AppColors.surfaceNeutral,
              foregroundColor: AppColors.darkDeep,
              disabledBackgroundColor: AppColors.surfaceNeutral.withValues(
                alpha: 0.45,
              ),
              disabledForegroundColor: Colors.white.withValues(alpha: 0.6),
              side: const BorderSide(color: AppColors.brandPassive, width: 1),
            ),
            icon:
                _loading
                    ? SizedBox(
                      width: 18 * r,
                      height: 18 * r,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                    : const Icon(Icons.alt_route),
            label: Text(
              _loading ? 'Calculando...' : 'Calcular ruta accesible',
              style: GoogleFonts.lexend(
                fontSize: 11 * r,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvoidInfoBar() {
    final sw = MediaQuery.sizeOf(context).width;
    final r = (sw / 390).clamp(0.9, 1.6);
    final rerouted =
        _avoidInfo!.startsWith('Ruta reencaminada') ||
        _avoidInfo!.startsWith('Evita');
    final color = rerouted ? AppColors.success : AppColors.brandPassive;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16 * r, vertical: 5 * r),
      color: AppColors.darkMid,
      child: Row(
        children: [
          Icon(
            rerouted ? Icons.alt_route : Icons.info_outline,
            color: color,
            size: 14 * r,
          ),
          SizedBox(width: 6 * r),
          Expanded(
            child: Text(
              _avoidInfo!,
              style: TextStyle(
                fontSize: 10 * r,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteInfoBar() {
    final sw = MediaQuery.sizeOf(context).width;
    final r = (sw / 390).clamp(0.9, 1.6);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16 * r, vertical: 8 * r),
      color: AppColors.darkMid,
      child: Row(
        children: [
          Icon(Icons.accessible, color: AppColors.success, size: 16 * r),
          SizedBox(width: 6 * r),
          Text(
            _routeInfo!,
            style: TextStyle(
              fontSize: 10 * r,
              fontWeight: FontWeight.w600,
              color: AppColors.surfacePositive,
            ),
          ),
          const Spacer(),
          Icon(
            Icons.check_circle_outline,
            color: AppColors.success,
            size: 13 * r,
          ),
          SizedBox(width: 3 * r),
          Text(
            'Ruta peatonal',
            style: TextStyle(
              fontSize: 10 * r,
              color: AppColors.surfacePositive,
            ),
          ),
          SizedBox(width: 6 * r),
          IconButton(
            onPressed: _speakRouteInfo,
            icon: Icon(
              _speaking ? Icons.stop_circle_outlined : Icons.volume_up_outlined,
            ),
            color: AppColors.success,
            iconSize: 16 * r,
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
      color: AppColors.error,
      child: Row(
        children: [
          const Icon(Icons.warning_amber, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _error!,
              style: const TextStyle(fontSize: 13, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SOS button widget (from MapScreen)
  // ---------------------------------------------------------------------------

  Widget _buildSosButton() {
    final isActive = _activeAlertId != null;

    return AnimatedBuilder(
      animation: isActive ? _pulseAnim : _breatheAnim,
      builder:
          (context, child) => Transform.scale(
            scale: isActive ? _pulseAnim.value : _breatheAnim.value,
            child: child,
          ),
      child: Semantics(
        label:
            isActive
                ? 'Cancelar alerta de emergencia activa'
                : 'Boton SOS: pedir ayuda de emergencia',
        button: true,
        child: GestureDetector(
          onTap:
              isActive
                  ? _cancelEmergencyAlert
                  : (_sendingAlert ? null : _confirmSendAlert),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeInOut,
            constraints: const BoxConstraints(minWidth: 165),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors:
                    isActive
                        ? [const Color(0xFFFFB300), const Color(0xFFFF8F00)]
                        : [const Color(0xFFFF6D00), const Color(0xFFE64A19)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(32),
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
                _sendingAlert
                    ? const SizedBox(
                      width: 30,
                      height: 30,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                    : Icon(
                      isActive ? Icons.cancel_outlined : Icons.warning_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                const SizedBox(width: 11),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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

  // ---------------------------------------------------------------------------
  // Legend widget (from MapScreen)
  // ---------------------------------------------------------------------------

  Widget _buildLegend() {
    return Positioned(
      top: 12,
      right: 12,
      child: GestureDetector(
        onTap: () => setState(() => _legendExpanded = !_legendExpanded),
        child: AnimatedScale(
          scale: _legendExpanded ? 1.2 : 1.0,
          alignment: Alignment.topRight,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutBack,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.darkMid,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color:
                    _legendExpanded
                        ? AppColors.brandPassive.withValues(alpha: 0.6)
                        : AppColors.brandPassive.withValues(alpha: 0.25),
              ),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 6),
              ],
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _LegendRow(
                  icon: Icons.accessible_forward,
                  color: Colors.orange,
                  label: 'Rampa faltante',
                ),
                _LegendRow(
                  icon: Icons.warning_rounded,
                  color: Colors.red,
                  label: 'Banqueta danada',
                ),
                _LegendRow(
                  icon: Icons.traffic,
                  color: Colors.purple,
                  label: 'Semaforo',
                ),
                _LegendRow(
                  icon: Icons.report_problem_rounded,
                  color: Color(0xFF29B6F6),
                  label: 'Otro',
                ),
                _LegendRow(
                  icon: Icons.check_circle_outline,
                  color: Colors.green,
                  label: 'Resuelto',
                ),
                _LegendRow(
                  icon: Icons.sos,
                  color: AppColors.error,
                  label: 'SOS',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Private widget classes (from MapScreen)
// ---------------------------------------------------------------------------

class _LegendRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  const _LegendRow({
    required this.icon,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.surfacePositive,
            ),
          ),
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
      _ => 'Estado: pendiente de revision',
    });
    return parts.join('. ');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.darkMid,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.brandPassive.withValues(alpha: 0.25),
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 16,
            offset: Offset(0, -2),
          ),
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
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.surfacePositive,
                  ),
                ),
              ),
              IconButton(
                onPressed: _toggleSpeak,
                icon: Icon(
                  _speaking
                      ? Icons.stop_circle_outlined
                      : Icons.volume_up_outlined,
                ),
                color: AppColors.brandActive,
                tooltip: _speaking ? 'Detener lectura' : 'Escuchar barrera',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 4),
              IconButton(
                onPressed: widget.onClose,
                icon: const Icon(Icons.close, color: AppColors.surfacePositive),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Cerrar',
              ),
            ],
          ),
          if (widget.barrier.description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              widget.barrier.description,
              style: TextStyle(
                color: AppColors.surfacePositive.withValues(alpha: 0.65),
                fontSize: 14,
              ),
            ),
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
        color: AppColors.brandActive.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.brandActive.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.auto_awesome,
            color: AppColors.brandActive,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              analysis,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.surfacePositive,
                height: 1.4,
              ),
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
      'resolved' => ('Resuelto', AppColors.success),
      'verified' => ('Verificado', AppColors.brandActive),
      _ => ('Pendiente revision', AppColors.warning),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SosSheet extends StatelessWidget {
  final EmergencyAlert alert;
  final VoidCallback onClose;

  const _SosSheet({required this.alert, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.darkMid,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.45)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 16,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.sos, color: AppColors.error, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Emergencia SOS',
                  style: GoogleFonts.lexend(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.error,
                  ),
                ),
              ),
              IconButton(
                onPressed: onClose,
                icon: const Icon(Icons.close, color: AppColors.surfacePositive),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Cerrar',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            alert.userName != null
                ? 'Reportado por ${alert.userName}'
                : 'Persona necesita ayuda',
            style: TextStyle(
              color: AppColors.surfacePositive.withValues(alpha: 0.8),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Route card — DraggableScrollableSheet that slides up after route calculation
// ---------------------------------------------------------------------------

class _RouteStep {
  final IconData icon;
  final String label;
  final String detail;
  final Color color;
  const _RouteStep(this.icon, this.label, this.detail, this.color);
}

class _RouteCard extends StatelessWidget {
  final RouteResult result;
  final PlaceResult origin;
  final PlaceResult dest;
  final VoidCallback onStartNavigation;

  const _RouteCard({
    required this.result,
    required this.origin,
    required this.dest,
    required this.onStartNavigation,
  });

  List<_RouteStep> _buildSteps() {
    final steps = <_RouteStep>[
      _RouteStep(Icons.my_location, 'Inicio', origin.name, AppColors.success),
    ];

    for (final b in result.remainingBarriers) {
      steps.add(
        _RouteStep(
          Icons.warning_rounded,
          b.type,
          'Precaución en la ruta',
          AppColors.warning,
        ),
      );
    }

    if (result.didReroute) {
      final n = result.avoidedBarriers.length;
      steps.add(
        _RouteStep(
          Icons.alt_route,
          'Desvío aplicado',
          'Se evitaron $n ${n == 1 ? "barrera" : "barreras"}',
          AppColors.brandActive,
        ),
      );
    }

    steps.add(
      _RouteStep(Icons.flag_rounded, 'Destino', dest.name, AppColors.error),
    );
    return steps;
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.sizeOf(context).width;
    final r = (sw / 390).clamp(0.9, 1.6);
    final steps = _buildSteps();

    return DraggableScrollableSheet(
      initialChildSize: 0.45,
      minChildSize: 0.20,
      maxChildSize: 0.88,
      snap: true,
      snapSizes: const [0.20, 0.45, 0.88],
      builder:
          (_, scrollCtrl) => Container(
            decoration: BoxDecoration(
              color: AppColors.darkMid,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              border: Border(
                top: BorderSide(
                  color: AppColors.brandPassive.withValues(alpha: 0.30),
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.40),
                  blurRadius: 24,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              children: [
                // ── Drag handle ───────────────────────────────────────────────
                Container(
                  margin: EdgeInsets.symmetric(vertical: 10 * r),
                  width: 40 * r,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.brandPassive.withValues(alpha: 0.40),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // ── Summary row ───────────────────────────────────────────────
                Padding(
                  padding: EdgeInsets.fromLTRB(20 * r, 4 * r, 16 * r, 14 * r),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.accessible_forward,
                        color: AppColors.success,
                        size: 26 * r,
                      ),
                      SizedBox(width: 12 * r),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${result.best.distanceKm.toStringAsFixed(1)} km  ·  ~${result.best.durationMinutes} min',
                              style: GoogleFonts.lexend(
                                fontSize: 17 * r,
                                fontWeight: FontWeight.w600,
                                color: AppColors.surfacePositive,
                              ),
                            ),
                            if (result.didReroute)
                              Text(
                                '${result.avoidedBarriers.length} barrera(s) evitada(s)',
                                style: GoogleFonts.lexend(
                                  fontSize: 12 * r,
                                  color: AppColors.success,
                                ),
                              ),
                          ],
                        ),
                      ),
                      SizedBox(width: 8 * r),
                      FilledButton.icon(
                        onPressed: onStartNavigation,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.brandHover,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            horizontal: 14 * r,
                            vertical: 10 * r,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: Icon(Icons.navigation_rounded, size: 16 * r),
                        label: Text(
                          'Iniciar',
                          style: GoogleFonts.lexend(
                            fontSize: 13 * r,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(
                  color: AppColors.darkDeep,
                  height: 1,
                  thickness: 1,
                ),

                // ── Step list ─────────────────────────────────────────────────
                Expanded(
                  child: ListView.builder(
                    controller: scrollCtrl,
                    padding: EdgeInsets.symmetric(vertical: 8 * r),
                    itemCount: steps.length,
                    itemBuilder:
                        (_, i) => _StepTile(
                          step: steps[i],
                          isLast: i == steps.length - 1,
                          r: r,
                        ),
                  ),
                ),
              ],
            ),
          ),
    );
  }
}

class _StepTile extends StatelessWidget {
  final _RouteStep step;
  final bool isLast;
  final double r;

  const _StepTile({required this.step, this.isLast = false, this.r = 1.0});

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Timeline column ─────────────────────────────────────────────
          SizedBox(
            width: 64 * r,
            child: Column(
              children: [
                SizedBox(height: 14 * r),
                Container(
                  width: 32 * r,
                  height: 32 * r,
                  decoration: BoxDecoration(
                    color: step.color.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(step.icon, color: step.color, size: 16 * r),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: EdgeInsets.symmetric(vertical: 4 * r),
                      color: AppColors.darkDeep,
                    ),
                  ),
              ],
            ),
          ),

          // ── Content ─────────────────────────────────────────────────────
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                right: 20 * r,
                top: 14 * r,
                bottom: 14 * r,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.label,
                    style: GoogleFonts.lexend(
                      fontSize: 13 * r,
                      fontWeight: FontWeight.w600,
                      color: AppColors.surfacePositive,
                    ),
                  ),
                  SizedBox(height: 2 * r),
                  Text(
                    step.detail,
                    style: GoogleFonts.lexend(
                      fontSize: 12 * r,
                      color: AppColors.surfacePositive.withValues(alpha: 0.65),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Auth button (login/profile)
// ---------------------------------------------------------------------------

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
            onPressed:
                () => Navigator.pushNamed(
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
