const { test, describe, before, after, beforeEach } = require("node:test");
const assert = require("node:assert/strict");
const jwt = require("jsonwebtoken");
const { googleStub, mockPool, resetGoogleStub, listen, sessionRow } = require("./helpers");
const app = require("../src/server");
const { signAppToken } = require("../src/auth");

let server;
let consoleError;

before(async () => {
  server = await listen(app);
  // El handler de errores hace console.error(err); se silencia en los tests
  // que fuerzan un 500 a propósito.
  consoleError = console.error;
  console.error = () => {};
});

after(async () => {
  console.error = consoleError;
  await server.close();
});

beforeEach(resetGoogleStub);

function call(method, path, { body, token, rawBody } = {}) {
  const headers = {};
  if (body !== undefined || rawBody !== undefined) headers["Content-Type"] = "application/json";
  if (token) headers.Authorization = `Bearer ${token}`;
  return fetch(`${server.baseUrl}${path}`, {
    method,
    headers,
    body: rawBody ?? (body === undefined ? undefined : JSON.stringify(body)),
  });
}

describe("server", () => {
  test("GET /health responde {ok: true}", async () => {
    const res = await call("GET", "/health");
    assert.equal(res.status, 200);
    assert.deepEqual(await res.json(), { ok: true });
  });

  test("no expone el header x-powered-by", async () => {
    const res = await call("GET", "/health");
    assert.equal(res.headers.get("x-powered-by"), null);
  });

  test("habilita CORS", async () => {
    const res = await call("GET", "/health");
    assert.equal(res.headers.get("access-control-allow-origin"), "*");
  });

  test("ruta inexistente responde 404", async () => {
    const res = await call("GET", "/no-existe");
    assert.equal(res.status, 404);
  });

  test("un error de la base de datos responde 500 genérico sin stack", async () => {
    mockPool(() => {
      throw new Error("connection refused");
    });
    const res = await call("GET", "/me", { token: signAppToken("u1") });
    assert.equal(res.status, 500);
    assert.deepEqual(await res.json(), { error: "Error interno" });
  });
});

describe("POST /auth/google", () => {
  test("sin idToken responde 400", async () => {
    mockPool(() => ({ rows: [] }));
    const res = await call("POST", "/auth/google", { body: {} });
    assert.equal(res.status, 400);
    assert.deepEqual(await res.json(), { error: "Falta idToken" });
  });

  test("idToken rechazado por Google responde 401 sin tocar la base", async () => {
    const { queries } = mockPool(() => ({ rows: [] }));
    googleStub.error = new Error("Invalid token signature");
    const res = await call("POST", "/auth/google", { body: { idToken: "malo" } });
    assert.equal(res.status, 401);
    assert.deepEqual(await res.json(), { error: "idToken de Google inválido" });
    assert.equal(queries.length, 0);
  });

  test("idToken válido hace upsert del usuario y devuelve JWT propio", async () => {
    googleStub.payload = { sub: "g-42", email: "ana@example.com", name: "Ana" };
    const { queries } = mockPool(() => ({
      rows: [{ id: "uuid-1", email: "ana@example.com", display_name: "Ana" }],
    }));

    const res = await call("POST", "/auth/google", { body: { idToken: "bueno" } });
    assert.equal(res.status, 200);
    const data = await res.json();
    assert.deepEqual(data.user, { id: "uuid-1", email: "ana@example.com", displayName: "Ana" });
    assert.equal(jwt.verify(data.token, process.env.JWT_SECRET).uid, "uuid-1");

    assert.equal(queries.length, 1);
    assert.match(queries[0].sql, /INSERT INTO users/);
    assert.match(queries[0].sql, /ON CONFLICT \(google_sub\)/);
    assert.deepEqual(queries[0].params, ["g-42", "ana@example.com", "Ana"]);
  });

  test("falla de la base durante el upsert responde 500", async () => {
    mockPool(() => {
      throw new Error("db caída");
    });
    const res = await call("POST", "/auth/google", { body: { idToken: "bueno" } });
    assert.equal(res.status, 500);
  });
});

