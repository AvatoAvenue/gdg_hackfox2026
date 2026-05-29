/**
 * Carga obstáculos de ejemplo en Firestore para probar el ruteo accesible.
 *
 * Usa firebase-admin, que escribe con privilegios de servicio (ignora las
 * reglas de seguridad), así que funciona aunque las reglas restrinjan la
 * creación desde el cliente.
 *
 * Uso (desde la carpeta functions/):
 *
 *   # Opción A — service account key (Firebase Console → Configuración del
 *   # proyecto → Cuentas de servicio → Generar nueva clave privada):
 *   GOOGLE_APPLICATION_CREDENTIALS=./serviceAccountKey.json \
 *     node seed_demo_barriers.js
 *
 *   # Opción B — Application Default Credentials (si tienes gcloud):
 *   gcloud auth application-default login
 *   node seed_demo_barriers.js
 *
 *   # Borrar los obstáculos de demo:
 *   node seed_demo_barriers.js --clear
 *
 * Son idempotentes: usan IDs estables (demo-XX) con set(), así que volver a
 * correrlo no duplica.
 */

const admin = require('firebase-admin');

const PROJECT_ID = 'tijuana-barreras-gdg-chdv';

admin.initializeApp({projectId: PROJECT_ID});
const db = admin.firestore();

// Mismos datos que lib/core/constants/demo_barriers.dart — mantener en sync.
const DEMO_BARRIERS = [
  // Racimo Zona Río / Paseo de los Héroes
  {id: 'demo-01', lat: 32.5268, lng: -117.0208, type: 'Rampa faltante', description: 'Esquina sin rampa en Paseo de los Héroes.'},
  {id: 'demo-02', lat: 32.5256, lng: -117.0227, type: 'Banqueta dañada', description: 'Banqueta fracturada y levantada por raíces.'},
  {id: 'demo-03', lat: 32.5244, lng: -117.0246, type: 'Obstáculo en paso peatonal', description: 'Puesto ambulante bloqueando el cruce peatonal.'},
  {id: 'demo-04', lat: 32.5233, lng: -117.0265, type: 'Estacionamiento en banqueta', description: 'Autos estacionados sobre la banqueta.'},
  {id: 'demo-05', lat: 32.5281, lng: -117.0193, type: 'Escalón sin rampa', description: 'Escalón de 20 cm sin rampa de acceso.'},
  // Racimo Centro / Av. Revolución
  {id: 'demo-06', lat: 32.5326, lng: -117.0382, type: 'Sin rebaje de banqueta', description: 'Esquina sin rebaje en Av. Revolución.'},
  {id: 'demo-07', lat: 32.5311, lng: -117.0375, type: 'Banqueta dañada', description: 'Baches y hundimientos en la banqueta.'},
  {id: 'demo-08', lat: 32.5298, lng: -117.0368, type: 'Semáforo sin sonido', description: 'Cruce sin señal sonora para personas ciegas.'},
  {id: 'demo-09', lat: 32.5305, lng: -117.0405, type: 'Obstáculo en paso peatonal', description: 'Poste en medio de la banqueta junto al Parque Teniente Guerrero.'},
  // Racimo Mercado Hidalgo / Sánchez Taboada
  {id: 'demo-10', lat: 32.5242, lng: -117.0221, type: 'Rampa faltante', description: 'Acceso al Mercado Hidalgo sin rampa.'},
  {id: 'demo-11', lat: 32.5229, lng: -117.0238, type: 'Banqueta dañada', description: 'Banqueta angosta y rota frente a locales.'},
  {id: 'demo-12', lat: 32.5215, lng: -117.0252, type: 'Estacionamiento en banqueta', description: 'Vehículos invadiendo el paso peatonal.'},
  // Racimo Hospital General (Av. Centenario)
  {id: 'demo-13', lat: 32.5131, lng: -117.0251, type: 'Escalón sin rampa', description: 'Escalón en acceso a banqueta cerca del hospital.'},
  {id: 'demo-14', lat: 32.5145, lng: -117.0238, type: 'Sin rebaje de banqueta', description: 'Cruce sin rebaje en Av. Centenario.'},
  {id: 'demo-15', lat: 32.5158, lng: -117.0229, type: 'Obstáculo en paso peatonal', description: 'Contenedor de basura sobre el cruce.'},
  // Dispersos
  {id: 'demo-16', lat: 32.5189, lng: -117.0301, type: 'Banqueta dañada', description: 'Tramo de banqueta sin pavimentar.'},
  {id: 'demo-17', lat: 32.5207, lng: -117.0285, type: 'Rampa faltante', description: 'Esquina sin rampa rumbo al Centro Cívico.'},
  {id: 'demo-18', lat: 32.5275, lng: -117.0255, type: 'Estacionamiento en banqueta', description: 'Banqueta bloqueada por motocicletas.'},
];

async function seed() {
  const batch = db.batch();
  for (const b of DEMO_BARRIERS) {
    const ref = db.collection('barriers').doc(b.id);
    batch.set(ref, {
      lat: b.lat,
      lng: b.lng,
      type: b.type,
      description: b.description,
      photoBase64: null,
      geminiAnalysis: null,
      reportedAt: admin.firestore.FieldValue.serverTimestamp(),
      status: 'pending',
      userId: 'demo-seed',
    });
  }
  await batch.commit();
  console.log(`✔ ${DEMO_BARRIERS.length} obstáculos de demo sembrados.`);
}

async function clear() {
  const batch = db.batch();
  for (const b of DEMO_BARRIERS) {
    batch.delete(db.collection('barriers').doc(b.id));
  }
  await batch.commit();
  console.log(`✔ ${DEMO_BARRIERS.length} obstáculos de demo borrados.`);
}

const isClear = process.argv.includes('--clear');
(isClear ? clear() : seed())
    .then(() => process.exit(0))
    .catch((err) => {
      console.error('✖ Falló:', err.message);
      process.exit(1);
    });
