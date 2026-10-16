# ZoraS no Termux

Serve o site do telemóvel, com HTTPS real e domínio próprio, através de um
túnel da Cloudflare.

## Como funciona

```
visitante → https://zorastech.com → Cloudflare (termina o TLS)
                                        ↓ ligação já aberta de dentro para fora
                                   cloudflared no Termux
                                        ↓ http://127.0.0.1:8080
                                   serve.py → public/
```

O telemóvel **não abre portas nenhumas**. É o `cloudflared` que se liga à
Cloudflare de dentro para fora, e a ligação fica aberta. Por isso o CGNAT da
operadora é irrelevante: nunca ninguém se liga diretamente ao telemóvel.

O certificado HTTPS é da Cloudflare, válido e renovado por ela.

## Ver online em dois minutos, sem conta nem domínio

```bash
cd ~/zoras
chmod +x zoras-termux.sh
./zoras-termux.sh setup
./zoras-termux.sh teste
```

O `teste` dá-te um endereço `trycloudflare.com` já com HTTPS, sem precisares de
conta nem de domínio. Serve para confirmares que tudo funciona antes de gastares
dinheiro no domínio.

Esse endereço é temporário e muda sempre que parares. Para um endereço fixo,
segue para os passos abaixo.

## Com o teu domínio

```bash
./zoras-termux.sh login     # abre o browser, escolhe o teu domínio
./zoras-termux.sh tunel     # cria o túnel e aponta o DNS
./zoras-termux.sh start     # arranca
./zoras-termux.sh boot      # passa a arrancar sozinho
```

O domínio tem de estar já adicionado à tua conta Cloudflare antes do `login`.

## Comandos

| Comando | O que faz |
|---|---|
| `teste` | Online já, endereço temporário, sem conta |
| `start` | Arranca com o teu domínio, mais wakelock e vigia |
| `boot` | Instala o arranque automático após reiniciar |
| `stop` | Pára tudo e liberta o wakelock |
| `status` | Diz o que está a correr e em que endereço |
| `logs` | Últimas linhas de todos os registos |

O `start` deixa a correr um **vigia**: de minuto a minuto confirma que o
servidor e o túnel estão de pé e repõe o que tiver caído. Fica registado em
`logs/vigia.log`, para saberes se andou a repor alguma coisa — um vigia
ocupado é sinal de que falta desligar o phantom process killer.

## Manter de pé — a parte que os tutoriais não contam

O `start` já pede o **wakelock**. Faltam três coisas, e sem elas o site cai
sozinho ao fim de umas horas.

**1. Desligar o phantom process killer** ← o passo decisivo

O Android 12 trouxe um mecanismo que mata processos-filho em segundo plano
quando passam de 32 no sistema, ou quando consomem CPU a mais. É ele que dá o
famoso `Process completed (signal 9)` no Termux. Não é um defeito do Termux:
é do Android, e **vem ligado de fábrica**, incluindo no Android 14 e seguintes.

*Android 14 ou mais recente* — faz-se no telemóvel, sem computador:

> Definições → Acerca do telemóvel → tocar 7 vezes em **Número de compilação**
> → voltar atrás → **Opções de programador** → ativar
> **Disable child process restrictions** → reiniciar

Deixa as Opções de programador ligadas: ao desligá-las, o interruptor volta atrás.

*Android 12L ou 13* — precisa de computador, uma vez só, com depuração USB:

```bash
adb shell settings put global settings_enable_monitor_phantom_procs false
```

Reinicia a seguir. Em telemóvel com root, o mesmo comando com `su -c` dentro
do próprio Termux.

O wakelock e o serviço em primeiro plano baixam a prioridade de remoção, logo
reduzem o risco, mas **não tornam imune**. O `tmux` também não protege: o
mecanismo mata o próprio servidor tmux.

**2. Tirar o Termux da otimização de bateria**

Definições → Aplicações → Termux → Bateria → **Sem restrições**.

**3. Arrancar sozinho depois de reiniciar**

Instala o **Termux:Boot** (da F-Droid, a mesma fonte do Termux) e cria:

```bash
mkdir -p ~/.termux/boot
cat > ~/.termux/boot/zoras <<'EOF'
#!/data/data/com.termux/files/usr/bin/sh
termux-wake-lock
~/zoras/zoras-termux.sh start
EOF
chmod +x ~/.termux/boot/zoras
```

Abre o Termux:Boot uma vez, para o Android lhe dar permissão.

## Segurança

O `serve.py` aplica os mesmos cabeçalhos da configuração do Caddy: HSTS, CSP
estrita, `Permissions-Policy`. Só responde a GET e HEAD; qualquer outro método
leva 405. Liga-se apenas a `127.0.0.1`, por isso mesmo em Wi-Fi público
ninguém na mesma rede alcança o servidor — só o túnel chega lá.

Na Cloudflare, ativa **SSL/TLS → Full (strict)** e **Always Use HTTPS**.

Confirma depois com:

```bash
curl -sI https://zorastech.com | grep -iE 'strict-transport|content-security'
```

E corre `https://securityheaders.com` — deve dar **A+**.

## O que esperar na prática

| | Realidade |
|---|---|
| Bateria | Consumo contínuo. Com o telemóvel na tomada, não é problema |
| Dados | Cada visita consome do teu plano. Um site destes ronda 60 KB por visita |
| Disponibilidade | Com os três passos acima feitos, aguenta-se. Cai quando o telemóvel desliga, fica sem rede ou é reiniciado sem o Termux:Boot |
| Velocidade | A Cloudflare não guarda cópia destes ficheiros por omissão, logo cada pedido vai ao telemóvel |

A última linha tem solução: na Cloudflare, em **Caching → Cache Rules**, cria
uma regra que guarde cópia de `*.css`, `*.js` e das imagens. Assim a maioria
dos pedidos é respondida pela Cloudflare e nem chega ao telemóvel — menos
dados, menos bateria, e o site continua de pé durante quedas curtas.

## Quando passar para as Pages

Esta montagem serve bem para arrancar e para testar. Quando começares a ter
clientes a chegar pelo site, vale a pena passar para o Cloudflare Pages: é
gratuito, o site deixa de depender do telemóvel, e os ficheiros são os mesmos.
O guia está em `COLOCAR-ONLINE.md`.
