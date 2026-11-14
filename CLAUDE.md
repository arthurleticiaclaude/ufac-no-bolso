# UFAC+ — Portal do Aluno + RU num app só (antes "UFAC no Bolso")

> Documento-guia do projeto para o Claude Code. **Leia inteiro antes de escrever qualquer código.**
> Dono: Arthur, aluno de Direito da Ufac (Rio Branco/AC). Não sou programador profissional.
> App para **mim e alguns amigos** (cada um no próprio celular, com o próprio login), **Android primeiro**.

---

## 1. Visão

Um app de celular com cara de app de verdade (nível banco digital) que junta o que eu uso no **Portal do Aluno da Ufac** e no **eTICKET do Restaurante Universitário**: meus dados acadêmicos, horários, notas, relatórios em PDF, saldo do RU, QR de entrada e cardápio. Sem abrir dois sites, sem navegar por menus antigos.

## 2. Os dois sistemas (o que já sei)

| | Portal do Aluno | eTICKET (RU) |
|---|---|---|
| URL | `https://portal.ufac.br/aluno/index.action` | `https://sistemas.ufac.br/eticket/` |
| Login | ID Ufac (CPF + senha) | ID Ufac (CPF + senha) — mesma credencial |
| Menu | Matrícula, Relatórios, Horários, Notas, Calendário, Biblioteca, Comunicações, Links Externos | Recarregar, Perfil, Cardápio, Histórico, Sair |
| Dados úteis | Nome, matrícula, curso, período atual, período de matrícula (topo da página Relatórios); horários; notas | Saldo (topo da página inicial logada); QR de entrada; cardápio |

Fatos confirmados:
- **Não há API oficial conhecida.** Tudo sai das páginas que eu já acesso como aluno.
- **O QR do RU é fixo:** decodificado de um print, contém só o número exibido embaixo dele (sem token, data ou validade). **Esse número é a matrícula de 11 dígitos** (confirmado em uma conta).
- **Cardápio:** a fonte é a página logada `/eticket/menu/`. A página pública "Cardápio do dia" pode dizer "Indisponível" quando a logada já tem conteúdo, e mostra outros preços. Nenhuma das duas tem data, horários ou cardápio da semana.
- **Horários das refeições** (post do RU, 04/11/2026): café 06h30 às 08h, almoço 11h às 14h, jantar 18h às 19h30. Ficam num arquivo de configuração do app.
- Detalhes de cada página em `docs/reconhecimento.md`.
- **Relatórios do portal (todos PDF):** Atestado Matrícula, Comprovante de Matrícula, Ficha Cadastral do Aluno, Histórico Escolar Simplificado, Histórico Integralização, Solicitação de Matrícula, Histórico Escolar CR – Aprovados (SIE), e um link "Mais Relatórios".
- Portal e eTICKET têm logins e sessões separados, com a mesma credencial.

## 3. Regras não negociáveis

1. **Eu faço o login, sempre dentro da página oficial.** Se houver CAPTCHA/2FA, eu resolvo. Nunca automatizar CAPTCHA nem contornar proteção.
2. **Senha só no cofre do celular, e só se a pessoa quiser** (mudança decidida por mim em 13/11/2026). A sessão fica nos cookies da WebView do Android. Com a chave "Entrar sozinho quando a sessão cair" ligada, o app guarda o CPF e a senha que a pessoa digitou na página oficial, cifrados no `flutter_secure_storage`, e refaz o login sozinho, na página oficial e escondida, quando a sessão cai. Esses dados só vão do celular para o site da Ufac; nunca para log, cache, servidor do app ou terceiros. "Sair" e "Esquecer senha salva" apagam.
3. **Nada sai do celular:** sem servidor intermediário, sem analytics, sem mandar senha, cookie, CPF ou matrícula para terceiros.
4. **Pagamento só no fluxo oficial** do eTICKET (botão Recarregar), aberto dentro do app; eu concluo.
5. **Respeitar a Ufac:** poucas requisições, cache local, atualizar só ao abrir o app ou puxar para atualizar.
6. **Segurança do QR:** o número do QR equivale a dinheiro (com ele qualquer um gera o QR) e é igual à matrícula. Guardar só no armazenamento seguro (`flutter_secure_storage`), nunca no SQLite. Nunca mostrar QR ou matrícula em notificação, widget ou tela bloqueada. Nunca logar esse número. Exceção decidida por mim: a matrícula fica sempre visível no cartão de identificação da Início.
7. **Nunca commitar** cookies, CPF, matrícula, número do QR, senha, nem HTML real com meus dados. `fixtures/raw/` e `.env` no `.gitignore`.
8. **Vários usuários, cada um no seu celular.** Nada pode ser fixo no código (nome, curso, matrícula, período, foto): tudo vem do login de quem está usando. Um celular = uma conta. Distribuição só por APK enviado direto a pessoas próximas, sem Play Store. Se um dia for para mais gente, conversar antes com a Ufac (NTI/Proaes).
9. **Aviso visível:** a tela de boas-vindas diz que é um app independente, feito por um aluno, e não um app oficial da Ufac.

## 4. Arquitetura

**Telas nativas na frente, sites da Ufac nos bastidores.**

