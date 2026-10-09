require("dotenv").config();
const express = require("express");
const cors = require("cors");
const routes = require("./routes");

const app = express();
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

const port = process.env.PORT || 3000;
app.listen(port, () => console.log(`coswim-backend escuchando en :${port}`));
