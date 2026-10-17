# zorastech.com — registos DNS de segurança

Três registos que o site não traz e que fazem falta. Adicionam-se em
**dash.cloudflare.com → zorastech.com → DNS → Registos**.

Sem eles o domínio fica exposto a dois ataques concretos: alguém emitir um
certificado em teu nome, e alguém enviar emails a fingir que são teus.

---

## 1. CAA — quem pode emitir certificados para o teu domínio

Sem CAA, **qualquer** autoridade certificadora no mundo pode emitir um
certificado válido para `zorastech.com`. Com CAA, só as que tu autorizas.

| Tipo | Nome | Conteúdo |
|---|---|---|
| CAA | `zorastech.com` | `0 issue "letsencrypt.org"` |
| CAA | `zorastech.com` | `0 issue "pki.goog"` |
| CAA | `zorastech.com` | `0 issuewild ";"` |
| CAA | `zorastech.com` | `0 iodef "mailto:c792389@gmail.com"` |

A Cloudflare usa Let's Encrypt e Google Trust Services, por isso os dois
primeiros são precisos. O terceiro proíbe certificados wildcard, que não usas.
O quarto faz-te chegar um aviso se alguém tentar emitir um.

No painel da Cloudflare, o campo divide-se em *Flags* (`0`), *Tag* (`issue`)
e *Value* (`letsencrypt.org`).

## 2. SPF — quem pode enviar email como @zorastech.com

| Tipo | Nome | Conteúdo |
|---|---|---|
| TXT | `zorastech.com` | `v=spf1 -all` |

O `-all` diz: **ninguém** envia email deste domínio. É o correto enquanto não
tiveres email próprio, e bloqueia quem tente fazer-se passar por ti.

Quando criares email em `@zorastech.com`, trocas pelo do teu fornecedor.
Exemplo para Google Workspace: `v=spf1 include:_spf.google.com -all`.

## 3. DMARC — o que fazer com quem falhar

| Tipo | Nome | Conteúdo |
|---|---|---|
| TXT | `_dmarc.zorastech.com` | `v=DMARC1; p=reject; rua=mailto:c792389@gmail.com` |

O `p=reject` manda os servidores recusarem qualquer email falsificado em teu
nome. O `rua` envia-te relatórios de quem tentou.

E para fechar o DKIM, já que não envias email:

| Tipo | Nome | Conteúdo |
|---|---|---|
| TXT | `*._domainkey.zorastech.com` | `v=DKIM1; p=` |

---

## Confirmar depois

```bash
dig CAA zorastech.com +short
dig TXT zorastech.com +short
dig TXT _dmarc.zorastech.com +short
```

Ou online, sem terminal:

- `https://securityheaders.com` — alvo A+
- `https://www.ssllabs.com/ssltest/` — alvo A+
- `https://dmarcian.com/domain-checker/` — confirma SPF e DMARC
- `https://internet.nl/site/zorastech.com/` — análise completa

## Porque isto importa para a ZoraS em particular

Vendes auditorias de segurança. Um cliente que saiba do assunto vai correr
estes testes ao teu próprio domínio antes de te contratar. Ter A+ nos dois
e o email protegido é argumento de venda; não ter é o contrário.
