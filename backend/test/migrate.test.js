const { test, describe } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("fs");
const path = require("path");
const { pool } = require("./helpers");

describe("migrate", () => {
  test("requerirlo no ejecuta la migración por sí solo", () => {
    let called = false;
    pool.query = async () => {
      called = true;
    };
    require("../src/migrate");
    assert.equal(called, false);
  });

  test("main() aplica schema.sql completo y cierra el pool", async () => {
    const executed = [];
    let ended = false;
    pool.query = async (sql) => {
      executed.push(sql);
    };
    pool.end = async () => {
      ended = true;
    };
    const originalLog = console.log;
    console.log = () => {};
    try {
      await require("../src/migrate").main();
    } finally {
      console.log = originalLog;
    }
    const schema = fs.readFileSync(path.join(__dirname, "..", "schema.sql"), "utf8");
    assert.deepEqual(executed, [schema]);
    assert.equal(ended, true);
  });

  test("main() propaga el error si la query falla", async () => {
    pool.query = async () => {
      throw new Error("permiso denegado");
    };
    await assert.rejects(require("../src/migrate").main(), /permiso denegado/);
  });
});