describe("GET /me", () => {
  test("sin token responde 401", async () => {
    const res = await call("GET", "/me");
    assert.equal(res.status, 401);
  });

  test("devuelve el usuario autenticado", async () => {
    const { queries } = mockPool(() => ({
      rows: [{ id: "u1", email: "a@b.com", display_name: "Ana" }],
    }));
    const res = await call("GET", "/me", { token: signAppToken("u1") });
    assert.equal(res.status, 200);
    assert.deepEqual(await res.json(), { id: "u1", email: "a@b.com", displayName: "Ana" });
    assert.deepEqual(queries[0].params, ["u1"]);
  });

  test("usuario inexistente responde 404", async () => {
    mockPool(() => ({ rows: [] }));
    const res = await call("GET", "/me", { token: signAppToken("fantasma") });
    assert.equal(res.status, 404);
    assert.deepEqual(await res.json(), { error: "No existe" });
  });
});

describe("GET /sessions", () => {
  test("sin token responde 401", async () => {
    const res = await call("GET", "/sessions");
    assert.equal(res.status, 401);
  });

  test("devuelve las sesiones del usuario con la forma de SwimSession.toJson", async () => {
    const { queries } = mockPool(() => ({ rows: [sessionRow()] }));
    const res = await call("GET", "/sessions", { token: signAppToken("u1") });
    assert.equal(res.status, 200);
    const { sessions } = await res.json();
    assert.equal(sessions.length, 1);
    assert.deepEqual(sessions[0], {
      id: "1767261600000",
      startTime: "2026-01-01T10:00:00.000Z",
      endTime: "2026-01-01T10:30:00.000Z",
      distance: 1500,
      calories: 320,
      averageHeartRate: 135,
      maxHeartRate: 168,
      heartRateSeries: [{ time: "2026-01-01T10:00:00.000Z", bpm: 120 }],
      spo2: 97,
      waterTemperature: 27,
      averageSpeed: 0.83,
      activityType: "SWIMMING_POOL",
      laps: [],
      segments: [],
      speedSeries: [],
      spo2Series: [],
      calorieSeries: [],
      stepSeries: [],
    });
    assert.match(queries[0].sql, /WHERE user_id = \$1 ORDER BY start_time DESC/);
    assert.deepEqual(queries[0].params, ["u1"]);
  });

  test("usuario sin sesiones recibe lista vacía", async () => {
    mockPool(() => ({ rows: [] }));
    const res = await call("GET", "/sessions", { token: signAppToken("u1") });
    assert.deepEqual(await res.json(), { sessions: [] });
  });

  test("respeta el orden que devuelve la base", async () => {
    mockPool(() => ({
      rows: [sessionRow({ external_id: "b" }), sessionRow({ external_id: "a" })],
    }));
    const res = await call("GET", "/sessions", { token: signAppToken("u1") });
    const { sessions } = await res.json();
    assert.deepEqual(sessions.map((s) => s.id), ["b", "a"]);
  });
});

