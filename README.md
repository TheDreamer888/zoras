# ZoraS

Site da ZoraS — auditoria de segurança (VibeGuard) e assistentes de WhatsApp (ZapAgent).

## Estrutura

```
index.html        o site (as Pages publicam a raiz do repositório)
style.css
app.js
_headers          cabeçalhos de segurança (HSTS, CSP, Permissions-Policy) e cache
.well-known/      security.txt
DNS-SEGURANCA.md  guia de DNS
termux/           servir a partir do telemóvel, para testes
```

## Publicar

`git push` na branch `main`. As Cloudflare Pages publicam sozinhas.

## Testar no Termux

```bash
./termux/zoras-termux.sh update   # git pull + reinicia
./termux/zoras-termux.sh teste    # endereço temporário com HTTPS
```

## Cuidado

O `_headers` é o que aplica a segurança nas Pages. Não o apagues.
