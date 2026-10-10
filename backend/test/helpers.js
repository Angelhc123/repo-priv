// Utilidades compartidas por los tests del backend. Ninguno toca Postgres ni
// Google de verdad: el pool de `pg` y `OAuth2Client.verifyIdToken` se
// reemplazan por dobles antes de cargar los módulos de src/.
process.env.DATABASE_URL =
  process.env.DATABASE_URL || "postgres://user:pass@localhost:5432/coswim_test";
process.env.JWT_SECRET = process.env.JWT_SECRET || "secreto-de-prueba";
process.env.GOOGLE_CLIENT_ID = process.env.GOOGLE_CLIENT_ID || "client-id-de-prueba";

const { OAuth2Client } = require("google-auth-library");
const { pool } = require("../src/db");

/** Lo que devuelve el doble de Google en la próxima verificación. */
const googleStub = {
  calls: [],
  payload: { sub: "google-sub-1", email: "nadador@example.com", name: "Nadador" },
  error: null,
};

OAuth2Client.prototype.verifyIdToken = async function (opts) {
  googleStub.calls.push(opts);
  if (googleStub.error) throw googleStub.error;
  return { getPayload: () => googleStub.payload };
};

/**
 * Reemplaza pool.query / pool.connect por funciones que registran cada
 * llamada y responden con `handler(sql, params)`.
 */
function mockPool(handler) {
  const queries = [];
  const client = {
    released: false,
    query: async (sql, params) => {
      queries.push({ sql, params, via: "client" });
      return handler(sql, params, "client");
    },
    release() {
      this.released = true;
    },
  };
  pool.query = async (sql, params) => {
    queries.push({ sql, params, via: "pool" });
    return handler(sql, params, "pool");
  };
  pool.connect = async () => client;
  return { queries, client };
}

function resetGoogleStub() {
  googleStub.calls.length = 0;
  googleStub.payload = { sub: "google-sub-1", email: "nadador@example.com", name: "Nadador" };
  googleStub.error = null;
}

/** Levanta `app` en un puerto libre y devuelve {baseUrl, close}. */
function listen(app) {
  return new Promise((resolve) => {
    const server = app.listen(0, () => {
      const { port } = server.address();
      resolve({
        baseUrl: `http://127.0.0.1:${port}`,
        close: () => new Promise((r) => server.close(r)),
      });
    });
  });
}

function sessionRow(overrides = {}) {
  return {
    external_id: "1767261600000",
    start_time: new Date("2026-01-01T10:00:00.000Z"),
    end_time: new Date("2026-01-01T10:30:00.000Z"),
    distance: 1500,
    calories: 320,
    average_heart_rate: 135,
    max_heart_rate: 168,
    heart_rate_series: [{ time: "2026-01-01T10:00:00.000Z", bpm: 120 }],
    spo2: 97,
    water_temperature: 27,
    average_speed: 0.83,
    activity_type: "SWIMMING_POOL",
    laps: [],
    segments: [],
    speed_series: [],
    spo2_series: [],
    calorie_series: [],
    step_series: [],
    ...overrides,
  };
}

module.exports = { pool, googleStub, mockPool, resetGoogleStub, listen, sessionRow };