- **WebView escondida** (`flutter_inappwebview`): carrega as páginas da Ufac em segundo plano, com a sessão do usuário, e entrega o HTML aos **extratores** em Dart (`lib/extractors/`), que devolvem os dados para o app.
- **Cache local** (`sqflite`): tudo que foi lido fica salvo; as telas abrem instantâneas e funcionam offline, com "Atualizado às HH:MM".
- **A WebView só aparece em 2 momentos:**
  - **Login:** tela própria do app, com cabeçalho do app e texto "Entre com seu ID Ufac — sua senha fica só no site da Ufac", e a página de login oficial embaixo.
  - **Recarga de créditos:** fluxo oficial do eTICKET.
  - (Extra: item "Abrir site completo" no Menu, para o que o app ainda não cobre.)
- **Sessão expirada:** detectar redirecionamento para a página de login → mostrar os dados do cache. Ao abrir, o app só confere o eTICKET, com aviso discreto e botão "Entrar de novo". O portal (sessão curta, menos de 1 hora) só pede login quando uma tela precisar dele, sem aviso ao abrir.
- **Pedir login o menos possível:** a sessão dura o que o servidor permitir. Nunca interromper a pessoa com tela de login: o app abre com o cache e o QR funciona offline, e só o botão "Entrar de novo" leva ao login. Na página oficial, deixar o preenchimento automático do Android (Google, etc.) oferecer CPF e senha; quem guarda é o gerenciador de senhas do celular, nunca o app.
- **QR:** gerado **localmente** (`qr_flutter`) a partir do número guardado → 100% offline.
- **PDFs dos relatórios:** baixados com os cookies da sessão da WebView, abertos num visualizador dentro do app (`pdfx`) e salvos/compartilhados pelo Android. Nunca por servidor externo.

**Stack:** Flutter (Dart), `flutter_inappwebview`, `sqflite`, `flutter_secure_storage`, `qr_flutter`, `screen_brightness`, `image_picker` + `image_cropper` (foto de perfil), visualizador de PDF, `share_plus`, `url_launcher` (WhatsApp/e-mail), `package_info_plus` + `device_info_plus` (versão e modelo no relato), instalador de APK para atualizações, fonte embutida em `assets/fonts/` (sem baixar da internet), `flutter_launcher_icons`, `flutter_native_splash`. Lembretes (v0.2): `flutter_local_notifications` + `workmanager`.

## 5. Telas e navegação

### Boas-vindas (primeira abertura, ou depois de "Sair")
Ícone próprio do app (capelo branco e âmbar sobre azul, o mesmo para todos), "UFAC+", frase "Portal do Aluno e RU num lugar só…". Cartão com 2 garantias: "Sua senha fica com a Ufac" e "Seus dados ficam no seu celular". Dois botões: **Sou aluno** (destaque) e **Sou professor** (contorno). O perfil define portal, abas e cores (azul para alunos, âmbar para professores). Rodapé: "App independente, feito por um aluno. Não é um aplicativo oficial da Ufac."

### Login oficial
Tela do app com voltar, título "Entrar com ID Ufac", "Etapa 1 de 2 · Portal do Aluno" e selo verde "Página oficial da Ufac · sua senha não passa pelo app". Embaixo, a WebView com a página de login real. Depois do Portal, sempre pedir a etapa 2 (eTICKET), porque o login não é compartilhado. Cada etapa tem o botão **Pular** (desde 14/11/2026): dá para conectar só o Portal ou só o eTICKET, nunca nenhum; o resto se conecta depois em Configurações › Contas da Ufac. Ao concluir: ler os dados da pessoa e abrir a Início.

**Barra inferior (5 itens):** Início · Horários · Notas · Biblioteca · **RU** (desde 14/11/2026; Relatórios fica no Menu). Professor: Início · Horários · Turmas · Relatórios · RU.

**Menu (☰):** botão redondo no canto superior direito das telas principais (ao lado das notificações na Início). Abre a tela Menu.

### Início
Ordem dos cartões, de cima para baixo:
1. Cabeçalho: data por extenso ("Quarta, 4 de novembro"), "Olá, Arthur" (primeiro nome), botão de notificações e botão ☰.
   - **Aviso de feriado** (logo abaixo do cabeçalho, só quando houver): faixa âmbar (cores do token chip) com ícone de calendário: "Amanhã é feriado · [nome]" / "Sem aulas. Confira o funcionamento do RU." Aparece na véspera e no próprio dia ("Hoje é feriado · [nome]"). Ver "Feriados" abaixo.
2. **Cartão de identificação (o mais importante):** foto do aluno num quadrado arredondado (ver "Foto de perfil" abaixo), nome completo, "Bacharelado em Direito · Ufac"; grade com 3 blocos: **Matrícula**, **Período atual** (ex.: 8º), **Semestre** (ex.: 2º / 2026).
3. **Cartão do RU** (fundo azul primário, texto branco): "Saldo no RU", valor grande, "Atualizado às HH:MM"; botões **Mostrar QR** (âmbar, texto escuro) e **Recarregar** (contorno branco).
4. **Próxima aula:** etiqueta âmbar "começa em X min", nome da disciplina e horário.
5. **Próxima refeição:** linha clicável com ícone verde, "Próxima refeição · Café/Almoço/Jantar · horário", primeiro item do cardápio → abre a aba RU nessa refeição.

