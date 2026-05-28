# HackFox 2026 — Chackethon Developers
## Reto: Tijuana Sin Barreras

---

## 1. MVP — Funcionalidades MÍNIMAS (sí o sí)

### Core Features (sin estas = descalificación)
- [ ] **Mapa con marcadores de barreras** — Firebase Realtime + Google Maps Flutter
- [ ] **Reporte de barrera con foto + GPS** — Firebase Storage + Firestore
- [ ] **Análisis IA de la foto** — Gemini API clasifica tipo y riesgo automáticamente
- [ ] **Ruta peatonal accesible** — Google Routes API (travelMode: WALK)
- [ ] **Búsqueda de destino** — Places API con sesgo a Tijuana

### Features que suman puntos (si hay tiempo)
- [ ] Login anónimo (Firebase Auth — 30 min)
- [ ] Filtros de mapa por tipo de barrera
- [ ] Score de accesibilidad de ruta con IA
- [ ] Estadísticas en BigQuery (número de barreras por colonia)

### NO hacer (mata el tiempo)
- ❌ Sistema de usuario completo con perfiles
- ❌ Notificaciones push
- ❌ Modo offline
- ❌ Multilenguaje

---

## 2. Arquitectura de Flujo de Datos

```
[Usuario Flutter App]
        |
        ├─── GPS/Cámara ──────────────────────────────────────────┐
        │                                                          │
        ├─── Firebase Auth (anon) ──→ UID                         │
        │                                                          ▼
        ├─── Reporte de Barrera ──→ [Cloud Firestore: /barriers]  │
        │         │                          │                     │
        │         │                          ├─→ [Firebase Storage: /barriers/{id}.jpg]
        │         │                          │
        │         └─── Cloud Function ───────┤
        │               (onBarrierCreate)    └─→ [Gemini API]
        │                                         (analyzeBarrierPhoto)
        │                                              │
        │                                         geminiAnalysis ──→ Firestore update
        │
        ├─── Ver Mapa ──→ Stream Firestore ──→ Markers en Google Maps
        │
        └─── Calcular Ruta ──→ [Routes API v2 (WALK)] ──→ Polyline en mapa
                    │
                    └─→ [Places API] ──→ Geocodificar origen/destino
```

**Stack de producción:**
- Flutter → Firebase Hosting (web) / APK directo (Android)
- Cloud Functions → Node.js 20 (Gemini calls server-side)
- BigQuery → Dashboard de métricas (opcional, demo en pitch)

---

## 3. Plan de Trabajo por Horas

### DÍA 1 — Viernes

#### Bloque 0: CHECK-IN (8:00–9:00 AM) — 1h
- [ ] Todos: instalar Flutter, VS Code, activar APIs de Google Cloud
- [ ] Backend: crear proyecto Firebase, habilitar Firestore + Storage + Functions
- [ ] IA: crear API key de Gemini en Google AI Studio
- [ ] Maps: habilitar Maps SDK, Routes API, Places API en GCP Console
- [ ] Crear `.env` con todas las keys

#### Bloque 1: FUNDAMENTOS (9:00–11:00 AM) — 2h
- Flutter: esqueleto de app (nav, pantallas vacías, theme)
- Backend: schema Firestore + reglas + index.js Cloud Function vacío
- IA: test de Maps API con curl/Postman (verificar que funciona)
- UX: wireframes en Excalidraw o papel (HOME + MAPA + REPORTE)

#### Bloque 2: CORE FEATURES (11:00 AM–2:00 PM) — 3h
- Flutter: pantalla Mapa con Google Maps + Stream de barreras
- Backend: submitBarrierReport() + uploadPhoto() funcionando
- IA: Gemini analyzeBarrierPhoto() integrado en Cloud Function
- UX: pantalla de Reporte (formulario completo)

#### ALMUERZO + GIT SYNC (2:00–3:00 PM) — 1h
- **Commit obligatorio**: `feat: core map and report screens`
- Resolver conflictos git (ver sección 7)
- Cada quien come y descansa 20 min

#### Bloque 3: INTEGRACIÓN (3:00–7:00 PM) — 4h
- Flutter: pantalla de Ruta (Routes API + Polyline)
- Backend: Cloud Function deployada y probada
- IA: Places API search + decode polyline
- UX: polish UI (colores, accesibilidad, iconos SVG)

#### Bloque 4: DEMO FLOW (7:00–9:00 PM) — 2h
- **Todos juntos**: probar el flujo completo end-to-end
- Flutter: fix bugs críticos de integración
- Backend: deploy Firebase Hosting (`firebase deploy`)
- UX: prepara slides del pitch (Canva/Google Slides)
- **Commit**: `feat: full MVP integration complete`

