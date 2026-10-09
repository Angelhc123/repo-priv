const { Pool } = require("pg");

if (!process.env.DATABASE_URL) {
  throw new Error("Falta DATABASE_URL en el entorno (ver .env.example)");
}

// Railway expone Postgres con TLS pero con un certificado que node no valida
// por defecto contra una CA conocida; rejectUnauthorized:false es lo que
// Railway mismo recomienda en sus docs de conexión desde Node.
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: process.env.DATABASE_URL.includes("railway")
    ? { rejectUnauthorized: false }
    : undefined,
});

module.exports = { pool };