**Foto de perfil (decidido: escolher da galeria):**
- Tocar no quadrado da foto abre o seletor de imagens do Android (`image_picker`); permitir recortar em quadrado (`image_cropper`).
- A foto fica **só no celular** (pasta privada do app), reduzida para ~512 px. Nunca enviada para lugar nenhum.
- Sem foto escolhida → mostrar as iniciais (ex.: "AH") no mesmo quadrado.
- Em Configurações: "Trocar foto" e "Remover foto". "Sair" também apaga a foto.

### QR do RU
Tela cheia, botão fechar (X) no topo e selo "Brilho no máximo". Título "QR do RU", "Aponte para o leitor na entrada". QR grande (~250 px) num cartão **sempre branco** (inclusive no modo escuro, para o leitor ler), número mascarado embaixo. Selos "Saldo R$ X" e "Funciona offline". Botão "Atualizar QR" e aviso "Não compartilhe prints desta tela". Ao abrir: brilho no máximo + vibração leve; ao sair: brilho volta ao normal.

### Horários
Linha do tempo da semana, dia atual destacado; cada aula com disciplina e horário. Sem local: o portal nunca informa a sala.

### Notas
Lista por disciplina, com notas e frequência (alerta quando a frequência chegar perto do limite — v0.2).

### Relatórios
Título "Relatórios", subtítulo "Direito · 8º período · 2º semestre / 2026". Um cartão branco com os 7 relatórios em lista: ícone "PDF" (fundo vermelho claro), nome, botão **Visualizar** (olho, fundo azul claro) e botão **Baixar** (seta, fundo azul). Abaixo, linha "Mais relatórios" e o rodapé "Os PDFs são gerados pelo Portal do Aluno na hora do pedido".

### RU (aba)
Título "RU", subtítulo "Restaurante Universitário · Ufac", botão ☰.
1. Cartão azul: "Saldo", valor grande, "Atualizado às HH:MM"; botão grande âmbar **Mostrar QR de entrada** (largura total); botão **Recarregar créditos** (contorno branco).
2. **Cardápio de hoje** (com a data), com seletor de 3 abas: **Café · Almoço · Jantar**, cada uma com seu horário. Abre já na próxima refeição do dia (antes do café → Café; depois do café → Almoço; depois do almoço → Jantar). O eTICKET publica cada refeição como uma frase só: mostrar uma lista, separando pelas vírgulas, sem afirmar o tipo de cada item (nada de "opção vegetariana" que o texto não diga). O eTICKET costuma publicar pouco antes do horário da refeição, então "Não informado" é normal: mostrar "O cardápio do almoço ainda não saiu. Costuma aparecer perto do horário." com o botão **Ver no Instagram do RU** (abre `@ru.informa.ufac` fora do app, sem enviar dado nenhum; o endereço fica na configuração). Refeição sem cardápio é lida de novo a cada abertura do app. A página não tem data: nunca mostrar como "hoje" um cardápio lido em outro dia.
3. Linha **Histórico de uso** (refeições e recargas) → tela do histórico do eTICKET.

### Menu (☰, aberto pelo botão do topo)
Título "Menu" com botão fechar (X).
- Seção **Portal do Aluno** (grade 2 colunas de cartões com ícone): Matrícula, Biblioteca, Comunicações, Links externos, Abrir site completo.
- Botões no rodapé: **Configurações** (abre a tela abaixo) e **Sair** (vermelho).

### Configurações
Voltar + título "Configurações". De cima para baixo:
1. **Foto de perfil:** miniatura, "Fica só neste celular", botão **Trocar** (e "Remover foto" quando houver foto).
2. **Aparência:** seletor de 3 opções **Sistema · Claro · Escuro** (padrão: Sistema).
3. **Avisos:** chave **Avisar sobre feriados** ("Na véspera, na tela Início"), ligada por padrão.
4. **Ajuda e app:**
   - **Verificar atualizações** — mostra a versão instalada e se há nova (ver "Atualizações").
   - **Relatar um problema** — ver abaixo.
   - **Limpar dados salvos** — apaga o cache (não a sessão); recarrega tudo da Ufac na próxima abertura. Pedir confirmação.
   - **Sobre o UFAC+** — versão, "App independente, feito por um aluno. Não é um aplicativo oficial da Ufac.", e o que o app guarda no celular.
5. Botão **Sair da conta** (vermelho, contorno) — pede confirmação; apaga sessão, cache, número do QR e foto, e volta para Boas-vindas.

### Feriados
- **Fonte:** lista local, dentro do app (o Calendário do portal é um Google Agenda parado em março de 2022, e não serve): feriados nacionais (as datas móveis, como Carnaval, Sexta-feira Santa e Corpus Christi, calculadas a partir da Páscoa) mais os feriados estaduais do Acre e municipais de Rio Branco. Essa lista é revisada uma vez por ano, numa atualização do app; **não inventar datas**: conferir em fonte oficial antes de colocar.
- **RU:** não afirmar que o RU está fechado; só dizer "Confira o funcionamento do RU", a menos que o eTICKET informe.
- Respeitar a chave "Avisar sobre feriados" das Configurações.

