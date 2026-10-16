#!/data/data/com.termux/files/usr/bin/bash
# ZoraS no Termux — servidor estático + túnel Cloudflare, com arranque
# automático e recuperação de falhas.
#
# Idempotente: podes correr as vezes que quiseres sem duplicar processos.
#
#   ./zoras-termux.sh setup    instala dependências (uma vez)
#   ./zoras-termux.sh update   git pull e reinicia o servidor
#   ./zoras-termux.sh teste    põe online já, sem conta nem domínio
#   ./zoras-termux.sh login    liga à tua conta Cloudflare (uma vez)
#   ./zoras-termux.sh tunel    cria o túnel e o DNS (uma vez, pede domínio)
#   ./zoras-termux.sh start    arranca com o teu domínio
#   ./zoras-termux.sh boot     arranca sozinho quando ligas o telemóvel
#   ./zoras-termux.sh stop     pára tudo
#   ./zoras-termux.sh status   mostra o estado
#   ./zoras-termux.sh logs     últimas linhas dos registos

set -euo pipefail

BASE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PORTA="${ZORAS_PORTA:-8080}"
NOME_TUNEL="${ZORAS_TUNEL:-zoras}"
EXEC="$HOME/.zoras"
LOGS="$BASE/logs"
CF="$HOME/.cloudflared"

mkdir -p "$EXEC" "$LOGS"

log()  { printf '\033[0;36m[zoras]\033[0m %s\n' "$*"; }
ok()   { printf '\033[0;32m[zoras]\033[0m %s\n' "$*"; }
aviso(){ printf '\033[0;33m[zoras]\033[0m %s\n' "$*"; }
erro() { printf '\033[0;31m[zoras] ERRO:\033[0m %s\n' "$*" >&2; exit 1; }

vivo() { local f="$1"; [[ -f "$f" ]] && kill -0 "$(cat "$f")" 2>/dev/null; }

# Arranca um comando em segundo plano e guarda o PID. Não duplica.
arranca() { # arranca <nome> <ficheiro-log> <comando...>
  local nome="$1" logf="$2"; shift 2
  if vivo "$EXEC/$nome.pid"; then
    log "$nome: já a correr"
    return 0
  fi
  nohup "$@" > "$logf" 2>&1 &
  echo $! > "$EXEC/$nome.pid"
  log "$nome: arrancado"
}

verifica_phantom() {
  local sdk; sdk="$(getprop ro.build.version.sdk 2>/dev/null || echo 0)"
  [[ "$sdk" -ge 31 ]] || return 0
  local pp; pp="$(settings get global settings_enable_monitor_phantom_procs 2>/dev/null || echo '?')"
  if [[ "$pp" != "false" ]]; then
    aviso "o phantom process killer parece ativo — o Android pode matar o site."
    if [[ "$sdk" -ge 34 ]]; then
      aviso "desliga em: Opções de programador → Disable child process restrictions"
    else
      aviso "precisa de adb: settings put global settings_enable_monitor_phantom_procs false"
    fi
  fi
}

cmd_setup() {
  log "a atualizar pacotes"
  pkg update -y && pkg upgrade -y
  log "a instalar python, cloudflared e termux-api"
  pkg install -y python cloudflared termux-api
  command -v cloudflared >/dev/null || erro "o cloudflared não ficou instalado"
  [[ -f "$BASE/public/index.html" ]] || erro "falta a pasta public/ com o index.html"
  ok "pronto. Para ver já online: ./zoras-termux.sh teste"
}

# Túnel rápido: sem conta, sem domínio, endereço temporário trycloudflare.com.
cmd_teste() {
  command -v cloudflared >/dev/null || erro "corre primeiro: ./zoras-termux.sh setup"
  verifica_phantom
  termux-wake-lock 2>/dev/null || true

  arranca servidor "$LOGS/servidor.log" python "$BASE/serve.py" "$PORTA"
  sleep 2
  arranca teste "$LOGS/teste.log" cloudflared tunnel --url "http://localhost:$PORTA"

  log "à espera do endereço…"
  local i url=""
  for i in $(seq 1 30); do
    url="$(grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' "$LOGS/teste.log" 2>/dev/null | head -1 || true)"
    [[ -n "$url" ]] && break
    sleep 1
  done

  if [[ -n "$url" ]]; then
    ok "o site está online em: $url"
    log "endereço temporário: muda sempre que parares. Para um fixo, usa login + tunel."
  else
    aviso "o endereço não apareceu. Vê: ./zoras-termux.sh logs"
  fi
}

cmd_login() {
  command -v cloudflared >/dev/null || erro "corre primeiro: ./zoras-termux.sh setup"
  log "abre o link que aparece e escolhe o teu domínio"
  cloudflared tunnel login
}

