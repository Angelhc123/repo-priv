const { test, describe, afterEach } = require("node:test");
const assert = require("node:assert/strict");

const dbPath = require.resolve("../src/db");
const originalUrl = process.env.DATABASE_URL;

/** Carga src/db.js de cero con el DATABASE_URL indicado. */
function loadDbWith(url) {
  delete require.cache[dbPath];
  if (url === undefined) {
    delete process.env.DATABASE_URL;
  } else {
    process.env.DATABASE_URL = url;
  }
  return require("../src/db");
}

describe("db", () => {
  afterEach(() => {
    if (originalUrl === undefined) {
      delete process.env.DATABASE_URL;
    } else {
      process.env.DATABASE_URL = originalUrl;
    }
    delete require.cache[dbPath];
  });

  test("lanza error claro si falta DATABASE_URL", () => {
    assert.throws(() => loadDbWith(undefined), /Falta DATABASE_URL/);
  });

  test("exporta un pool con la cadena de conexión configurada", () => {
    const { pool } = loadDbWith("postgres://u:p@localhost:5432/x");
    assert.equal(pool.options.connectionString, "postgres://u:p@localhost:5432/x");
  });

  test("sin TLS para una base que no es de Railway", () => {
    const { pool } = loadDbWith("postgres://u:p@localhost:5432/x");
    assert.equal(pool.options.ssl, undefined);
  });

  test("con TLS sin validar CA para una base de Railway", () => {
    const { pool } = loadDbWith("postgres://u:p@containers.railway.app:5432/railway");
    assert.deepEqual(pool.options.ssl, { rejectUnauthorized: false });
  });
});
