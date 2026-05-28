const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { GoogleGenerativeAI } = require('@google/generative-ai');

admin.initializeApp();

// Analiza automáticamente la foto de una barrera recién reportada con Gemini
exports.analyzeBarrierOnCreate = functions.firestore
  .document('barriers/{barrierId}')
  .onCreate(async (snap, context) => {
    const data = snap.data();

    // Solo procesar si hay foto y aún no hay análisis
    if (!data.photoUrl || data.geminiAnalysis) return null;

    try {
      const apiKey = functions.config().gemini.api_key;
      const genAI = new GoogleGenerativeAI(apiKey);
      const model = genAI.getGenerativeModel({ model: 'gemini-1.5-flash' });

      // Descargar la imagen desde Firebase Storage URL
      const fetch = (await import('node-fetch')).default;
      const response = await fetch(data.photoUrl);
      const buffer = await response.arrayBuffer();
      const base64 = Buffer.from(buffer).toString('base64');

      const result = await model.generateContent([
        `Eres un experto en accesibilidad urbana de Tijuana, México.
Analiza esta imagen e identifica la barrera de accesibilidad.
Tipo reportado por el ciudadano: ${data.type}.
Responde ÚNICAMENTE con JSON válido:
{"tipo": "", "riesgo": "Alto|Medio|Bajo", "accion": "", "descripcion": ""}`,
        { inlineData: { mimeType: 'image/jpeg', data: base64 } },
      ]);

      const text = result.response.text().trim();

      // Extraer JSON de la respuesta
      const start = text.indexOf('{');
      const end = text.lastIndexOf('}') + 1;
      const jsonStr = text.substring(start, end);
      const parsed = JSON.parse(jsonStr);

      const analysis = `[${parsed.riesgo}] ${parsed.descripcion}\n→ ${parsed.accion}`;

      await snap.ref.update({ geminiAnalysis: analysis });
      console.log(`Barrier ${context.params.barrierId} analyzed: ${parsed.riesgo}`);
    } catch (err) {
      console.error('Gemini analysis failed:', err);
    }

    return null;
  });

// Endpoint HTTP para estadísticas (opcional para demo BigQuery)
exports.getStats = functions.https.onRequest(async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');

  const snapshot = await admin.firestore().collection('barriers').get();
  const total = snapshot.size;

  const byType = {};
  const byStatus = {};

  snapshot.forEach((doc) => {
    const data = doc.data();
    byType[data.type] = (byType[data.type] || 0) + 1;
    byStatus[data.status] = (byStatus[data.status] || 0) + 1;
  });

  res.json({ total, byType, byStatus });
});