### Atualizações do app
- O app é distribuído por APK. A cada nova versão, publico o APK numa página pública de **Releases** de um repositório no GitHub (só o APK e as notas da versão — **nunca** código com dados pessoais).
- Ao abrir (no máximo 1 vez por dia) e no botão "Verificar atualizações", o app consulta **só** a última versão publicada nessa página e compara com a instalada. Não envia nenhum dado da pessoa.
- Se houver versão nova: faixa discreta na Início, "Nova versão disponível", com botão **Atualizar** que baixa o APK e abre o instalador do Android. Nunca forçar.
- Configurar a assinatura do APK com **a mesma chave sempre** (senão o Android não deixa atualizar por cima). Guardar a chave fora do repositório e me explicar como fazer backup dela.

### Relatar um problema
- Abre uma escolha: **WhatsApp** ou **e-mail**, já endereçados a mim (meu número/e-mail ficam numa configuração do build, não fixos no meio do código).
- A mensagem vem pré-preenchida com: versão do app, modelo do celular, versão do Android e a tela onde a pessoa estava, mais um espaço "O que aconteceu?".
- **Nunca** incluir CPF, matrícula, número do QR, notas, cookies ou prints automáticos. A pessoa revisa e envia ela mesma.

## 6. Design (tokens — usar exatamente isto em `lib/theme/`)

Material 3 com tema próprio. Nada de cor solta no código. **Modo claro e escuro desde o início**, seguindo o sistema.

| Token | Claro | Escuro |
|---|---|---|
| background | `#F3F5F9` | `#0A0F1A` |
| surface (cartões, barra) | `#FFFFFF` | `#141B2A` |
| text | `#0E1726` | `#E9EEF6` |
| muted (texto secundário) | `#536074` | `#9AA6BA` |
| border | `#E3E8F0` | `#232D40` |
| chrome (botões redondos) | `#E6EBF2` | `#1A2233` |
| primary (cartão do RU) | `#0B4FA8` | `#16438C` |
| onPrimaryMuted | `#D3E1F7` | `#C6D7F4` |
| accent (Mostrar QR) | `#F2A516` (texto `#1A1300`) | `#F5B23A` (texto `#1A1300`) |
| chip (etiqueta "começa em") | fundo `#FFF1D6`, texto `#7A4A00` | fundo `#3A2A0A`, texto `#F8C76A` |
| navActive / navActiveBg | `#0B4FA8` / `#E2ECFB` | `#8DB4FF` / `#1B2A47` |
| verde (comida, "offline") | `#1F7A44` sobre `#E1F4E8` | `#7BD69E` sobre `#163323` |
| perigo (Sair, PDF) | `#B42318` sobre `#FDE8E6` | ajustar mantendo contraste AA |

**Versão dos professores** (âmbar da Ufac desde 14/11/2026; mesmos tokens, trocando só estes; contraste AA conferido em `test/contraste_test.dart`):

| Token | Claro | Escuro |
|---|---|---|
| primary (texto sobre ela: `#1A1300`) | `#F2A516` | `#F5B23A` |
| onPrimaryMuted | `#4D3300` | `#4D3300` |
| accent (botão de destaque, escuro sobre o âmbar) | `#1A1300` (texto branco) | `#1A1300` (texto branco) |
| navActive / navActiveBg (também a cor dos botões de texto) | `#8A5300` / `#FFF1D6` | `#F8C76A` / `#3A2A0A` |
| perigo | o mesmo vermelho do aluno | o mesmo vermelho do aluno |

- **Fonte:** Plus Jakarta Sans (embutida). Saldo 34–40 px peso 800; títulos de tela 24–26 px peso 800; títulos de cartão 18 px peso 700; texto 14–15 px; rótulos 11–13 px peso 600.
- **Raios:** cartões 20–22 px; botões 14 px; ícones-quadrado 12–16 px; selos em pílula.
- **Espaçamento:** margem lateral 20 px; 14–16 px entre cartões; padding interno 16 px.
- **Ícones:** uma única família de traço arredondado (Material Symbols Rounded ou Phosphor). Sem emoji na interface.
- **Ícone do app e splash** próprios. **Não** usar logo da Ufac nem do eTICKET.
- Áreas de toque ≥ 44 px; contraste WCAG AA; respeitar tamanho de fonte do sistema e área segura.

**Acabamento obrigatório:**
- Carregamento com **skeleton** animado, nunca tela branca ou spinner solto.
- Estados vazios e de erro desenhados, em linguagem humana ("Sem aula hoje", "Não consegui falar com o eTICKET agora — mostrando dados das 9h40"). Nunca "erro 500", "null", "sessão inválida".
- Transições de 200–300 ms; vibração leve ao abrir o QR e ao puxar para atualizar.
- Formatos brasileiros: R$ 12,50; "qua, 4 de nov"; 10h20.
- Componentes reutilizáveis em `lib/ui/` (cartão, botão primário, item de lista, skeleton, estado vazio, barra inferior).

## 7. Fase 0 — Reconhecimento (antes de codar as telas)

Fazer comigo, no navegador do PC com o DevTools aberto (eu faço o login):

1. Login: tem CAPTCHA? Quanto dura a sessão? Logar no portal libera o eTICKET (ou vice-versa)?
2. Para cada dado (identificação, horários, notas, saldo, número do QR, cardápio): em que página está, e se vem no HTML ou numa requisição XHR/JSON (aba Network). JSON interno é preferível.
3. URL de cada um dos 7 relatórios em PDF e o que há em "Mais relatórios". Confirmar se o PDF baixa direto com os cookies.
4. Fluxo do botão Recarregar e meio de pagamento.
5. Aba Histórico do eTICKET (para a v0.2).
5b. Página **Calendário** do portal: como aparecem feriados, recessos e dias sem aula.
6. Salvar HTML de exemplo **anonimizado** (nome, CPF, matrícula, número do QR trocados por dados falsos) em `fixtures/`.
7. Registrar tudo em `docs/reconhecimento.md`.

