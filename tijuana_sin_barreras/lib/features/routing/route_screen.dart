import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/maps_service.dart';

class RouteScreen extends StatefulWidget {
  const RouteScreen({super.key});

  @override
  State<RouteScreen> createState() => _RouteScreenState();
}

class _RouteScreenState extends State<RouteScreen> {
  final _originCtrl = TextEditingController();
  final _destCtrl = TextEditingController();
  final _mapController = Completer<GoogleMapController>();

  Set<Polyline> _polylines = {};
  Set<Marker> _markers = {};
  bool _loading = false;
  String? _routeInfo;
  String? _error;

  static const _tijuanaCenter = LatLng(AppConstants.tijuanaLat, AppConstants.tijuanaLng);

  Future<void> _calcRoute() async {
    final origin = _originCtrl.text.trim();
    final dest = _destCtrl.text.trim();

    if (origin.isEmpty || dest.isEmpty) {
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
      final maps = context.read<MapsService>();

      final originResults = await maps.searchPlaces('$origin Tijuana');
      final destResults = await maps.searchPlaces('$dest Tijuana');

      if (originResults.isEmpty || destResults.isEmpty) {
        setState(() {
          _error = 'No se encontraron las ubicaciones. Intenta ser más específico.';
          _loading = false;
        });
        return;
      }

      final originGeo = originResults.first['geometry']['location'] as Map;
      final destGeo = destResults.first['geometry']['location'] as Map;

      final originLatLng = LatLng(
        (originGeo['lat'] as num).toDouble(),
        (originGeo['lng'] as num).toDouble(),
      );
      final destLatLng = LatLng(
        (destGeo['lat'] as num).toDouble(),
        (destGeo['lng'] as num).toDouble(),
      );

      final routeData = await maps.getAccessibleRoute(
        origin: originLatLng,
        destination: destLatLng,
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
      final points = maps.decodePolyline(polylineEncoded);
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
            patterns: const [],
          ),
        };
        _markers = {
          Marker(
            markerId: const MarkerId('origin'),
            position: originLatLng,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
            infoWindow: InfoWindow(title: 'Inicio: $origin'),
          ),
          Marker(
            markerId: const MarkerId('dest'),
            position: destLatLng,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            infoWindow: InfoWindow(title: 'Destino: $dest'),
          ),
        };
        _routeInfo =
            '${(distanceM / 1000).toStringAsFixed(1)} km · ~$durationMin min caminando';
        _loading = false;
      });

      // Zoom to fit the route
      final ctrl = await _mapController.future;
      final bounds = LatLngBounds(
        southwest: LatLng(
          [originLatLng.latitude, destLatLng.latitude].reduce((a, b) => a < b ? a : b),
          [originLatLng.longitude, destLatLng.longitude].reduce((a, b) => a < b ? a : b),
        ),
        northeast: LatLng(
          [originLatLng.latitude, destLatLng.latitude].reduce((a, b) => a > b ? a : b),
          [originLatLng.longitude, destLatLng.longitude].reduce((a, b) => a > b ? a : b),
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
          TextField(
            controller: _originCtrl,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              hintText: 'Origen  (ej. Centro Cívico)',
              prefixIcon: Icon(Icons.trip_origin, color: AppColors.secondary),
              filled: true,
              fillColor: Color(0xFFF8F9FA),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _destCtrl,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _calcRoute(),
            decoration: const InputDecoration(
              hintText: 'Destino  (ej. Hospital General)',
              prefixIcon: Icon(Icons.location_on, color: AppColors.danger),
              filled: true,
              fillColor: Color(0xFFF8F9FA),
            ),
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
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
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
              onPressed: () {
                if (_originCtrl.text.isEmpty) {
                  _originCtrl.text = short;
                } else {
                  _destCtrl.text = short;
                }
              },
            ),
          );
        }).toList(),
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
            style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.secondary),
          ),
          const Spacer(),
          const Icon(Icons.check_circle_outline, color: AppColors.secondary, size: 16),
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
