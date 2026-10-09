const { OAuth2Client } = require("google-auth-library");
const jwt = require("jsonwebtoken");

const googleClient = new OAuth2Client(process.env.GOOGLE_CLIENT_ID);

/** Verifica el idToken de Google Sign-In y devuelve {sub, email, name}. */
async function verifyGoogleIdToken(idToken) {
  const ticket = await googleClient.verifyIdToken({
    idToken,
    audience: process.env.GOOGLE_CLIENT_ID,
  });
  const payload = ticket.getPayload();
  if (!payload) throw new Error("Google ID token sin payload");
  return {
    sub: payload.sub,
    email: payload.email,
    name: payload.name,
  };
}

/** JWT propio de la API, no tiene relación con el token de Google. */
function signAppToken(userId) {
  return jwt.sign({ uid: userId }, process.env.JWT_SECRET, {
    expiresIn: "180d",
  });
}

function requireAuth(req, res, next) {
  const header = req.headers.authorization || "";
  const token = header.startsWith("Bearer ") ? header.slice(7) : null;
  if (!token) return res.status(401).json({ error: "Falta token" });

  try {
    const payload = jwt.verify(token, process.env.JWT_SECRET);
    req.userId = payload.uid;
    next();
  } catch (e) {
    res.status(401).json({ error: "Token inválido o vencido" });
  }
}

module.exports = { verifyGoogleIdToken, signAppToken, requireAuth };
