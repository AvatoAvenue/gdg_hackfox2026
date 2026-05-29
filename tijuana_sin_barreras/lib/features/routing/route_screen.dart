import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/models/place_models.dart';
import '../../core/services/maps_service.dart';
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
  bool _loading = false;
  String? _routeInfo;
  String? _error;

  static const _tijuanaCenter =
      LatLng(AppConstants.tijuanaLat, AppConstants.tijuanaLng);

  MapsService get _maps => context.read<MapsService>();

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
      _polylines = {};
      _markers = {};
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

      final routeData = await _maps.getAccessibleRoute(
        origin: origin.latLng,
        destination: dest.latLng,
      );

      if (routeData == null || (routeData['routes'] as List?)?.isEmpty == true) {
        setState(() {
          _error = 'No se pudo calcular la ruta. Verifica las ubicaciones.';
          _loading = false;
        });
        return;
      }

      final route = (routeData['routes'] as List).first as Map<String, dynamic>;
      final polylineEncoded = route['polyline']['encodedPolyline'] as String;
      final points = _maps.decodePolyline(polylineEncoded);
      final distanceM = (route['distanceMeters'] as num).toInt();
      final durationS = int.tryParse(
            (route['duration'] as String).replaceAll('s', ''),
          ) ??
          0;
      final durationMin = durationS ~/ 60;

      setState(() {
        _polylines = {
          Polyline(
            polylineId: const PolylineId('route'),
            points: points,
            color: AppColors.secondary,
            width: 5,
          ),
        };
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
        };
        _routeInfo =
            '${(distanceM / 1000).toStringAsFixed(1)} km · ~$durationMin min caminando';
        _loading = false;
      });

      // Encuadrar la ruta en el mapa.
      final ctrl = await _mapController.future;
      final bounds = LatLngBounds(
        southwest: LatLng(
          [origin.latLng.latitude, dest.latLng.latitude]
              .reduce((a, b) => a < b ? a : b),
          [origin.latLng.longitude, dest.latLng.longitude]
              .reduce((a, b) => a < b ? a : b),
        ),
        northeast: LatLng(
          [origin.latLng.latitude, dest.latLng.latitude]
              .reduce((a, b) => a > b ? a : b),
          [origin.latLng.longitude, dest.latLng.longitude]
              .reduce((a, b) => a > b ? a : b),
        ),
      );
      ctrl.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
    } catch (e) {
      setState(() {
        _error = 'Error inesperado: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ruta Accesible'),
        backgroundColor: AppColors.secondary,
      ),
      body: Column(
        children: [
          _buildSearchPanel(),
          if (_routeInfo != null) _buildRouteInfoBar(),
          if (_error != null) _buildErrorBar(),
          Expanded(
            child: GoogleMap(
              initialCameraPosition:
                  const CameraPosition(target: _tijuanaCenter, zoom: 13),
              onMapCreated: _mapController.complete,
              polylines: _polylines,
              markers: _markers,
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
