// POST /api/lead: guarda um pedido do formulário de contacto na D1 (binding LEADS).
// Sem o binding responde 503 e o app.js volta ao método antigo (copiar e enviar por email).
const SERVICES = ["vibeguard", "zapagent", "faturai", "conformia", "tokengate", "ambos", "outro"];

function bad(status, error) {
  return Response.json({ ok: false, error }, { status, headers: { "Cache-Control": "no-store" } });
}

export async function onRequestPost({ request, env }) {
  if (!env.LEADS) return bad(503, "indisponivel");
  if (!(request.headers.get("Content-Type") || "").startsWith("application/json")) return bad(415, "formato");

  let d;
  try { d = await request.json(); } catch { return bad(400, "json"); }
  if (d.website) return Response.json({ ok: true }); // campo-isco: só os robôs o preenchem

  const name = String(d.name || "").trim().slice(0, 120);
  const email = String(d.email || "").trim().slice(0, 200);
  const message = String(d.message || "").trim().slice(0, 4000);
  const service = SERVICES.includes(d.service) ? d.service : "outro";
  const lang = d.lang === "en" ? "en" : "pt";
  const source = String(d.source || "").slice(0, 200);
  if (!name || !message || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) return bad(422, "campos");

  await env.LEADS.prepare(
    "INSERT INTO leads (name, email, service, message, lang, source) VALUES (?, ?, ?, ?, ?, ?)"
  ).bind(name, email, service, message, lang, source).run();
  return Response.json({ ok: true }, { headers: { "Cache-Control": "no-store" } });
}
