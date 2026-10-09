require("dotenv").config();
const fs = require("fs");
const path = require("path");
const { pool } = require("./db");

async function main() {
  const sql = fs.readFileSync(path.join(__dirname, "..", "schema.sql"), "utf8");
  await pool.query(sql);
  console.log("Esquema aplicado correctamente.");
  await pool.end();
}

main().catch((err) => {
  console.error("Falló la migración:", err);
  process.exit(1);
});