describe("POST /sessions/sync", () => {
  const fullSession = {
    id: "s1",
    startTime: "2026-01-01T10:00:00.000Z",
    endTime: "2026-01-01T10:30:00.000Z",
    distance: 1000,
    calories: 250,
    averageHeartRate: 130,
    maxHeartRate: 160,
    spo2: 96,
    waterTemperature: 26.5,
    averageSpeed: 0.55,
    activityType: "SWIMMING_POOL",
    heartRateSeries: [{ time: "2026-01-01T10:00:00.000Z", bpm: 110 }],
    laps: [{ lengthMeters: 25 }],
    segments: [],
    speedSeries: [],
    spo2Series: [],
    calorieSeries: [],
    stepSeries: [],
  };

  test("sin token responde 401", async () => {
    const res = await call("POST", "/sessions/sync", { body: { sessions: [] } });
    assert.equal(res.status, 401);
  });

  test("sessions que no es array responde 400", async () => {
    mockPool(() => ({ rows: [] }));
    const res = await call("POST", "/sessions/sync", {
      token: signAppToken("u1"),
      body: { sessions: "nope" },
    });
    assert.equal(res.status, 400);
    assert.deepEqual(await res.json(), { error: "Falta sessions (array)" });
  });

  test("sin campo sessions responde 400", async () => {
    mockPool(() => ({ rows: [] }));
    const res = await call("POST", "/sessions/sync", { token: signAppToken("u1"), body: {} });
    assert.equal(res.status, 400);
  });

  test("hace upsert dentro de una transacción y devuelve el historial", async () => {
    const { queries, client } = mockPool((sql) =>
      /SELECT \* FROM swim_sessions/.test(sql) ? { rows: [sessionRow({ external_id: "s1" })] } : { rows: [] }
    );
    const res = await call("POST", "/sessions/sync", {
      token: signAppToken("u1"),
      body: { sessions: [fullSession] },
    });
    assert.equal(res.status, 200);
    const { sessions } = await res.json();
    assert.deepEqual(sessions.map((s) => s.id), ["s1"]);

    const clientSql = queries.filter((q) => q.via === "client").map((q) => q.sql.trim().split(/\s+/)[0]);
    assert.deepEqual(clientSql, ["BEGIN", "INSERT", "COMMIT"]);
    assert.equal(client.released, true);
  });

  test("manda los 19 parámetros en el orden de la tabla", async () => {
    const { queries } = mockPool(() => ({ rows: [] }));
    await call("POST", "/sessions/sync", {
      token: signAppToken("u1"),
      body: { sessions: [fullSession] },
    });
    const insert = queries.find((q) => /INSERT INTO swim_sessions/.test(q.sql));
    assert.deepEqual(insert.params, [
      "u1",
      "s1",
      "2026-01-01T10:00:00.000Z",
      "2026-01-01T10:30:00.000Z",
      1000,
      250,
      130,
      160,
      96,
      26.5,
      0.55,
      "SWIMMING_POOL",
      JSON.stringify(fullSession.heartRateSeries),
      JSON.stringify(fullSession.laps),
      "[]",
      "[]",
      "[]",
      "[]",
      "[]",
    ]);
  });

  test("completa con valores por defecto los campos que faltan", async () => {
    const { queries } = mockPool(() => ({ rows: [] }));
    await call("POST", "/sessions/sync", {
      token: signAppToken("u1"),
      body: { sessions: [{ id: "min", startTime: "a", endTime: "b" }] },
    });
    const insert = queries.find((q) => /INSERT INTO swim_sessions/.test(q.sql));
    assert.deepEqual(insert.params, [
      "u1", "min", "a", "b", 0, 0, null, null, null, null, null, null,
      "[]", "[]", "[]", "[]", "[]", "[]", "[]",
    ]);
  });

  test("un insert por cada sesión recibida", async () => {
    const { queries } = mockPool(() => ({ rows: [] }));
    await call("POST", "/sessions/sync", {
      token: signAppToken("u1"),
      body: { sessions: [fullSession, { ...fullSession, id: "s2" }, { ...fullSession, id: "s3" }] },
    });
    const inserts = queries.filter((q) => /INSERT INTO swim_sessions/.test(q.sql));
    assert.deepEqual(inserts.map((q) => q.params[1]), ["s1", "s2", "s3"]);
  });

  test("lista vacía no inserta nada pero igual devuelve el historial", async () => {
    const { queries } = mockPool((sql) =>
      /SELECT/.test(sql) ? { rows: [sessionRow()] } : { rows: [] }
    );
    const res = await call("POST", "/sessions/sync", {
      token: signAppToken("u1"),
      body: { sessions: [] },
    });
    assert.equal(res.status, 200);
    assert.equal((await res.json()).sessions.length, 1);
    assert.equal(queries.filter((q) => /INSERT/.test(q.sql)).length, 0);
  });

  test("si un insert falla hace ROLLBACK, libera el cliente y responde 500", async () => {
    const { queries, client } = mockPool((sql) => {
      if (/INSERT/.test(sql)) throw new Error("violación de constraint");
      return { rows: [] };
    });
    const res = await call("POST", "/sessions/sync", {
      token: signAppToken("u1"),
      body: { sessions: [fullSession] },
    });
    assert.equal(res.status, 500);
    const clientSql = queries.filter((q) => q.via === "client").map((q) => q.sql.trim().split(/\s+/)[0]);
    assert.deepEqual(clientSql, ["BEGIN", "INSERT", "ROLLBACK"]);
    assert.equal(client.released, true);
  });
});