## 8. Estrutura de pastas

```
ufac_no_bolso/
  lib/
    main.dart
    theme/          # tokens de cor, tipografia, espaçamento (claro e escuro)
    ui/             # componentes reutilizáveis
    screens/        # inicio, qr, horarios, notas, relatorios, ru, menu, login, configuracoes
    session/        # WebView em segundo plano, login, detecção de sessão expirada
    extractors/     # um extrator por dado, em Dart
    data/           # SQLite, modelos, armazenamento seguro
    pdf/            # download com sessão, visualizador, salvar/compartilhar
  fixtures/         # HTML de exemplo anonimizado
  test/             # testes dos extratores contra as fixtures
  tools/            # scripts de apoio (leitura mascarada da Fase 0)
  docs/
    reconhecimento.md
    decisoes.md
  CLAUDE.md
```

## 9. Roteiro

1. **Fase 0** — reconhecimento (seção 7).
2. **Base:** projeto Flutter, tema/tokens claro e escuro, fonte, componentes de `lib/ui/`, barra inferior com as 5 abas (telas ainda com dados de exemplo), ícone e splash. → me mostrar prints claro/escuro.
3. **Boas-vindas + login + sessão:** tela de boas-vindas, login com WebView oficial, sessão persistente, detecção de expiração.
4. **QR do RU:** ler o número do eTICKET, guardar seguro, gerar QR offline, tela cheia com brilho e vibração.
5. **RU:** saldo + cardápio (página logada) + botão Recarregar.
6. **Início:** cartão de identificação + próxima aula + próxima refeição, com cache e "puxar para atualizar".
7. **Relatórios:** lista dos 7 PDFs + "Mais relatórios", visualizar e baixar.
8. **Horários** e **Notas**.
9. **Aba RU** completa (histórico) e **Menu (☰):** atalhos do portal.
10. **Configurações** (tema, foto, avisos, limpar dados, Sobre, Sair), **Relatar um problema** e **aviso de feriados** (lista local).
11. **Atualizações:** assinatura fixa do APK, página de Releases no GitHub, verificação de versão nova.
12. Gerar APK e instalar no meu celular → **MVP pronto**.

**Depois do MVP (v0.2):** frequência com alerta de faltas; lembretes de saldo baixo e de almoço; widget de horários (sem QR); calendário acadêmico com notificações; exportar horários para o Google Agenda; histórico de gastos do RU.

## 10. Como trabalhar comigo

- Etapas pequenas e testáveis; no fim de cada uma, dizer em português simples o que mudou e **como testar no celular**.
- Cada extrator tem teste automático contra uma fixture; se o site mudar, o teste aponta qual extrator quebrou.
- Se um extrator falhar no app, mostrar "Não consegui ler X — abrir a página" em vez de travar ou mostrar dado errado.
- Explicar decisões sem jargão. Registrar as importantes em `docs/decisoes.md`.
- Economizar tokens: edições pontuais, não reescrever arquivos inteiros sem necessidade.
- Antes de qualquer coisa que envolva meus dados reais (login, cookies, PDFs), me avisar o que vai fazer.

## 11. Perguntas em aberto

- Quanto dura exatamente a sessão? (o portal caiu em menos de 1 hora parado; o eTICKET passou de 1 hora)
- O preenchimento automático de senha funciona dentro do app? (depende de ativar o serviço no Android)
- O que vem depois de confirmar o valor em Recarregar?

---

## 12. Handoff para a próxima sessão (estado em 10/11/2026)

> As seções 1 a 11 continuam valendo como regras e especificação. Esta seção diz **onde o trabalho parou**. Os detalhes de cada decisão estão em `docs/decisoes.md`, e os do site da Ufac, em `docs/reconhecimento.md`.

### 12.1 Visão geral
- **Nome no celular:** **UFAC+** (antes "UFAC no Bolso"). O identificador `io.github.ufacnobolso.ufac_no_bolso` **não muda nunca**, porque trocá-lo impede as atualizações por cima. A pasta do projeto e o repositório também mantêm o nome antigo.
- **Dois perfis no mesmo APK:** aluno (azul, completo) e professor (vermelho, por enquanto só uma prévia). O perfil é escolhido nas boas-vindas.
- **Stack:** Flutter 3.47.9, Dart 3.13, só Android (minSdk 24). Testado num moto g35 5G (Android 15) (o número de série do adb fica em `CLAUDE.local.md`).
- **Comandos:** sempre de dentro de `android/` (`cd android`), pelo atalho sem espaços **`C:\dev\flutter_sdk\bin\flutter`**.
  - Testes: `flutter test --exclude-tags visual`
  - Prints dos temas: `flutter test test/visual_test.dart --update-goldens --tags visual` (saem em `test/goldens/`)
  - APK final: `flutter build apk --release --dart-define-from-file=.env.json`
  - Instalar por cima: `adb -s <serial> install -r build/app/outputs/flutter-apk/app-release.apk`
