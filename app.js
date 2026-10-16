(function () {
  "use strict";

  /* ---------- language ---------- */
  var LANG_KEY = "zoras.lang";
  var btnPt = document.getElementById("btn-pt");
  var btnEn = document.getElementById("btn-en");

  function applyLang(lang) {
    var isEn = lang === "en";
    document.querySelectorAll("[data-pt]").forEach(function (el) {
      var next = isEn ? el.getAttribute("data-en") : el.getAttribute("data-pt");
      if (next) { el.textContent = next; }
    });
    document.querySelectorAll("[data-pt-ph]").forEach(function (el) {
      var next = isEn ? el.getAttribute("data-en-ph") : el.getAttribute("data-pt-ph");
      if (next) { el.setAttribute("placeholder", next); }
    });
    btnPt.setAttribute("aria-pressed", String(!isEn));
    btnEn.setAttribute("aria-pressed", String(isEn));
    document.documentElement.setAttribute("lang", isEn ? "en" : "pt");
    try { localStorage.setItem(LANG_KEY, isEn ? "en" : "pt"); } catch (e) { /* storage blocked */ }
  }

  btnPt.addEventListener("click", function () { applyLang("pt"); });
  btnEn.addEventListener("click", function () { applyLang("en"); });

  var startLang = "pt";
  try {
    var saved = localStorage.getItem(LANG_KEY);
    if (saved === "pt" || saved === "en") { startLang = saved; }
    else if ((navigator.language || "").slice(0, 2).toLowerCase() !== "pt") { startLang = "en"; }
  } catch (e) {
    if ((navigator.language || "").slice(0, 2).toLowerCase() !== "pt") { startLang = "en"; }
  }
  applyLang(startLang);

  /* ---------- copy email ---------- */
  var copyBtn = document.getElementById("copy-email");
  var emailVal = document.getElementById("email-val");
  copyBtn.addEventListener("click", function () {
    var text = emailVal.textContent.trim();
    var done = function () {
      var isEn = btnEn.getAttribute("aria-pressed") === "true";
      copyBtn.textContent = isEn ? "Copied" : "Copiado";
      setTimeout(function () {
        copyBtn.textContent = isEn ? "Copy" : "Copiar";
      }, 1800);
    };
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(text).then(done, selectFallback);
    } else {
      selectFallback();
    }
    function selectFallback() {
      var range = document.createRange();
      range.selectNodeContents(emailVal);
      var sel = window.getSelection();
      sel.removeAllRanges();
      sel.addRange(range);
    }
  });

  /* ---------- contact form ---------- */
  var form = document.getElementById("lead-form");
  var statusEl = document.getElementById("f-status");
  var outWrap = document.getElementById("f-out-wrap");
  var out = document.getElementById("f-out");
  var copyMsg = document.getElementById("copy-msg");

  var SERVICE_LABEL = {
    vibeguard: ["VibeGuard — auditoria de segurança", "VibeGuard — security audit"],
    zapagent: ["ZapAgent — assistente de WhatsApp", "ZapAgent — WhatsApp assistant"],
    ambos: ["Os dois serviços", "Both services"],
    outro: ["Outro assunto", "Something else"]
  };

  function isEnglish() { return btnEn.getAttribute("aria-pressed") === "true"; }

  function say(kind, pt, en) {
    statusEl.className = "status" + (kind ? " " + kind : "");
    statusEl.textContent = isEnglish() ? en : pt;
    statusEl.hidden = false;
  }

  form.addEventListener("submit", function (ev) {
    ev.preventDefault();
    var name = document.getElementById("f-name").value.trim();
    var email = document.getElementById("f-email").value.trim();
    var service = document.getElementById("f-service").value;
    var message = document.getElementById("f-msg").value.trim();
    var en = isEnglish();

    if (!name || !email || !message) {
      say("warn",
        "Preenche o nome, o email e a mensagem.",
        "Fill in your name, email and message.");
      return;
    }
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      say("warn", "Esse email não parece válido.", "That email doesn't look valid.");
      return;
    }

    var label = (SERVICE_LABEL[service] || SERVICE_LABEL.outro)[en ? 1 : 0];
    var body = en
      ? ["Hello ZoraS,", "", "Service: " + label, "Name: " + name,
         "Reply to: " + email, "", message, "", "— sent from the ZoraS site"].join("\n")
      : ["Olá ZoraS,", "", "Serviço: " + label, "Nome: " + name,
         "Responder para: " + email, "", message, "", "— enviado pelo site da ZoraS"].join("\n");

    out.value = body;
    outWrap.hidden = false;

    var addr = emailVal.textContent.trim();
    var tell = function (copied) {
      if (copied) {
        say("ok",
          "Mensagem copiada. Cola num email para " + addr + " e envia.",
          "Message copied. Paste it into an email to " + addr + " and send.");
      } else {
        say("ok",
          "Mensagem pronta em baixo. Copia-a e envia para " + addr + ".",
          "Your message is ready below. Copy it and send it to " + addr + ".");
      }
    };

    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(body).then(function () { tell(true); }, function () { tell(false); });
    } else {
      tell(false);
    }
  });

  copyMsg.addEventListener("click", function () {
    var en = isEnglish();
    var done = function () {
      copyMsg.textContent = en ? "Copied" : "Copiado";
      setTimeout(function () { copyMsg.textContent = en ? "Copy message" : "Copiar mensagem"; }, 1800);
    };
    var fallback = function () { out.focus(); out.select(); };
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(out.value).then(done, fallback);
    } else {
      fallback();
    }
  });
})();
