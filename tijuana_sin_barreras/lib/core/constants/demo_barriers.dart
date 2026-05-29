/// Obstáculos de ejemplo para pruebas y demo del ruteo accesible.
///
/// Están ubicados sobre corredores peatonales reales del centro y la Zona Río
/// de Tijuana, en racimos pensados para que una ruta directa entre los lugares
/// de demo (Centro Cívico, Zona Río, Hospital General, Parque Teniente
/// Guerrero, Mercado Hidalgo) tenga que rodearlos.
///
/// Se siembran con IDs estables (`demo-XX`) y el campo `demo: true`, de modo que
/// volver a sembrar es idempotente y se pueden borrar todos de un golpe.
class DemoBarrier {
  final String id;
  final double lat;
  final double lng;
  final String type;
  final String description;

  const DemoBarrier({
    required this.id,
    required this.lat,
    required this.lng,
    required this.type,
    required this.description,
  });
}

class DemoBarriers {
  /// Prefijo de los IDs de documento sembrados.
  static const String idPrefix = 'demo-';

  static const List<DemoBarrier> all = [
    // --- Racimo Zona Río / Paseo de los Héroes (entre Centro Cívico y Zona Río) ---
    DemoBarrier(
      id: 'demo-01',
      lat: 32.5268,
      lng: -117.0208,
      type: 'Rampa faltante',
      description: 'Esquina sin rampa en Paseo de los Héroes.',
    ),
    DemoBarrier(
      id: 'demo-02',
      lat: 32.5256,
      lng: -117.0227,
      type: 'Banqueta dañada',
      description: 'Banqueta fracturada y levantada por raíces.',
    ),
    DemoBarrier(
      id: 'demo-03',
      lat: 32.5244,
      lng: -117.0246,
      type: 'Obstáculo en paso peatonal',
      description: 'Puesto ambulante bloqueando el cruce peatonal.',
    ),
    DemoBarrier(
      id: 'demo-04',
      lat: 32.5233,
      lng: -117.0265,
      type: 'Estacionamiento en banqueta',
      description: 'Autos estacionados sobre la banqueta.',
    ),
    DemoBarrier(
      id: 'demo-05',
      lat: 32.5281,
      lng: -117.0193,
      type: 'Escalón sin rampa',
      description: 'Escalón de 20 cm sin rampa de acceso.',
    ),

    // --- Racimo Centro / Av. Revolución ---
    DemoBarrier(
      id: 'demo-06',
      lat: 32.5326,
      lng: -117.0382,
      type: 'Sin rebaje de banqueta',
      description: 'Esquina sin rebaje en Av. Revolución.',
    ),
    DemoBarrier(
      id: 'demo-07',
      lat: 32.5311,
      lng: -117.0375,
      type: 'Banqueta dañada',
      description: 'Baches y hundimientos en la banqueta.',
    ),
    DemoBarrier(
      id: 'demo-08',
      lat: 32.5298,
      lng: -117.0368,
      type: 'Semáforo sin sonido',
      description: 'Cruce sin señal sonora para personas ciegas.',
    ),
    DemoBarrier(
      id: 'demo-09',
      lat: 32.5305,
      lng: -117.0405,
      type: 'Obstáculo en paso peatonal',
      description: 'Poste en medio de la banqueta junto al Parque Teniente Guerrero.',
    ),

    // --- Racimo Mercado Hidalgo / Sánchez Taboada ---
    DemoBarrier(
      id: 'demo-10',
      lat: 32.5242,
      lng: -117.0221,
      type: 'Rampa faltante',
      description: 'Acceso al Mercado Hidalgo sin rampa.',
    ),
    DemoBarrier(
      id: 'demo-11',
      lat: 32.5229,
      lng: -117.0238,
      type: 'Banqueta dañada',
      description: 'Banqueta angosta y rota frente a locales.',
    ),
    DemoBarrier(
      id: 'demo-12',
      lat: 32.5215,
      lng: -117.0252,
      type: 'Estacionamiento en banqueta',
      description: 'Vehículos invadiendo el paso peatonal.',
    ),

    // --- Racimo cercano al Hospital General (Av. Centenario) ---
    DemoBarrier(
      id: 'demo-13',
      lat: 32.5131,
      lng: -117.0251,
      type: 'Escalón sin rampa',
      description: 'Escalón en acceso a banqueta cerca del hospital.',
    ),
    DemoBarrier(
      id: 'demo-14',
      lat: 32.5145,
      lng: -117.0238,
      type: 'Sin rebaje de banqueta',
      description: 'Cruce sin rebaje en Av. Centenario.',
    ),
    DemoBarrier(
      id: 'demo-15',
      lat: 32.5158,
      lng: -117.0229,
      type: 'Obstáculo en paso peatonal',
      description: 'Contenedor de basura sobre el cruce.',
    ),

    // --- Dispersos para densidad general ---
    DemoBarrier(
      id: 'demo-16',
      lat: 32.5189,
      lng: -117.0301,
      type: 'Banqueta dañada',
      description: 'Tramo de banqueta sin pavimentar.',
    ),
    DemoBarrier(
      id: 'demo-17',
      lat: 32.5207,
      lng: -117.0285,
      type: 'Rampa faltante',
      description: 'Esquina sin rampa rumbo al Centro Cívico.',
    ),
    DemoBarrier(
      id: 'demo-18',
      lat: 32.5275,
      lng: -117.0255,
      type: 'Estacionamiento en banqueta',
      description: 'Banqueta bloqueada por motocicletas.',
    ),
  ];
}