- **`.env.json` (fora do git):** `CONTATO_EMAIL` (valor em `CLAUDE.local.md`), `ATUALIZACOES_REPO` (`ufac-plus/ufac-plus`) e, opcional, `CONTATO_WHATSAPP`. Os valores vão dentro do APK, que é público.
- **Chave de assinatura:** fora do repositório (caminho em `CLAUDE.local.md`; `ufac_no_bolso.jks` + `key.properties`, com cópia em `android/android/key.properties`). SHA-1 pública: `7D:85:A3:3B:3D:30:45:02:4A:20:CD:0A:81:53:EC:F1:CD:60:8E:BA`. Nunca mostrar a senha.
- **Publicação:** Releases em github.com/ufac-plus/ufac-plus. Android: `UFAC+ Android 0.1.x` (tag `v0.1.x`), sempre a Latest, com o `.apk`. iPhone: `UFAC+ iPhone 1.x` (tag `iphone-v1.x`), sempre `--latest=false`. Nunca Pre-release. Passo a passo em `docs/publicar.md`.
- **Git:** repositório **público** github.com/ufac-plus/ufac-plus (organização ufac-plus; Arthur e Matheus são donos). Pastas: `android/` (este projeto Flutter: rodar o `flutter` de dentro de `android/`), `iphone/` (do Matheus), `docs/`, e o site do GitHub Pages na raiz (`index.html`, `privacidade.html`). O histórico antigo do Android fica no privado e arquivado `ufac-plus/ufac-plus-antigo`: nunca dar push dele no público. Segredos e dados reais ficam fora pelo `.gitignore` da raiz. Dados pessoais da máquina (e-mail, serial do celular, caminho da chave) ficam no `CLAUDE.local.md`, fora do git.

### 12.2 Estrutura (arquivos principais)
- `lib/main.dart`: carrega preferências, perfil, foto e dados salvos, e escolhe o tema pelo perfil. Também tem o `--dart-define=TEMA` para prints.
- `lib/config.dart`: horários das refeições, URLs da Ufac, `RelatorioPortal`, `limiteFaltas` (16), contatos e repositório de atualização.
- `lib/theme/`: `app_cores.dart` (tokens; `professorClaro`/`professorEscuro` trocam só primária, aba ativa e perigo), `app_tema.dart`, `app_texto.dart` (fonte variável, peso via `fontVariations`) e `app_medidas.dart`.
- `lib/ui/`: `componentes.dart` (Cartao, botões, Selo, ItemLista, CabecalhoTela, EstadoVazio, Skeleton, FaixaAviso, SeletorAbas, ListaDaTela com puxar para atualizar), `barra_inferior.dart`, `formatos.dart` e `tela_atual.dart`.
- `lib/session/`: `regras_sessao.dart` (o que é página de login, troca de http por https, só sites da Ufac) e `sessao.dart` (WebView invisível `_lerComWebView`, `lerEMarcar` e `verificar`, que só confere o eTICKET ao abrir).
- `lib/extractors/`: `eticket_inicio.dart` (saldo e QR), `eticket_cardapio.dart`, `eticket_historico.dart` e `portal.dart` (identificação, horários, notas completas, carga horária, Mais relatórios, Comunicações). Leem HTML com o pacote `html`.
- `lib/data/`:
  - Repositórios: `repositorio_ru.dart` (saldo e QR no cofre, cardápio e histórico no SQLite) e `repositorio_portal.dart` (identificação, aulas e notas; matrícula e id interno no cofre).
  - Armazenamento: `banco.dart` (SQLite chave-valor).
  - Modelos: `academico.dart` (`proximaAula`, `situacaoFaltas`, `notasDaDisciplina`), `cardapio.dart`, `historico.dart` e `feriados.dart` (Páscoa e lista de 2026 conferida).
  - Preferências e perfil: `preferencias.dart` (tema e feriados), `perfil.dart` (aluno ou professor), `foto_perfil.dart` e `atualizacoes.dart` (GitHub Releases).
- `lib/pdf/`: `baixar_pdf.dart` (download com cookie e redirecionamentos) e `servico_pdf.dart` (pasta temporária).
- `lib/screens/`:
  - Entrada e login: `boas_vindas.dart` (Sou aluno / Sou professor), `login.dart` (enquadramento do Portal e trava do vh no eTICKET) e `casca.dart` (5 abas; lê ao abrir e ao voltar).
  - Abas: `inicio.dart`, `horarios.dart`, `notas.dart`, `relatorios.dart` e `ru.dart`.
  - Telas de apoio: `qr.dart`, `recarga.dart`, `historico.dart`, `pdf.dart` (pdfx, salvar e compartilhar), `site_oficial.dart` (página oficial dentro do app), `menu.dart` (`confirmarSaida`), `configuracoes.dart`, `relatar.dart`, `aviso_faltas.dart`, `acoes_portal.dart` (`entrarNoPortal`, `atualizarPortal`) e `professor_em_breve.dart` (prévia vermelha, sem salvar o perfil).
- `tools/`: `mascara.js` (leitura mascarada), `gerar_icone.dart` (ícone atual: capelo) e `gerar_icone_opcoes.dart` (as 7 opções avaliadas, de A a G).
- `fixtures/` (HTML anonimizado; `public/` sem login; `raw/` fora do git) e `test/` (extratores, sessão, PDF, feriados, atualizações, base e `visual_test.dart`).
- `docs/`: `reconhecimento.md`, `decisoes.md`, `publicar.md`, `classroom.md`, `prints/` e `publicar/`, que fica fora do git e guarda o APK e as notas a publicar.

