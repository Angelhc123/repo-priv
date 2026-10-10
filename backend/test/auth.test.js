const { test, describe, beforeEach } = require("node:test");
const assert = require("node:assert/strict");
const jwt = require("jsonwebtoken");
const { googleStub, resetGoogleStub } = require("./helpers");
const { verifyGoogleIdToken, signAppToken, requireAuth } = require("../src/auth");

/** Ejecuta requireAuth con una request falsa y captura la respuesta. */
function runRequireAuth(authorization) {
  const req = { headers: authorization === undefined ? {} : { authorization } };
  const res = {
    statusCode: 200,
    body: undefined,
    status(code) {
      this.statusCode = code;
      return this;
    },
    json(body) {
      this.body = body;
      return this;
    },
  };
  let nextCalled = false;
  requireAuth(req, res, () => {
    nextCalled = true;
  });
  return { req, res, nextCalled };
}

describe("signAppToken", () => {
  test("firma un JWT con el uid del usuario", () => {
    const token = signAppToken("user-123");
    const payload = jwt.verify(token, process.env.JWT_SECRET);
    assert.equal(payload.uid, "user-123");
  });

  test("el token vence a los 180 días", () => {
    const payload = jwt.decode(signAppToken("u"));
    assert.equal(payload.exp - payload.iat, 180 * 24 * 60 * 60);
  });

  test("no se puede verificar con otro secreto", () => {
    const token = signAppToken("u");
    assert.throws(() => jwt.verify(token, "otro-secreto"));
  });
});

describe("requireAuth", () => {
  test("sin header Authorization responde 401 'Falta token'", () => {
    const { res, nextCalled } = runRequireAuth(undefined);
    assert.equal(res.statusCode, 401);
    assert.deepEqual(res.body, { error: "Falta token" });
    assert.equal(nextCalled, false);
  });

  test("header sin prefijo Bearer responde 401 'Falta token'", () => {
    const { res, nextCalled } = runRequireAuth(signAppToken("u"));
    assert.equal(res.statusCode, 401);
    assert.deepEqual(res.body, { error: "Falta token" });
    assert.equal(nextCalled, false);
  });

  test("'Bearer ' vacío responde 401 'Falta token'", () => {
    const { res } = runRequireAuth("Bearer ");
    assert.equal(res.statusCode, 401);
    assert.deepEqual(res.body, { error: "Falta token" });
  });

  test("token mal formado responde 401 'Token inválido o vencido'", () => {
    const { res, nextCalled } = runRequireAuth("Bearer no-es-un-jwt");
    assert.equal(res.statusCode, 401);
    assert.deepEqual(res.body, { error: "Token inválido o vencido" });
    assert.equal(nextCalled, false);
  });

  test("token firmado con otro secreto responde 401", () => {
    const forged = jwt.sign({ uid: "u" }, "otro-secreto");
    const { res } = runRequireAuth(`Bearer ${forged}`);
    assert.equal(res.statusCode, 401);
  });

  test("token vencido responde 401", () => {
    const expired = jwt.sign({ uid: "u" }, process.env.JWT_SECRET, { expiresIn: -10 });
    const { res, nextCalled } = runRequireAuth(`Bearer ${expired}`);
    assert.equal(res.statusCode, 401);
    assert.deepEqual(res.body, { error: "Token inválido o vencido" });
    assert.equal(nextCalled, false);
  });

  test("token válido llama a next() y deja req.userId", () => {
    const { req, res, nextCalled } = runRequireAuth(`Bearer ${signAppToken("abc")}`);
    assert.equal(nextCalled, true);
    assert.equal(req.userId, "abc");
    assert.equal(res.body, undefined);
  });
});

describe("verifyGoogleIdToken", () => {
  beforeEach(resetGoogleStub);

  test("devuelve sub, email y name del payload de Google", async () => {
    googleStub.payload = { sub: "s1", email: "a@b.com", name: "Ana", picture: "x" };
    const profile = await verifyGoogleIdToken("id-token");
    assert.deepEqual(profile, { sub: "s1", email: "a@b.com", name: "Ana" });
  });

  test("verifica contra el GOOGLE_CLIENT_ID como audience", async () => {
    await verifyGoogleIdToken("id-token-xyz");
    assert.equal(googleStub.calls.length, 1);
    assert.deepEqual(googleStub.calls[0], {
      idToken: "id-token-xyz",
      audience: process.env.GOOGLE_CLIENT_ID,
    });
  });

  test("lanza error si Google no devuelve payload", async () => {
    googleStub.payload = undefined;
    await assert.rejects(verifyGoogleIdToken("t"), /sin payload/);
  });

  test("propaga el error si Google rechaza el token", async () => {
    googleStub.error = new Error("Wrong recipient");
    await assert.rejects(verifyGoogleIdToken("t"), /Wrong recipient/);
  });
});