cmd_tunel() {
  [[ -f "$CF/cert.pem" ]] || erro "corre primeiro: ./zoras-termux.sh login"
  read -rp "Domínio (ex.: zorastech.com): " DOMINIO
  [[ "$DOMINIO" =~ ^[a-z0-9.-]+\.[a-z]{2,}$ ]] || erro "domínio inválido"

  if cloudflared tunnel list 2>/dev/null | grep -qw "$NOME_TUNEL"; then
    log "o túnel '$NOME_TUNEL' já existe, a reaproveitar"
  else
    log "a criar o túnel '$NOME_TUNEL'"
    cloudflared tunnel create "$NOME_TUNEL"
  fi

  local ID
  ID="$(cloudflared tunnel list --output json | python -c \
    "import sys,json;print(next(t['id'] for t in json.load(sys.stdin) if t['name']=='$NOME_TUNEL'))")" \
    || erro "não consegui obter o id do túnel"

  cat > "$CF/config.yml" <<EOF
tunnel: $ID
credentials-file: $CF/$ID.json

ingress:
  - hostname: $DOMINIO
    service: http://localhost:$PORTA
  - hostname: www.$DOMINIO
    service: http://localhost:$PORTA
  - service: http_status:404
EOF

  log "a apontar o DNS"
  cloudflared tunnel route dns "$NOME_TUNEL" "$DOMINIO" || log "DNS de $DOMINIO já existia"
  cloudflared tunnel route dns "$NOME_TUNEL" "www.$DOMINIO" || log "DNS de www já existia"

  echo "$DOMINIO" > "$EXEC/dominio"
  ok "feito. Agora: ./zoras-termux.sh start"
}

cmd_start() {
  [[ -f "$CF/config.yml" ]] || erro "corre primeiro: ./zoras-termux.sh tunel"
  verifica_phantom
  termux-wake-lock 2>/dev/null && log "wakelock ativo" || aviso "sem termux-api: instala com pkg install termux-api"

  arranca servidor "$LOGS/servidor.log" python "$BASE/serve.py" "$PORTA"
  sleep 2
  arranca tunel "$LOGS/tunel.log" cloudflared tunnel run "$NOME_TUNEL"
  sleep 1
  arranca vigia "$LOGS/vigia.log" bash "$BASE/zoras-termux.sh" _vigia

  sleep 3
  cmd_status
}

# Vigia: de 60 em 60 segundos confirma que ambos estão de pé e repõe o que caiu.
cmd_vigia() {
  while true; do
    sleep 60
    if ! vivo "$EXEC/servidor.pid"; then
      rm -f "$EXEC/servidor.pid"
      nohup python "$BASE/serve.py" "$PORTA" >> "$LOGS/servidor.log" 2>&1 &
      echo $! > "$EXEC/servidor.pid"
      echo "$(date '+%F %T') servidor reposto" >> "$LOGS/vigia.log"
    fi
    if ! vivo "$EXEC/tunel.pid"; then
      rm -f "$EXEC/tunel.pid"
      nohup cloudflared tunnel run "$NOME_TUNEL" >> "$LOGS/tunel.log" 2>&1 &
      echo $! > "$EXEC/tunel.pid"
      echo "$(date '+%F %T') tunel reposto" >> "$LOGS/vigia.log"
    fi
  done
}

cmd_boot() {
  local d="$HOME/.termux/boot"
  mkdir -p "$d"
  cat > "$d/zoras" <<EOF
#!/data/data/com.termux/files/usr/bin/sh
termux-wake-lock
sleep 10
$BASE/zoras-termux.sh start >> $LOGS/boot.log 2>&1
EOF
  chmod +x "$d/zoras"
  ok "arranque automático instalado em $d/zoras"
  log "falta instalar a app Termux:Boot (F-Droid) e abri-la uma vez."
}

cmd_stop() {
  local n
  for n in vigia tunel teste servidor; do
    if vivo "$EXEC/$n.pid"; then
      kill "$(cat "$EXEC/$n.pid")" 2>/dev/null || true
      log "$n: parado"
    fi
    rm -f "$EXEC/$n.pid"
  done
  termux-wake-unlock 2>/dev/null || true
}

cmd_status() {
  local n
  for n in servidor tunel teste vigia; do
    if vivo "$EXEC/$n.pid"; then ok "$n: a correr"; fi
  done
  vivo "$EXEC/servidor.pid" || aviso "servidor: parado"
  if [[ -f "$EXEC/dominio" ]] && vivo "$EXEC/tunel.pid"; then
    ok "online em: https://$(cat "$EXEC/dominio")"
  fi
  if vivo "$EXEC/teste.pid"; then
    grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' "$LOGS/teste.log" 2>/dev/null | head -1 || true
  fi
}

cmd_update() {
  local raiz
  raiz="$(git -C "$BASE" rev-parse --show-toplevel 2>/dev/null)" \
    || erro "isto não é um repositório git — clona-o primeiro"

  log "a buscar alterações"
  git -C "$raiz" pull --ff-only || erro "o pull falhou; resolve os conflitos primeiro"

  if vivo "$EXEC/servidor.pid"; then
    kill "$(cat "$EXEC/servidor.pid")" 2>/dev/null || true
    rm -f "$EXEC/servidor.pid"
    arranca servidor "$LOGS/servidor.log" python "$BASE/serve.py" "$PORTA"
    sleep 1
    ok "site atualizado e servidor reiniciado"
  else
    ok "ficheiros atualizados. Arranca com: ./zoras-termux.sh start"
  fi
}

cmd_logs() {
  local f
  for f in "$LOGS"/*.log; do
    [[ -e "$f" ]] || continue
    printf '\n\033[0;36m── %s ──\033[0m\n' "$(basename "$f")"
    tail -n 15 "$f"
  done
}

case "${1:-}" in
  setup)  cmd_setup ;;
  update) cmd_update ;;
  teste)  cmd_teste ;;
  login)  cmd_login ;;
  tunel)  cmd_tunel ;;
  start)  cmd_start ;;
  boot)   cmd_boot ;;
  stop)   cmd_stop ;;
  status) cmd_status ;;
  logs)   cmd_logs ;;
  _vigia) cmd_vigia ;;
  *) sed -n '2,16p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//' ;;
esac
