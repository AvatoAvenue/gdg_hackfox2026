# Agents — Tijuana Sin Barreras
## Chackethon Developers · HackFox 2026

Agentes especializados de Claude Code para el desarrollo del proyecto.
Están definidos en `.claude/agents/` y se activan con el Agent tool.

---

## Índice de Agentes

| Agente | Activar cuando... | Archivo |
|--------|------------------|---------|
| `flutter-frontend` | Crear/modificar screens, widgets, navegación, UI | `.claude/agents/flutter-frontend.md` |
| `firebase-backend` | Firestore, Storage, Auth, Cloud Functions, reglas | `.claude/agents/firebase-backend.md` |
| `ai-maps` | Gemini API, Routes API, Places API, polylines | `.claude/agents/ai-maps.md` |
| `ux-pitch` | Revisar UI/UX, accesibilidad, preparar pitch | `.claude/agents/ux-pitch.md` |

---

## Uso rápido

```
# En Claude Code — delegar una tarea completa a un agente:
"Usa el agente flutter-frontend para crear la pantalla de detalle de barrera"
"Usa el agente firebase-backend para configurar las reglas de Firestore"
"Usa el agente ai-maps para optimizar el prompt de Gemini"
"Usa el agente ux-pitch para revisar la accesibilidad de la app"
```

---

## Arquitectura del proyecto

```
tijuana_sin_barreras/
├── lib/
│   ├── main.dart                    ← Firebase init + runApp
│   ├── app.dart                     ← MaterialApp + rutas
│   ├── core/
│   │   ├── constants/
│   │   │   ├── app_colors.dart      ← Paleta accesible WCAG AA
│   │   │   ├── app_text_styles.dart ← Typography system
│   │   │   └── app_constants.dart   ← Tipos de barrera, coords Tijuana
│   │   ├── models/
│   │   │   └── barrier_report.dart  ← Modelo principal
│   │   └── services/
│   │       ├── firebase_service.dart ← Firestore + Storage + Auth
│   │       ├── maps_service.dart     ← Routes API + Places API
│   │       └── gemini_service.dart   ← Gemini API calls
│   ├── features/
│   │   ├── home/home_screen.dart    ← Pantalla inicial
│   │   ├── map/map_screen.dart      ← Mapa con marcadores
│   │   ├── report/report_barrier_screen.dart ← Formulario reporte
│   │   └── routing/route_screen.dart ← Ruta accesible
│   └── shared/widgets/              ← Componentes reutilizables
├── functions/
│   ├── index.js                     ← Cloud Functions (Gemini server-side)
│   └── package.json
├── firebase.json
├── firestore.rules
├── .env.example                     ← Variables de entorno requeridas
└── pubspec.yaml
```

---

## Variables de entorno requeridas (.env)

```
GOOGLE_MAPS_KEY=tu_key_aqui
GEMINI_API_KEY=tu_key_aqui
FIREBASE_PROJECT_ID=tu_proyecto_aqui
```

## APIs de Google habilitadas (GCP Console)

- Maps SDK for Android
- Maps SDK for iOS
- Maps JavaScript API
- Routes API
- Places API (New)
- Gemini API (via Google AI Studio)

---

## Reglas de colaboración Git

- `main` branch: siempre deployable
- Cada feature en su propio archivo — evitar conflictos
- Commit cada bloque de trabajo (mínimo cada 2h)
- Formato: `feat: descripción` / `fix: descripción` / `style: descripción`
