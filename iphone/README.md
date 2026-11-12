# UFAC+ para iPhone (PWA)

**No ar:** app em https://ufac-plus-ios.pages.dev (instalar: https://ufac-plus-ios.pages.dev/instalar/) e Worker em https://ufac-plus-ios.ufacplus.workers.dev, na conta Cloudflare do Matheus (publicado em 12/11/2026).

Versão do UFAC+ para iPhone, como app da web instalável (PWA). O original fica na branch `ios-pwa` do repositório privado `ufac-plus`; a `main` (Android/Flutter) não muda.

**Código aberto:** uma cópia pública fica na pasta [`iphone/`](https://github.com/arthurleticiaclaude/ufac-no-bolso/tree/main/iphone) do repositório das releases (`arthurleticiaclaude/ufac-no-bolso`), com as fixtures anonimizadas para os testes rodarem lá. Para atualizar: clonar o `ufac-no-bolso`, rodar `ios-pwa/tools/publicar-codigo.sh <clone>` (copia só o que está commitado), conferir o `git diff` e fazer o commit e o push de lá.

**Por que PWA:** desde o acordo com o CADE (iOS 26.5), a Apple aceita apps fora da App Store, mas exige notarização, que pede a conta Apple Developer paga (US$ 99/ano). Sem pagar, a via viável é o site instalado pelo Safari (Compartilhar › Adicionar à Tela de Início), que no iOS 26 abre como app.

## O que tem

| Pasta | O quê |
|---|---|
| `web/` | O app (HTML/CSS/JS com Vite, sem Flutter web). Telas, extratores, cache em IndexedDB, service worker e visual Liquid Glass em CSS. |
| `web/src/lib/extratores/` | Porte dos extratores Dart (`lib/extractors/`) para JS, testados com os mesmos HTML de `fixtures/`. |
| `worker/` | Cloudflare Worker: repassa `/portal/*` e `/eticket/*` para a Ufac (o Safari bloqueia por CORS) e manda as notificações (Web Push + Cron). |
| `docs/` | Página `/instalar` (3 passos) e `/privacidade` (política nova, citando o Worker e o push). |
| `e2e/` | Testes com Playwright num iPhone emulado (WebKit), com um Worker falso que serve as fixtures. |
| `tools/gerar-splash.mjs` | Gera as telas de abertura do iOS. |

### Diferenças em relação ao Android

| Android | iPhone (PWA) | Por quê |
|---|---|---|
| WebView escondida lê as páginas | Worker repassa os pedidos; o HTML é lido no iPhone | O Safari não deixa um site ler outro (CORS). |
| Login na página oficial dentro da WebView | Duas etapas próprias, uma senha por sistema (Portal, depois eTICKET), que vão pelo Worker para a Ufac | A página oficial não pode ser embutida com sessão. As senhas podem ser diferentes. O app não guarda senha: o Chaves do iCloud salva cada uma como um item à parte, com o usuário rotulado ("CPF · Portal do Aluno" e "CPF · eTICKET"), porque com o mesmo CPF no mesmo site a segunda sobrescreveria a primeira. |
| Cookies na WebView | Cookies cifrados (AES-GCM) pelo Worker, guardados só no iPhone | O Worker não guarda nada. |
| `flutter_secure_storage` | IndexedDB do app instalado | Não há cofre do sistema para apps da web. |
| Brilho no máximo no QR | Aviso “Aumente o brilho” + tela sempre acesa (Wake Lock) | A web não controla o brilho. |
| Live Activities / avisos locais | Web Push (aula 15 min antes, refeição, Classroom às 19h) + selo no ícone | Live Activities não existem em PWA. |
| Recarga, chamada e notas do professor dentro do app | Abrem o site oficial no Safari (a Ufac pede login lá) | Pagamento e lançamentos só no fluxo oficial. |
| Classroom com o SDK do Android | Fluxo de código com PKCE por redirecionamento, só leitura; leituras direto do iPhone para o Google | O Worker só troca o código e renova (precisa do client secret) e devolve a autorização cifrada, que fica no iPhone. Nada é guardado no Worker. |

## Rodar no Mac

```bash
cd ios-pwa
npm install
node worker/scripts/gerar-chaves.mjs --dev   # cria worker/.dev.vars (fora do git)
npm run dev:worker                            # Worker em http://localhost:8787
npm run dev:web                               # PWA em http://localhost:5173
```

Testes:

```bash
npm test               # extratores (com as fixtures) + Worker
npx playwright install webkit   # uma vez
npm run e2e            # iPhone emulado; prints em e2e/prints/
```

## Publicar de graça na Cloudflare

Precisa de uma conta gratuita da Cloudflare (`npx wrangler login` abre o navegador).

1. **KV das notificações:** `npx wrangler kv namespace create INSCRICOES` (dentro de `worker/`) e cole o `id` em `worker/wrangler.toml`.
2. **Segredos do Worker:** `node worker/scripts/gerar-chaves.mjs` mostra três valores. Para cada um: `npx wrangler secret put SESSAO_CHAVE`, `VAPID_PUBLICA` e `VAPID_PRIVADA` (dentro de `worker/`). Guarde uma cópia fora do repositório: trocar a `VAPID_*` desliga as notificações de todo mundo, e trocar a `SESSAO_CHAVE` pede login de novo.
3. **Worker:** `npm run deploy -w worker`. Anote o endereço `https://ufac-plus-ios.<subdominio>.workers.dev`.
4. **PWA:** copie `web/.env.production.example` para `web/.env.production`, preencha `VITE_WORKER_URL` e rode `npm run deploy -w web`. Atenção: o `wrangler` 4.16x tenta converter o projeto em Worker (cria `web/wrangler.jsonc` e mexe no `package.json`); se isso acontecer, desfaça com `git checkout` e apague o `wrangler.jsonc`. O projeto do Pages já existe, então `npx wrangler pages deploy dist --project-name ufac-plus-ios --branch main` publica direto. O endereço será `https://ufac-plus-ios.pages.dev` (se o nome estiver ocupado, troque `--project-name` e ajuste `ORIGENS` e `VAPID_ASSUNTO` em `wrangler.toml`).
5. Abra `https://ufac-plus-ios.pages.dev/instalar/` no iPhone.

**Ligar ao GitHub (deploy automático da branch `ios-pwa`):** no painel da Cloudflare, *Workers & Pages › Create › Pages › Connect to Git*. Isso instala o app da Cloudflare no GitHub do dono do repositório, então **quem faz é o Arthur** (você tem permissão de escrita, não de administrador). Configuração: branch de produção `ios-pwa`, diretório raiz `ios-pwa/web`, comando `npm install && npm run build`, saída `dist`, variáveis `VITE_*` do passo 4. O Worker pode ser ligado do mesmo jeito em *Workers › Settings › Builds* (raiz `ios-pwa/worker`). Até lá, os comandos acima publicam a partir do seu Mac.

### Classroom (opcional)

O ID do cliente Android não serve na web. No Google Cloud (pode ser um projeto próprio, com a conta Gmail pessoal):

1. Ative a **Google Classroom API**.
2. *Google Auth Platform*: público **Externo**; em *Acesso a dados*, só `classroom.courses.readonly` e `classroom.coursework.me.readonly`; em *Público › Usuários de teste*, os e-mails @sou.ufac.br de quem vai usar.
3. *Clientes › Criar cliente › Aplicativo da Web*. Origem JavaScript: `https://ufac-plus-ios.pages.dev`. URI de redirecionamento: `https://ufac-plus-ios.pages.dev/` (com a barra no fim). Não ponha `localhost` neste cliente: para desenvolver, crie outro cliente só com `http://localhost:5173/` e use `GOOGLE_DEV=1` no `worker/.dev.vars`.
4. ID do cliente em `web/.env.production` (`VITE_GOOGLE_CLIENT_ID`) , o mesmo ID em `GOOGLE_CLIENT_ID` no `worker/wrangler.toml` e, dentro de `worker/`, `npx wrangler secret put GOOGLE_CLIENT_SECRET`. O secret nunca vai para o git nem para o chat.
5. Depois que funcionar: *Público › Publicar app* (Em produção), **sem** pedir verificação. Em "Teste" a autorização vence em 7 dias; em produção não verificado ela dura (com o aviso "app não verificado" e teto de 100 pessoas).

Se a conta da Ufac mostrar "Acesso bloqueado" pela instituição, a Ufac bloqueia apps externos: não há contorno, só o botão "Abrir o Classroom".

## Estado em 12/11/2026 (para a próxima sessão)

**Feito e no ar (testado no iPhone 15 Pro Max do Matheus pelo Phone Harness):**
- Modo escuro blackout (preto puro, cinzas do iOS); seletores com a opção marcada visível (`--polegar`).
- Login em duas etapas, uma senha por sistema (Portal, depois eTICKET). O Chaves do iCloud salva o usuário rotulado ("CPF · Portal do Aluno" / "CPF · eTICKET"). No teste real, o Chaves ainda preencheu a senha errada no item do Portal: conferir no app Senhas se o item "· Portal do Aluno" tem a senha certa; se continuar misturando, é limite do Safari.
- Cardápio: lê o formato novo do eTICKET (um item por linha, "SALADA:", "SOBREMESA:", sem a saudação) e o antigo (vírgulas); usa a página pública se a sessão cair. O app Android (`main`, do Arthur) ainda não lê o formato novo.
- Classroom funcionando: projeto Google Cloud `ufac-plus-iphone` (conta pessoal do Matheus), app "UFAC Plus" **Em produção**, escopos não confidenciais (sem verificação, sem vencer em 7 dias), cliente Web com volta em `https://ufac-plus-ios.pages.dev/`. O ID está em `wrangler.toml` e `web/.env.production`; o secret só no Worker (`wrangler secret`). A Ufac não bloqueou a conta @sou.ufac.br.
- iOS 26 instalado: a área do app vai só até 873 de 932 pt; a barra de abas agora fica na borda real dessa área (`--falta` / `--inset-baixo`). A faixa preta embaixo é do iOS e não dá para pintar.
- Troca de aba sem piscar (a tela nova só aparece quando já tem conteúdo).
- O app instalado se atualiza sozinho ao voltar para ele (e recarrega fora do login).
- **Debug de 12/11 (tarde):** o "carregando infinito" ao puxar a Início vinha do eTICKET (sistemas.ufac.br), que às vezes fica sem responder (inclusive fora da Cloudflare); o app esperava para sempre. Agora: limite de 25 s por pedido no app e 20 s no Worker (responde 504), o IndexedDB não trava quando o iOS derruba a conexão, Portal/eTICKET/Classroom em paralelo e o resto do sistema é pulado quando ele está fora. O piscar da Início e do RU vinha de redesenhar tudo com `innerHTML` (vidro refeito, foto recarregada, animação reiniciada): agora `remontar()` (ui/componentes.js) mexe só no que mudou. Testes e2e cobrem os dois casos. Ideias da Biblioteca e do ônibus em `funcionalidades-futuras.md`.
- **eTICKET instável (diagnóstico de 12/11, com o Fable):** o DNS de sistemas.ufac.br tem dois IPs. O `200.129.173.8` entrega o certificado do portal.ufac.br (falha na hora). No `200.129.173.36`, cerca de metade das conexões novas nunca recebe resposta, e as boas respondem em ~0,35 s; numa conexão boa, os pedidos seguintes também vão bem. O Worker agora repete cada salto do eTICKET com conexão nova e prazos curtos até os cabeçalhos (GET: até 9 tentativas, 1,2 s → 3 s; POST do login: 2 de 6 s; o Portal não repete). Medido depois: 25 de 25 pedidos com sucesso, a maioria na 1ª ou 2ª tentativa. O cabeçalho `X-Tentativas` mostra o que aconteceu em cada uma (sem dado pessoal). Correção definitiva é da Ufac: avisar o NTI do registro `.8` e do servidor que trava.

**Release no GitHub (mesmo repositório público das releases do Android, `arthurleticiaclaude/ufac-no-bolso`):** tag `iphone-vX.Y.Z`, sem arquivo para baixar (só notas, QR da página `/instalar` e prints com dados fictícios de `e2e/prints`). **Sempre com `--latest=false`**: o app Android procura atualização em `/releases/latest` e só aceita release com `.apk`; se a do iPhone virar "Latest", o Android para de ver versões novas. Ex.: `gh release create iphone-v1.0.1 -R arthurleticiaclaude/ufac-no-bolso --target main --title "UFAC+ para iPhone 1.0.1" --notes-file notas.md --latest=false <imagens>`. A 1.0 saiu em 12/11/2026.

**Publicar:** `npm run build -w web` gera `web/dist` (os testes e2e usam `web/dist-e2e` e não sobrescrevem). Publicar o app: `cd web && npx wrangler pages deploy dist --project-name ufac-plus-ios --branch main --commit-dirty=true`. Publicar o Worker: `cd worker && npx wrangler deploy`. O Claude só publica sozinho se houver a regra de permissão em `.claude/settings.local.json` (o Matheus cria; o Claude não pode dar permissão a si mesmo).

**Próximos passos:**
1. Conferir no iPhone a última versão (seletor visível no escuro) e a troca de abas sem piscar.
2. Testar de novo o Chaves do iCloud com as duas senhas (apagar itens antigos no app Senhas antes).
3. Classroom: ligar "Atividades do Classroom" em Configurações › Notificações e conferir o aviso das 19h e o selo no ícone.
4. Testar Notas, Relatórios (PDF) e o QR na catraca do RU.
5. Avisar o Arthur do formato novo do cardápio no app Android.
6. Opcional: limite de pedidos por IP em `/google/*` no Worker; tirar `localhost` de `ORIGENS` em produção.

## Testar no iPhone com login real

- [ ] Instalar pela página `/instalar` e abrir pelo ícone (sem a barra do Safari).
- [ ] Login em duas etapas, cada uma com a sua senha. Antes, apagar no app Senhas itens antigos de `ufac-plus-ios.pages.dev`. Conferir: o Safari oferece salvar nas duas etapas? Ficam dois itens, "CPF · Portal do Aluno" e "CPF · eTICKET"? Ao sair e entrar de novo, a barra do teclado mostra os dois rotulados e o CPF volta sozinho ao escolher?
- [ ] Senhas já salvas para portal.ufac.br e sistemas.ufac.br não aparecem sozinhas (outro site): na primeira vez, chave do teclado › Senhas › buscar "ufac".
- [ ] Início: nome, matrícula, período, saldo e próxima aula batem com o portal.
- [ ] Horários, Notas (quadro aberto e faltas) e Relatórios: ver um PDF e usar “Compartilhar › Salvar em Arquivos”.
- [ ] RU: cardápio (o eTICKET passou a publicar um item por linha, com "SALADA:" e "SOBREMESA:"), histórico e QR. **Passar o QR na catraca** e testar com o modo avião.
- [ ] Recarregar: abre o eTICKET no Safari (lá pede login).
- [ ] Configurações › Notificações: permitir e ligar “Próxima aula”; conferir se chega 15 min antes.
- [ ] Deixar o app parado por mais de 1 hora e abrir de novo: o Portal deve pedir “Entrar de novo” só quando uma tela precisar.
- [ ] Classroom (se configurado): conectar no app instalado (o Google abre numa folha e volta sozinho para a Início), ver atividades da semana e o selo no ícone; fechar o app, voltar depois de 1 hora e conferir que atualiza sem pedir o Google de novo.
- [ ] Faixa vazia embaixo (iOS 26): a barra de abas encosta na borda de baixo, e o fim da página rola até aparecer inteiro.
- [ ] Modo escuro do iPhone (blackout: fundo preto puro, cinzas do iOS) e “Reduzir transparência” (Acessibilidade): o vidro vira cartão sólido.
- [ ] Sair da conta: volta às boas-vindas e não mostra mais nada.

## O que não deu para conferir sem um iPhone real

- Se o portal ou o eTICKET aceitam o login vindo do Worker (IP da Cloudflare). Nas leituras públicas de teste (sem login) os dois responderam normalmente.
- O popup do Google no app instalado (no iOS, o PWA às vezes abre o Google numa folha separada).
- O visualizador de PDF em `<iframe>` (o iOS 18+ mostra todas as páginas; versões antigas, só a primeira, e aí vale o botão Compartilhar).
