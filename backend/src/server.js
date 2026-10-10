require("dotenv").config();
const express = require("express");
const cors = require("cors");
const routes = require("./routes");

// Sin CSRF middleware a propósito: esta API es stateless (JWT por header
// Authorization, nunca cookies/sesión), así que no hay credencial ambiente
// que el navegador adjunte solo — el ataque CSRF clásico no aplica acá.
const app = express(); // nosemgrep: javascript.express.security.audit.express-check-csurf-middleware-usage.express-check-csurf-middleware-usage
app.disable("x-powered-by"); // no anunciar el framework a quien escanee el servidor
app.use(cors());
app.use(express.json({ limit: "5mb" })); // las series HR/velocidad por sesión pueden pesar

app.get("/health", (_req, res) => res.json({ ok: true }));
app.use(routes);

// Handler de errores al final: cualquier throw/rejection de las rutas de
// arriba (ej. una query de Postgres que falla) cae acá en vez de tirar el
// stack trace crudo al cliente.
app.use((err, _req, res, _next) => {
  console.error(err);
  res.status(500).json({ error: "Error interno" });
});

// Solo escucha cuando se ejecuta directo (`node src/server.js`); los tests
// importan `app` y levantan su propio servidor en un puerto libre.
if (require.main === module) {
  const port = process.env.PORT || 3000;
  app.listen(port, () => console.log(`coswim-backend escuchando en :${port}`));
}

module.exports = app;