### 12.3 Pronto e funcionando (validado por Arthur no celular)
- **Etapas 1 a 12 do roteiro.** O MVP está publicado como **v0.1.5 "latest"**, com o SHA-256 do APK conferido.
- **Entrada:** login nas duas etapas, sessão, cache offline e aviso de sessão expirada só para o eTICKET.
- **RU:** QR offline com brilho (passou na leitura de outro aparelho), saldo, cardápio, Instagram, recarga oficial e histórico.
- **Portal:** Início com dados reais, Horários, Notas com o quadro completo (avaliações, pesos, Exame, Média Final) e aviso de faltas. Relatórios em PDF (ver, salvar, compartilhar) e Mais relatórios.
- **Menu e Configurações:** Menu, Configurações (tema, foto, feriados, limpar, Sobre, Sair), relato por e-mail e verificação de versão.
- **Testes:** 80 testes passando (`--exclude-tags visual`).

### 12.4 Decisões principais (motivos em `docs/decisoes.md`)
- **Login e sessão:**
  - Senha: desde 13/11/2026, login automático opcional (chave ligada por padrão): CPF e senha cifrados no cofre, login refeito na página oficial escondida, uma tentativa por leitura, nunca com CAPTCHA. Antes, Arthur tinha recusado o login automático. Ver `docs/decisoes.md`.
  - Portal: a sessão cai em menos de 1 hora, então não há aviso ao abrir. O login é pedido só quando uma tela precisa.
  - http: os saltos do portal são trocados por https antes de sair do celular. O backup do Android está desligado.
- **Leitura de dados:**
  - Extratores em Dart, sobre o HTML, testáveis com fixtures (em vez de JS injetado).
  - O número do QR é a matrícula. A matrícula fica sempre visível na Início, mas só no cofre, nunca no SQLite.
- **Notas e faltas:**
  - Faltas: até **16 são permitidas** e a **17ª reprova** (decisão final de Arthur). O aviso começa em 12. Os 25% da carga horária foram descartados.
  - Notas: só do semestre atual, sempre com a data da leitura.
- **Feriados:** lista local. Os nacionais e móveis são calculados. Os do Acre e de Rio Branco entram só depois de conferidos: hoje só 2026. Carnaval e Corpus Christi são pontos facultativos ("Confira se há aula").
- **Visual:**
  - Nome: UFAC+.
  - Ícone: **opção E**, capelo branco com borla âmbar sobre `#0B4FA8`, igual para todos.
  - Professores: âmbar `#F2A516` (claro) e `#F5B23A` (escuro), com texto escuro e perigo vermelho, contraste AA conferido (era vermelho até 14/11/2026).
  - Calendário: o atalho saiu do Menu (agenda parada em 2022).
- **Ferramentas:** pdfx em vez de pdfrx; `flutter_inappwebview` fixo em `6.2.0-beta.3`.
- **Fora do escopo por ora:** o ônibus (sem dados públicos). Pode voltar só como tabela manual.

### 12.5 Em andamento (onde parou)
- **v0.1.6** (16 faltas permitidas): rascunho criado no GitHub como "latest", com notas. **Falta Arthur anexar** `publicar/ufac-mais-v0.1.6.apk` e publicar. Conferir com `curl https://api.github.com/repos/ufac-plus/ufac-plus/releases/latest`.
- **Celular:** está **de propósito na 0.1.5**, para testar a faixa "Nova versão disponível" quando a 0.1.6 sair. Não instalar pelo cabo antes disso.
- **Já no código, mas fora de qualquer APK:** o ícone novo (capelo) e a etapa 2 (escolha de perfil e paleta vermelha). Aguarda Arthur **aprovar as cores** (prints em `test/goldens/`). O `pubspec.yaml` ainda está em `0.1.6+7`.
- **Plano v0.2 aprovado, nesta ordem:**
  1. Ícone neutro: **feito**.
  2. Tema por perfil: **feito no código**.
  3. Classroom.
  4. Biblioteca.
  5. Ônibus.
  6. Portal do Professor.

### 12.6 Próximos passos (prioridade)
1. Confirmar se a v0.1.6 foi publicada e se a atualização dentro do app funcionou no celular (faixa → Atualizar → instalador → login mantido).
2. Com as cores aprovadas: `version: 0.1.7+8`, gerar o APK, preparar `publicar/` e o rascunho da Release (o Chrome não envia arquivos acima de 10 MB, então Arthur anexa o APK). **Não marcar Pre-release.**
3. **Classroom:** Arthur vai criar o projeto no Google Cloud com o prompt e o guia de `docs/classroom.md`, e mandar o **ID do cliente Android**. Depois: um teste só de login para ver se a Ufac bloqueia; o cartão "Atividades da semana"; a notificação local diária (`flutter_local_notifications` + `workmanager`); e o ID no `.env.json`.
4. **Biblioteca:** Arthur precisa abrir "Meu Espaço" e "Renovação" no navegador dele. Se funcionar, refazer a leitura mascarada, a aba Biblioteca no lugar de Relatórios (que vão para o Menu) e a renovação com confirmação livro a livro.
5. **Ônibus:** só se Arthur conseguir a tabela oficial (linhas 501, 502 e 902, com a 902-1 agrupada). Fica num arquivo de horários fácil de editar, com "horários de [data]".
6. **Portal do Professor:** leitura mascarada com um dos dois professores que toparam ajudar. Depois, abas do professor e "Sou professor" de verdade, guardando o perfil.
7. Revisar os feriados de 2027 em fonte oficial (decreto do Acre e da Prefeitura).