#### CENA + BREAK (9:00–10:00 PM) — 1h
- ⚠️ Menores de edad salen a las 10 PM
- Comer y descansar (obligatorio — claridad mental)

#### Bloque 5: POLISH NOCTURNO (10:00 PM–2:00 AM) — 4h
- Flutter: animaciones suaves, loading states, error handling
- Backend: reglas Firestore de seguridad
- IA: prompt Gemini refinado + respuesta JSON estructurada
- UX: métricas para el pitch (barreras reportadas, distancia ahorrada)
- **Commit**: `feat: UI polish and error handling`

---

### DÍA 2 — Sábado

#### DORMIR (2:00–6:00 AM) — 4h OBLIGATORIO
- Sin sueño = pitch pésimo = pierden
- Alarma a las 6:00 AM

#### Bloque 6: FINAL SPRINT (6:00–8:00 AM) — 2h
- Hacer un run completo de la demo en dispositivo físico
- Fix SOLO bugs que rompen la demo (no nuevas features)
- **Commit final**: `release: v1.0.0-hackfox2026`
- Deploy final a Firebase Hosting

#### PREPARACIÓN PITCH (8:00–9:30 AM) — 1.5h
- 3 ensayos del pitch de 3 minutos
- Cargar APK en teléfono del presentador
- Verificar que el demo funciona sin internet (fallback con screenshots)
- Preparar métricas reales de la app (barreras en Firestore)

#### PRESENTACIÓN (10:00 AM aprox)
- 3 minutos exactos
- Demo en vivo en teléfono físico (no emulador)

---

## 4. Organización del Equipo por Bloque

| Bloque | Rol 1 (Flutter) | Rol 2 (Backend) | Rol 3 (IA/Maps) | Rol 4 (UX/Pitch) |
|--------|----------------|-----------------|-----------------|-------------------|
| 0 Setup | `flutter pub get` + run | Firebase Console setup | GCP Console + API keys | Wireframes papel |
| 1 Fundamentos | `app.dart` + nav | Firestore schema | Gemini + Maps test | Design tokens |
| 2 Core | MapScreen + Stream | FirebaseService | GeminiService + MapsService | ReportScreen UI |
| Almuerzo | **Git sync** | **Git sync** | **Git sync** | **Slides inicio** |
| 3 Integración | RouteScreen | Cloud Functions deploy | Routes API polyline | UI polish |
| 4 Demo Flow | Bug fixes | firebase deploy | Places API search | Pitch deck |
| 5 Nocturno | Animaciones | Firestore rules | Prompt refinement | Métricas |
| 6 Final Sprint | Demo run | Final deploy | API fallbacks | Ensayo pitch |
| Pitch Prep | Soporte técnico | Monitor Firebase | Soporte técnico | **Presenta** |

**Regla de oro**: nadie toca el mismo archivo al mismo tiempo. Si necesitas un archivo de otro, lo pides con anticipación.

---

## 5. Checklist de Entregables GitHub

### Commits mínimos requeridos (auditados)
```
git log --oneline
feat: initial project setup with Flutter and Firebase
feat: core map screen with barrier markers
feat: report barrier form with photo upload
feat: Gemini AI photo analysis integration
feat: accessible route calculation with Routes API
feat: full MVP integration complete
feat: UI polish and accessibility improvements
release: v1.0.0-hackfox2026
```

### Archivos obligatorios en el repo
```
tijuana_sin_barreras/
├── lib/                          ← código fuente completo
├── functions/index.js            ← Cloud Functions
├── firebase.json                 ← config Firebase Hosting
├── firestore.rules               ← reglas de seguridad
├── .env.example                  ← keys SIN valores reales
├── pubspec.yaml                  ← con todas las dependencias
└── README.md                     ← descripción del proyecto
```

### README.md debe incluir
- [ ] Descripción del problema (accesibilidad en Tijuana)
- [ ] Capturas de pantalla de la app
- [ ] Instrucciones de instalación
- [ ] APIs utilizadas (Maps, Gemini, Firebase)
- [ ] Nombre del equipo y hackathon

### Lo que NO debe estar en el repo
- [ ] `.env` con API keys reales → usar `.env.example`
- [ ] `google-services.json` en texto plano → añadir a `.gitignore`
- [ ] `build/` folders

---

## 6. Estrategia de Pitch — 3 Minutos Exactos

### Estructura (cronometrada)
```
0:00–0:30 | GANCHO + PROBLEMA
0:30–1:15 | SOLUCIÓN (demo rápida)
1:15–2:15 | DEMO EN VIVO
2:15–2:45 | IMPACTO + MÉTRICAS
2:45–3:00 | CIERRE
```

