# CoSwim

Aplicación móvil que lee sesiones de natación desde **Health Connect** (sincronizadas
por un reloj deportivo vía la app del fabricante, p. ej. Mi Fitness en un Redmi Watch 4)
y agrega analítica deportiva propia que esas apps no calculan: índice de eficiencia,
splits de 100 m, zonas de frecuencia cardiaca, carga de entrenamiento y recuperación de
FC. El historial se respalda en un backend propio con autenticación por Google.

## Arquitectura

```
Reloj --Bluetooth--> Mi Fitness --sync--> Health Connect --lee--> App Flutter
                                                                      |
                                                              Google Sign-In (JWT propio)
                                                                      |
                                                                      v
                                                      API CoSwim (Node.js/Express)
                                                                      |
                                                                      v
                                                          PostgreSQL (Railway)
```

- **App (`lib/`)**: Flutter, Android. La app **nunca** habla directo con la base de
  datos: todo pasa por la API propia.
- **Backend (`backend/`)**: API REST en Node.js/Express, autenticación con Google
  (sin contraseñas propias) + JWT propio, PostgreSQL. Ver [`backend/README.md`](backend/README.md)
  para endpoints, variables de entorno y despliegue en Railway.
- **Datos de salud**: se leen de Health Connect tipo por tipo (frecuencia cardiaca,
  SpO2, calorías activas, distancia, sesiones de ejercicio), para que un tipo mal
  declarado en Android no bloquee la lectura de los demás.

## Navegación de la app

Tres pestañas (`lib/screens/main_navigation.dart`), montadas una sola vez con
`IndexedStack`:

| Pestaña | Pantalla | Qué muestra |
| --- | --- | --- |
| Entrenamientos | `history_screen.dart` + `session_detail_screen.dart` | Historial de sesiones; detalle con stats, índice de eficiencia, chart de FC/SpO2, splits de 100 m. |
| Progreso | `charts_screen.dart` | Tendencias históricas y récords personales (mejor 100 m, mayor distancia, mejor índice). |
| Datos | `dashboard_screen.dart` | Vista cruda de Health Connect, para depuración. |

La lógica de métricas propias vive en `lib/utils/rules_engine.dart` (índice de
eficiencia, zonas de FC, carga de entrenamiento, recuperación de FC) y
`lib/utils/splits_calculator.dart` (splits de 100 m desde la serie de velocidad).

## Empezando

### App Flutter

```bash
flutter pub get
flutter run --dart-define=GOOGLE_SERVER_CLIENT_ID=<client_id_web> \
            --dart-define=BACKEND_URL=<url_del_backend>
```

Requiere un dispositivo Android con Health Connect disponible (nativo desde Android 14,
instalable en versiones anteriores desde Play Store) y `minSdk 26`.

### Backend

Ver [`backend/README.md`](backend/README.md): configuración de credenciales OAuth de
Google, correrlo localmente (`npm install && npm run migrate && npm run dev`) y
despliegue en Railway.

## Calidad y seguridad (CI)

GitHub Actions corre en cada push a `main` (`.github/workflows/`):

- **`ci.yml`**: `flutter analyze` + `flutter test`; verificación de sintaxis del backend.
- **`sonar.yml`**: análisis de calidad con SonarCloud.
- **`snyk.yml`**: dependencias y SAST del backend con Snyk.
- **`semgrep.yml`**: análisis estático adicional con Semgrep.

## Documentación del proyecto

En [`docs/`](docs/) está la documentación formal del curso (Escuela Profesional de
Ingeniería de Sistemas, UPT): Informe de Factibilidad, Documento de Visión,
Especificación de Requerimientos, Arquitectura de Software, Informe Final y Propuesta
de Proyecto — cada uno como `.md` (fuente) y `.docx` (formato institucional).

Para regenerar los `.docx` después de editar un `.md`:

```bash
cd docs/tools
npm install        # solo la primera vez
node md-to-word.js # regenera todos; o pasale un archivo puntual como argumento
```

## Limitaciones conocidas

- Solo Android: no hay integración con HealthKit (iOS) en este alcance.
- Las métricas dependen de lo que el fabricante del wearable efectivamente escriba en
  Health Connect — por ejemplo, Mi Fitness no exporta `SpeedRecord` para todos los
  modos de ejercicio del reloj, así que los splits de 100 m no siempre están
  disponibles.
- El `applicationId` sigue en `com.example.coswim` (placeholder) — cambiarlo es un
  paso pendiente antes de cualquier publicación.
