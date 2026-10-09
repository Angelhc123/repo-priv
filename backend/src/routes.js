const express = require("express");
const { pool } = require("./db");
const { verifyGoogleIdToken, signAppToken, requireAuth } = require("./auth");

const router = express.Router();

// Express 4 no reenvía rechazos de promesas al error handler por su cuenta;
// sin esto, una query de Postgres que falla deja la request colgada en vez
// de responder 500.
const h = (fn) => (req, res, next) => fn(req, res, next).catch(next);

// ── AUTH ─────────────────────────────────────────────────────────────────

router.post("/auth/google", h(async (req, res) => {
  const { idToken } = req.body;
  if (!idToken) return res.status(400).json({ error: "Falta idToken" });

  let profile;
  try {
    profile = await verifyGoogleIdToken(idToken);
  } catch (e) {
    return res.status(401).json({ error: "idToken de Google inválido" });
  }

  const { rows } = await pool.query(
    `INSERT INTO users (google_sub, email, display_name)
     VALUES ($1, $2, $3)
     ON CONFLICT (google_sub)
     DO UPDATE SET email = EXCLUDED.email, display_name = EXCLUDED.display_name
     RETURNING id, email, display_name`,
    [profile.sub, profile.email, profile.name]
  );
  const user = rows[0];
  const token = signAppToken(user.id);

  res.json({
    token,
    user: { id: user.id, email: user.email, displayName: user.display_name },
  });
}));

router.get("/me", requireAuth, h(async (req, res) => {
  const { rows } = await pool.query(
    "SELECT id, email, display_name FROM users WHERE id = $1",
    [req.userId]
  );
  if (rows.length === 0) return res.status(404).json({ error: "No existe" });
  const u = rows[0];
  res.json({ id: u.id, email: u.email, displayName: u.display_name });
}));

// ── SESIONES ─────────────────────────────────────────────────────────────

// Misma forma que SwimSession.toJson()/fromJson() en swim_session.dart, así
// el cliente Flutter no necesita un parser distinto para lo que viene de la API.
function rowToSession(row) {
  return {
    id: row.external_id,
    startTime: row.start_time.toISOString(),
    endTime: row.end_time.toISOString(),
    distance: row.distance,
    calories: row.calories,
    averageHeartRate: row.average_heart_rate,
    maxHeartRate: row.max_heart_rate,
    heartRateSeries: row.heart_rate_series,
    spo2: row.spo2,
    waterTemperature: row.water_temperature,
    averageSpeed: row.average_speed,
    activityType: row.activity_type,
    laps: row.laps,
    segments: row.segments,
    speedSeries: row.speed_series,
    spo2Series: row.spo2_series,
    calorieSeries: row.calorie_series,
    stepSeries: row.step_series,
  };
}

router.get("/sessions", requireAuth, h(async (req, res) => {
  const { rows } = await pool.query(
    "SELECT * FROM swim_sessions WHERE user_id = $1 ORDER BY start_time DESC",
    [req.userId]
  );
  res.json({ sessions: rows.map(rowToSession) });
}));

router.post("/sessions/sync", requireAuth, h(async (req, res) => {
  const sessions = req.body.sessions;
  if (!Array.isArray(sessions)) {
    return res.status(400).json({ error: "Falta sessions (array)" });
  }

  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    for (const s of sessions) {
      await client.query(
        `INSERT INTO swim_sessions (
           user_id, external_id, start_time, end_time, distance, calories,
           average_heart_rate, max_heart_rate, spo2, water_temperature,
           average_speed, activity_type, heart_rate_series, laps, segments,
           speed_series, spo2_series, calorie_series, step_series
         ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19)
         ON CONFLICT (user_id, external_id) DO UPDATE SET
           end_time = EXCLUDED.end_time,
           distance = EXCLUDED.distance,
           calories = EXCLUDED.calories,
           average_heart_rate = EXCLUDED.average_heart_rate,
           max_heart_rate = EXCLUDED.max_heart_rate,
           spo2 = EXCLUDED.spo2,
           water_temperature = EXCLUDED.water_temperature,
           average_speed = EXCLUDED.average_speed,
           activity_type = EXCLUDED.activity_type,
           heart_rate_series = EXCLUDED.heart_rate_series,
           laps = EXCLUDED.laps,
           segments = EXCLUDED.segments,
           speed_series = EXCLUDED.speed_series,
           spo2_series = EXCLUDED.spo2_series,
           calorie_series = EXCLUDED.calorie_series,
           step_series = EXCLUDED.step_series,
           updated_at = now()`,
        [
          req.userId,
          s.id,
          s.startTime,
          s.endTime,
          s.distance ?? 0,
          s.calories ?? 0,
          s.averageHeartRate ?? null,
          s.maxHeartRate ?? null,
          s.spo2 ?? null,
          s.waterTemperature ?? null,
          s.averageSpeed ?? null,
          s.activityType ?? null,
          JSON.stringify(s.heartRateSeries ?? []),
          JSON.stringify(s.laps ?? []),
          JSON.stringify(s.segments ?? []),
          JSON.stringify(s.speedSeries ?? []),
          JSON.stringify(s.spo2Series ?? []),
          JSON.stringify(s.calorieSeries ?? []),
          JSON.stringify(s.stepSeries ?? []),
        ]
      );
    }
    await client.query("COMMIT");
  } catch (e) {
    await client.query("ROLLBACK");
    throw e;
  } finally {
    client.release();
  }

  const { rows } = await pool.query(
    "SELECT * FROM swim_sessions WHERE user_id = $1 ORDER BY start_time DESC",
    [req.userId]
  );
  res.json({ sessions: rows.map(rowToSession) });
}));

module.exports = router;