### 12.7 Problemas conhecidos e o que não funcionou
- **Flutter e Android:**
  - Caminho com espaços quebra a compilação: usar `C:\dev\flutter_sdk` (atalho de pasta).
  - O `sdkmanager` virou "Android CLI": para instalar pacotes, usar `android sdk install ndk/<versão>`. O NDK 28.2 já está instalado.
  - `flutter_inappwebview` 6.1.5 não compila com AGP 9 (proguard): por isso a beta.
  - `pdfrx` exige compilador C no PC até para `flutter test`: trocado por `pdfx`.
  - A compilação avisa "Built-in Kotlin" em alguns plugins. Por enquanto só é um aviso.
  - O emulador (`Medium_Phone_API_37.0`) não ficou pronto em modo sem janela: usar o celular.
- **GitHub:**
  - Release marcada como "Pre-release" não aparece em `/releases/latest`, então o app não a enxerga.
  - Repositório vazio não aceita Release: foi preciso criar o README antes.
- **Sites da Ufac:**
  - **Biblioteca:** "Meu Espaço" e "Renovação" caem em `/biblioteca/500.action` ("Requisição Incompleta"), até clicando no próprio site.
  - **Mais relatórios:** a geração de PDF depois do formulário nunca foi vista.
  - **Recarga:** a tela depois de confirmar o valor também nunca foi vista.
  - No navegador do PC, um `fetch` que redireciona por http falha (no app, isso é resolvido trocando por https).
- **Celular de Arthur:**
  - O serviço de preenchimento automático do Android está desligado, por isso não oferece a senha.
  - Prints: um print pegou a cortina de notificações dele. Só capturar com o app em primeiro plano e WebView visível (`dumpsys window` / `dumpsys activity top`), e nunca em telas com dados reais.
- **Dúvidas sem resposta:**
  - Feriado de 17/11/2026: o decreto diz 17, um trecho do TRE-AC indica 19. O app usa 17.
  - Ainda não vi uma disciplina em andamento com o quadro de notas parcial.
- **Pequenos:** na leitura pelo navegador do painel, o endereço da página mostra o id interno do portal (não é a matrícula). A vírgula parece afastada do número em "12 ,50" (detalhe de fonte, não investigado).

### 12.8 Convenções
- **Língua:** código, nomes e textos em português ("aoTocar", "carregando", "Não consegui…"). Comentários curtos explicam o porquê.
- **Visual:** cores só pelos tokens de `AppCores` (`context.cores`) e componentes de `lib/ui/`. Nunca cor solta nem spinner solto: usar Skeleton e EstadoVazio.
- **Extratores:** cada extrator novo tem fixture anonimizada e teste. Se falhar, devolve null, para nunca mostrar dado errado.
- **Dados sensíveis:**
  - Matrícula, número do QR, id interno e preferências ficam no `FlutterSecureStorage`. Cache comum vai para `Banco` (SQLite).
  - Nada sensível em log.
  - Antes de ler dados reais de Arthur, avisar. No PC, ler só com a máscara (`tools/mascara.js`).
- **Requisições à Ufac:** poucas, só ao abrir, ao voltar (no máximo a cada 15 minutos), ao puxar para atualizar ou quando uma tela precisa. Sem tarefas em segundo plano nos sites da Ufac.
- **Versões:** toda versão nova sobe `version` no `pubspec.yaml` (o número depois do `+` sempre cresce). Compila `--release` com `.env.json`, instala com `adb -s <serial> install -r` e registra a decisão em `docs/decisoes.md`.
- **Compilações longas:** rodar em segundo plano. Só instalar no celular se compilou, e conferir travamentos com `logcat -b crash`.
- **Publicar e decidir:** publicar no GitHub só com o "pode publicar" de Arthur. Perguntar quando algo for ambíguo, e não inventar dados (feriados, horários, labels do site).

## 13. Bugs e features: GitHub Issues

A lista única de bugs e features do UFAC+ (Android e iPhone) fica nas Issues de `ufac-plus/ufac-plus`. Etiquetas: `tipo:bug`/`tipo:feature`, `plataforma:android`/`plataforma:iphone`, `resolvido:android`/`resolvido:iphone` (feito numa plataforma só) e `prioridade:alta`.

- Ao começar uma sessão no Android, rodar `gh issue list --repo ufac-plus/ufac-plus --label plataforma:android` e ler a issue (`gh issue view <n>`) antes de mexer no assunto.
- Ao resolver: comentar com o commit (`gh issue comment <n> --body "Resolvido no Android em <commit>: <resumo>"`). Se a issue também tem `plataforma:iphone`, só pôr `resolvido:android` (`gh issue edit <n> --add-label resolvido:android`) e deixar aberta. Se é só do Android, ou o iPhone já tem `resolvido:iphone`, fechar.
- Bug ou ideia nova: `gh issue create` com as etiquetas certas, só com o ok de Arthur. O repositório é público: nunca pôr CPF, matrícula, número do QR, cookies ou prints com dados reais.