### Guión de referencia

**GANCHO (0:00–0:30)**
> "En Tijuana hay 47,000 personas con discapacidad motriz. Para ellas, un simple paso sin rampa puede significar dar 10 cuadras de rodeo... o no salir de casa."

**SOLUCIÓN (0:30–1:15)**
> "Tijuana Sin Barreras es una app que hace dos cosas: te calcula la ruta peatonal más accesible usando Google Maps y Gemini AI, y permite que cualquier ciudadano reporte barreras con foto — la IA las clasifica y prioriza automáticamente."

**DEMO EN VIVO (1:15–2:15)**
1. Abrir app → mostrar mapa con barreras ya reportadas
2. Reportar una barrera nueva con foto → "Gemini la analiza: Rampa faltante, riesgo ALTO"
3. Calcular ruta accesible → mostrar polyline en mapa
4. "Todo en tiempo real, sin servidores propios — Firebase + Google Cloud"

**MÉTRICAS (2:15–2:45)**
> - "En 26 horas agregamos [X] barreras reales de Tijuana al mapa"
> - "La IA de Gemini clasifica una barrera en menos de 3 segundos"
> - "Ruta accesible calculada vs. ruta normal: promedio 15% menos obstáculos"
> - "Costo de operación: $0 en las primeras 10,000 peticiones/mes (Firebase free tier)"

**CIERRE (2:45–3:00)**
> "Tijuana Sin Barreras no es solo una app — es infraestructura ciudadana de datos de accesibilidad. El mismo modelo puede escalarse a cualquier ciudad de México."

### Qué tener listo para el pitch
- [ ] APK instalado en teléfono físico (no emulador)
- [ ] 5+ barreras pre-cargadas en Firestore (que el mapa no esté vacío)
- [ ] Ruta de demo lista: "Centro Cívico → Hospital General de Tijuana"
- [ ] Firebase Hosting URL funcionando (backup si el teléfono falla)
- [ ] Slide con arquitectura técnica (1 slide)
- [ ] Slide con métricas (1 slide)

---

## 7. Bloqueos Frecuentes y Soluciones Rápidas

### API Keys / Google Cloud
| Problema | Solución inmediata |
|----------|-------------------|
| Maps API da 403 | Verificar que Routes API y Maps SDK estén habilitados en GCP Console |
| Gemini API key inválida | Usar Google AI Studio (aistudio.google.com) — gratis sin tarjeta |
| Places API no retorna resultados | Añadir `location=32.5149,-117.0382&radius=10000` al request |
| Routes API no retorna ruta | Cambiar `travelMode` a `DRIVE` de emergencia |

### Flutter / Build
| Problema | Solución inmediata |
|----------|-------------------|
| `flutter pub get` falla | `flutter clean && flutter pub get` |
| Google Maps no carga en Android | Verificar meta-data con API key en AndroidManifest.xml |
| Build iOS falla | Ignorar — solo entregar Android/Web |
| Hot reload rompe estado | `r` para hot reload, `R` para hot restart |

### Firebase / Backend
| Problema | Solución inmediata |
|----------|-------------------|
| Firestore permission denied | Cambiar reglas a `allow read, write: if true;` (solo para demo) |
| Upload de foto falla | Verificar Storage rules y que firebase init se ejecutó |
| Cloud Functions no deploya | Usar Gemini directo desde Flutter (sin Cloud Functions) |
| Firebase init rompe el proyecto | Usar `firebase use --add` para seleccionar el proyecto correcto |

### Git
| Problema | Solución inmediata |
|----------|-------------------|
| Merge conflict en pubspec.yaml | Aceptar la versión con MÁS dependencias y hacer `flutter pub get` |
| Conflict en main.dart | El que más avanzado esté gana, el otro integra su código manualmente |
| Accidentalmente borraste código | `git checkout HEAD~1 -- lib/features/pantalla.dart` |
| Push rejected | `git pull --rebase origin main` |

### Equipos / Humanos
| Problema | Solución |
|----------|----------|
| Sueño (>2AM) | Dormir 3-4h es mejor que código con bugs a las 5AM |
| Bloqueo técnico >30min | Pedir ayuda a mentor del hackathon o cambiar de enfoque |
| Frontend y backend no sincronizan | Definir interfaz (modelo Dart + schema Firestore) juntos ANTES de codear |
| El presentador está nervioso | Ensayar 3 veces exactamente, cronómetro en mano |

---

## Contactos de Emergencia (durante el hackathon)
- Mentor técnico del evento: preguntar en check-in
- Firebase Emergency: console.firebase.google.com
- Gemini Docs: aistudio.google.com
- Routes API Docs: developers.google.com/maps/documentation/routes
