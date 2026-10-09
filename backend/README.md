# coswim-backend

API de CoSwim: autenticación con Google (sin contraseñas propias) y
almacenamiento de sesiones de nado en Postgres. La app Flutter nunca habla
directo con la base de datos — todo pasa por esta API.

## Endpoints

| Método | Ruta              | Auth | Qué hace |
|--------|-------------------|------|----------|
| POST   | `/auth/google`    | —    | Canjea el idToken de Google por un JWT propio. Crea el usuario si no existía. |
| GET    | `/me`             | JWT  | Datos del usuario autenticado. |
| GET    | `/sessions`       | JWT  | Historial completo del usuario. |
| POST   | `/sessions/sync`  | JWT  | Sube/actualiza sesiones (upsert por `external_id`) y devuelve el historial completo actualizado. |

Las sesiones viajan con las mismas claves que `SwimSession.toJson()` en
`lib/models/swim_session.dart` (`startTime`, `heartRateSeries`, etc.), así
que el parser de Flutter (`SwimSession.fromJson`) sirve sin tocarlo.

## 1. Google Cloud — crear credenciales OAuth

En [Google Cloud Console](https://console.cloud.google.com/) → *APIs & Services
→ Credentials*, dentro de un proyecto (podés crear uno nuevo solo para esto):

1. **OAuth consent screen**: tipo "External", agregá tu email como test user
   si lo dejás en modo "Testing".
2. **Credential → OAuth client ID → tipo "Android"**:
   - Package name: el `applicationId` de `android/app/build.gradle` (hoy es
     el placeholder `com.example.coswim` — considerá cambiarlo a algo real
     antes de este paso, es una decisión tuya, no la tomé por vos).
   - SHA-1: sacalo con
     `keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android`
     (debug keystore; cuando firmes para producción hay que repetir esto con
     el keystore de release).
   - Este client ID no se usa como variable en ningún lado — Google lo
     detecta solo por package+SHA-1 al mostrar el selector de cuenta.
3. **Credential → OAuth client ID → tipo "Web application"**: no necesita
   redirect URIs para este flujo. Este es el que sí se usa:
   - Backend: `GOOGLE_CLIENT_ID` en `.env`.
   - Flutter: `--dart-define=GOOGLE_SERVER_CLIENT_ID=ese_mismo_id`.

## 2. Correrlo localmente

```bash
cp .env.example .env
# completá DATABASE_URL (podés usar un Postgres local o uno de Railway) y
# GOOGLE_CLIENT_ID con el client ID "Web application" del paso anterior.
# Generá JWT_SECRET con:
node -e "console.log(require('crypto').randomBytes(48).toString('hex'))"

npm install
npm run migrate   # aplica backend/schema.sql
npm run dev        # http://localhost:3000, reinicia solo al guardar
```

Probar rápido sin Flutter:

```bash
curl http://localhost:3000/health
# {"ok":true}
```

## 3. Deploy en Railway

1. `railway init` (o creá el proyecto desde el dashboard) apuntando a esta
   carpeta `backend/` como root del servicio.
2. Agregá el addon de **PostgreSQL** desde el dashboard de Railway — te da
   la variable `DATABASE_URL` automáticamente, pegala en las variables del
   servicio del backend (o dejá que Railway la comparta si quedan en el
   mismo proyecto).
3. Variables del servicio: `GOOGLE_CLIENT_ID`, `JWT_SECRET` (las de arriba).
   `PORT` lo define Railway solo.
4. Deploy. Después corré la migración una vez contra esa base — por ejemplo
   con `railway run npm run migrate` desde tu máquina, o conectándote con el
   `DATABASE_URL` que te dio Railway.
5. Railway te da una URL pública (`https://tu-servicio.up.railway.app`) — esa
   es la que va en `--dart-define=BACKEND_URL=...` del lado Flutter.

## Notas de diseño

- **Por qué JSONB para las series** (`heart_rate_series`, `speed_series`,
  `spo2_series`, `laps`, `segments`): hoy nada las consulta por adentro (ni
  filtra ni agrega sobre puntos individuales en el servidor), solo se leen
  completas para mostrarlas en la app. Normalizarlas en tablas propias sería
  trabajo sin beneficio real ahora; si en el futuro se necesita, por ejemplo,
  "todas las sesiones con un pico de HR > X", ahí sí conviene una tabla aparte.
- **Por qué `external_id` y no solo el `id` de Postgres**: el `id` que ya
  genera `SwimSession` en el teléfono (hoy: epoch ms del inicio) es lo único
  estable que tiene el dispositivo para identificar "esta sesión" entre
  sincronizaciones repetidas. `UNIQUE (user_id, external_id)` + `ON CONFLICT
  DO UPDATE` es lo que hace que resubir la misma sesión actualice en vez de
  duplicar.
