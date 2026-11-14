# Decisões do projeto

## 2026-11-04: fixtures separadas por origem
- `fixtures/public/`: páginas abertas sem login. Só o token de formulário e o identificador de sessão anônima são trocados.
- `fixtures/` (demais arquivos): páginas com login, depois de anonimizadas.
- `fixtures/raw/`: material bruto com dados reais. Fica fora do git.

## 2026-11-04: matrícula sempre visível na Início
O número do QR é igual à matrícula. Arthur decidiu manter a matrícula sempre visível no cartão de identificação, sem ocultar nem pedir toque.
Continua valendo: ela fica no armazenamento seguro (não no SQLite), nunca vai para log, notificação, widget nem para o relato de problema.

## 2026-11-04: horários das refeições como configuração
O eTICKET não informa horários. Valores vindos do post do RU no Instagram (@ru.informa.ufac) de 04/11/2026: café 06h30 às 08h, almoço 11h às 14h, jantar 18h às 19h30. Ficam num único arquivo de configuração, porque podem mudar e só são atualizados numa nova versão do app.

## 2026-11-04: fonte do cardápio
Usar a página logada `/eticket/menu/`. A página pública mostrou "Indisponível" enquanto a logada já tinha o café, e traz outros preços.
A página não tem data: o cache guarda o dia da leitura, e cardápio de outro dia nunca aparece como "hoje".
Sem cardápio da semana no MVP, porque não há fonte.

## 2026-11-04: feriados
O calendário do portal parou em março de 2022. A lista local passa a ser a fonte principal.

## 2026-11-04: menos logins, sem guardar senha
Arthur pediu para não ter de entrar toda vez. A regra 2 continua: o app não guarda a senha. Em vez disso: o app abre com o cache e o QR offline, nunca interrompe com tela de login, e o gerenciador de senhas do Android pode preencher a página oficial. Não mantemos a sessão viva com requisições em segundo plano (regra 5). A duração real da sessão ainda será medida.

## 2026-11-04: identificador do app
`applicationId` = `io.github.ufacnobolso.ufac_no_bolso`. Não usa domínio da Ufac e não pode mudar depois sem quebrar as atualizações.

## 2026-11-04: fonte e ícones
Plus Jakarta Sans fica embutida em `assets/fonts/` (arquivo variável, licença OFL), em vez do pacote `google_fonts`, para o app não buscar nada na internet. Ícones: `Icons.*_rounded`, que já vêm com o Flutter.

## 2026-11-04: nada de http no celular
O portal redireciona passando por `http://`. Em vez de liberar `http` no Android, o app troca esses endereços para `https://` antes de seguir (`versaoHttps`). Assim o cookie de sessão, que não tem a marca `Secure`, nunca viaja sem criptografia. A página de login abriu assim no moto g35. O backup do Android também foi desligado.

## 2026-11-04: flutter_inappwebview em versão beta
A 6.1.5 (última estável) não compila com as ferramentas atuais do Android. Usamos a `6.2.0-beta.3`, fixa no `pubspec.yaml`. Trocar pela estável quando ela sair.

## 2026-11-04: Flutter por um caminho sem espaços
Uma etapa de compilação do Flutter quebra porque ele está em uma pasta com espaços no nome. Criamos o atalho de pasta `C:\dev\flutter_sdk`, que aponta para a mesma instalação. Rodar sempre `C:\dev\flutter_sdk\bin\flutter`.

## 2026-11-04: extratores em Dart
Os extratores recebem o HTML da página (`getHtml`) e leem com o pacote `html`, em Dart, em vez de JavaScript injetado. Assim rodam em `flutter test` contra as fixtures, como a seção 10 do CLAUDE.md pede, sem precisar de celular. O QR e o saldo usam a mesma página da verificação de sessão, para não pedir duas vezes à Ufac.

## 2026-11-04: Portal só quando for preciso
A sessão do portal caiu em menos de 1 hora parada. Para não mostrar "Sua sessão terminou" em quase toda abertura, o app confere só o eTICKET ao abrir (que traz saldo e QR). O portal é conferido quando uma tela precisar dele, e o login é pedido nessa hora (Arthur decidiu). Regra para as etapas 6 a 8: mostrar o que está salvo e não interromper.

## 2026-11-04: ajustes de enquadramento no login
A proporção errada do eTICKET vinha do teclado: o site mede o formulário pela altura da tela (`vh`). O app trava o tamanho com o teclado fechado. No portal, o app aproxima a área do formulário. Os dois ajustes só mudam o visual da página e não leem nem tocam nos campos. Se o site mudar, a página volta ao normal sem quebrar o login.

## 2026-11-04: cardápio e leituras ao voltar
O cardápio fica em SQLite com a data da leitura; cardápio de outro dia não aparece como "hoje". Como o eTICKET publica perto do horário, o app lê de novo enquanto faltar alguma refeição: ao abrir, ao voltar para o app (no máximo a cada 15 minutos) e ao puxar para atualizar na aba RU. Com as 3 refeições publicadas, não pede de novo à Ufac.

## 2026-11-04: recarga aceita outros sites https
A tela de recarga não fica presa aos endereços da Ufac, porque o pagamento pode passar por outro site. Só `https` é aceito. A tela depois de confirmar o valor ainda não foi vista.

## 2026-11-04: dados do Portal ficam salvos
Nome, curso, período, semestre e aulas ficam em SQLite; a matrícula, no armazenamento seguro. Como a sessão do portal é curta, o app lê esses dados só depois do login ou ao puxar para atualizar (Início e Horários). Se a sessão caiu ao puxar, aparece uma mensagem com "Entrar", sem interromper.

## 2026-11-04: PDFs
O app baixa os PDFs direto do portal, com os cookies da WebView, e os guarda só na pasta temporária; o arquivo é apagado ao fechar o visualizador e ao abrir o app. "Baixar" usa a tela "salvar como" do Android, sem pedir permissão de arquivos. Se a sessão caiu, a resposta não é PDF: o app oferece "Entrar" e, depois do login, continua o que a pessoa pediu.

## 2026-11-04: pdfx em vez de pdfrx
O `pdfrx` exige um compilador C no PC até para rodar `flutter test`. O `pdfx` usa o leitor de PDF do próprio Android e não tem essa exigência.

## 2026-11-04: notas só do semestre atual
O app lê a lista de notas e um quadro por disciplina (uma requisição cada), só do semestre mais recente. A sessão do portal é curta, então a tela mostra quando as notas foram lidas: nota antiga não pode parecer atual. A frequência em porcentagem fica para a v0.2; por enquanto aparece o total de faltas.

## 2026-11-04: histórico e Menu
O histórico do RU é lido só ao abrir essa tela e fica salvo. Os atalhos do Menu abrem a página oficial dentro do app (`TelaSiteOficial`), que pede o login sozinha se a sessão caiu. Conteúdo embutido em página oficial, como o calendário do Google, pode carregar; navegar para fora da Ufac, não. O sino da Início abre os avisos do eTICKET (`/eticket/informacao/`).

## 2026-11-04: feriados
Feriados nacionais fixos e datas móveis (calculadas pela Páscoa) valem para qualquer ano. Feriados do Acre e de Rio Branco ficam por ano, porque decretos podem mudar a data: só 2026 está na lista, conferido no Decreto estadual 11.809/2025, no calendário da Prefeitura (RBPREV) e no calendário federal (MGI). Em 2027, esses precisam ser conferidos e adicionados numa atualização do app.
Carnaval e Corpus Christi são pontos facultativos: o aviso diz "Confira se há aula", sem afirmar que não há. Outros pontos facultativos (vésperas, Dia do Servidor, Revolução Acreana) ficaram de fora.
**Dúvida a conferir:** 17/11/2026 (Tratado de Petrópolis) está no decreto sem adiamento, mas um trecho do calendário do TRE-AC indica comemoração em 19/11. O app usa 17/11.

## 2026-11-04: contato do relato
Número e e-mail vêm de `.env.json` no build (`--dart-define-from-file`), fora do git. Eles vão dentro do APK, que é público nas Releases. Arthur decidiu não colocar o e-mail: sem contato, a tela avisa que ele não está configurado.

## 2026-11-04: assinatura e atualizações
Chave RSA própria, com validade de 50 anos, fora do projeto (`docs/publicar.md`). A atualização consulta só a última Release do GitHub, aceita APK apenas de `https://github.com/` e abre o instalador do Android, que recusa APK com outra chave. O atalho do Calendário acadêmico saiu do Menu, a pedido de Arthur, porque a agenda parou em 2022.

## 2026-11-10: quadro de notas completo
A aba Notas mostra todas as colunas do quadro do portal: cada nota com peso, cada avaliação com peso e valor, o total, Média, Exame e Média Final, além da situação e das faltas. O cache das notas passou a se chamar `notas_v2`, e o formato antigo é ignorado (as notas são lidas de novo).

## 2026-11-10: login automático recusado
Arthur considerou guardar a senha para entrar sozinho e escolheu manter as regras 1 e 2: o app não guarda senha. Para entrar mais rápido, usar o preenchimento automático do Android na página oficial.

## 2026-11-10: aviso de faltas
Limite fixo: pode ter até 16 faltas em cada disciplina, e a 17ª reprova (decisão final de Arthur). O app não lê mais a página de cada turma. O aviso começa em 12 (75% das 16 permitidas) e fica vermelho a partir da 17ª. A próxima aula é ligada à disciplina pelo nome.

## 2026-11-10: ônibus fora do escopo
Arthur desistiu da integração com ônibus (não há dados públicos de posição ou horário em Rio Branco).

## 2026-11-10: nome UFAC+
O nome que aparece no celular passou a ser "UFAC+". O identificador interno (`io.github.ufacnobolso.ufac_no_bolso`), a pasta do projeto e o repositório continuam iguais, porque mudar o identificador impediria as atualizações por cima. O aviso de app independente, não oficial, continua na tela de boas-vindas e no Sobre.

## 2026-11-10: ícone neutro (capelo)
Arthur escolheu, entre sete opções, o capelo de formatura branco com borla âmbar sobre o mesmo azul (opção E). O ícone é um só para alunos e professores e não muda de cor. O desenho fica em `tools/gerar_icone.dart`; as opções descartadas, em `tools/gerar_icone_opcoes.dart` e `docs/prints/icone/`.

## 2026-11-10: perfil aluno ou professor
Um app só, com perfil escolhido na tela de boas-vindas ("Sou aluno" ou "Sou professor") e guardado no armazenamento seguro. Quem já usava o app é aluno. O perfil escolhe a paleta: alunos em azul, professores em vermelho (`AppCores.professorClaro` e `professorEscuro`). Na paleta dos professores, "perigo" vira laranja para não se confundir com a cor do app. Todos os pares de texto e fundo ficaram acima de 4,5 (AA). O ícone é o mesmo para todos.
Enquanto o Portal do Professor não é lido (etapa 6), "Sou professor" mostra só uma prévia em vermelho e não guarda o perfil.
Prints dos temas: `flutter test test/visual_test.dart --update-goldens --tags visual` (saem em `test/goldens/`).

## 2026-11-10: v0.1.7 e Classroom sem cliente Web
- Arthur aprovou as cores dos dois perfis. A 0.1.7 leva o ícone do capelo e a escolha de perfil.
- Classroom: o `authenticate()` do google_sign_in 7 exige um cliente Web no Android (`serverClientId`). O projeto só tem cliente Android, então o plano é usar só a autorização de escopos (AuthorizationClient), que não precisa dele. A confirmar no celular.- Testado no celular (0.1.8 de teste): sem cliente Web funcionou e leu as turmas. O primeiro bloqueio ("não concluiu o processo de verificação") era só a conta fora de Usuários de teste. Cada pessoa precisa estar nessa lista (até 100). Sair revoga pelo endereço de revogação do Google, porque o disconnect() da biblioteca não tem conta para revogar nesse caminho.
## 2026-11-10: aviso diário do Classroom
- Às 19h (`horaAvisoClassroom` em config.dart), só nos dias com algo pendente até o fim do dia seguinte. Agendado pelo próprio app a partir da última leitura, para os próximos 7 dias, e refeito a cada leitura. Sem workmanager e sem leitura do Google em segundo plano: a autorização silenciosa precisa do app aberto, e assim nada roda escondido. Desvantagem: sem abrir o app por dias, o aviso pode citar algo já entregue.
- Modo inexato (sem permissão de alarme exato). Conteúdo privado na tela bloqueada. Chave "Avisar sobre atividades" nas Configurações, ligada por padrão.
- flutter_local_notifications 23 exige compileSdk 37 (já instalado no PC). minSdk 24 e targetSdk 36 não mudaram.
## 2026-11-11: perfil do professor, escopo e lançamentos
- **Fontes:** o perfil do professor usa só o Portal do Professor, o eTICKET e o Google Classroom. Fica de fora tudo que não está nesses três sistemas (SouGov, salas, mapa, IA, carteirinha, chat).
- **Notas e faltas pelo app:** tela nativa no app. Ao confirmar, a WebView escondida abre a página oficial de lançamento com a sessão do professor, preenche o mesmo formulário e envia. É o mesmo pedido que o site faria. Nada passa por servidor do app ou de terceiros, e nada fica guardado além do que o portal já guarda.
- **Proteções obrigatórias:** tela de revisão antes de enviar; envio só com toque do professor, nunca automático nem repetido sozinho; depois de enviar, o app lê a página de novo e confere se o portal gravou cada valor; se algo não bater, mostra qual aluno e manda conferir no site.
- Notas e listas de alunos são lidas na hora e não vão para o cache.
- Antes de codar: ver com o professor, com a máscara e sem enviar nada, o quadro de notas e a tela de chamada.

## 2026-11-11: perfil do professor, primeira versão (só leitura)
- "Sou professor" agora entra de verdade: login em duas etapas (Portal do Professor e eTICKET) e o perfil fica guardado. A prévia vermelha saiu.
- Abas do professor: Início (próxima aula, Pendências, saldo, refeição), Horários (todas as turmas), Turmas (cartão por turma e detalhe), Relatórios e RU.
- Pendências: aulas do mês já passadas e sem chamada (da Agenda) e lançamento de notas aberto (de "Minhas turmas" das Notas).
- Lançar chamada e notas, por enquanto, abre a página oficial dentro do app. A tela nativa vem depois, com revisão e conferência.
- Nada de aluno é lido nesta versão: só turmas, horários, totais e situações.
- Os nomes dos relatórios do professor vêm dos endereços, porque na página eles são só ícones. Conferir com o professor.
- O Classroom continua só para aluno: para professor seriam outras consultas e outro escopo.
- A página de login do professor quando a sessão cai não foi vista. A regra trata qualquer endereço do portal com "login" como login.
- Testado em 2026-11-11 no celular do Arthur, com um professor voluntário: login nas duas etapas, Início, Horários, Turmas e Relatórios conferidos com o portal. Sem travamentos.

## 2026-11-11: chamada nativa
- Tela no app: a lista da turma, com todos começando presentes (ou como já está no portal). Tocar no nome marca falta na aula toda; tocar em P1, P2… marca só aquela hora-aula. Falta justificada (`ad`) aparece, mas não se altera.
- Revisão antes de enviar: turma, dia, horas-aula, quantos presentes e quem fica com falta.
- Envio: a WebView escondida abre a página oficial da chamada, clica em cada célula pelo próprio tratador da página (assim o portal registra o período como modificado) e aperta o Salvar do site. O site valida e monta os campos como faria com o professor.
- Se alguma célula não chegar ao estado pedido, nada é enviado. Depois do Salvar, o app lê a chamada de novo e confere aluno por aluno. Sem resposta ou sem conferência, ele diz isso e manda abrir no portal, nunca afirma que deu certo.
- O script de marcação só leva números (ids e períodos). Nomes de aluno ficam na memória da tela e não vão para o cache nem para o log.
- 2026-11-11, primeiro teste com o professor: "não consegui marcar todos", e nada foi enviado (a aula continuou em branco no portal). Causa provável: na WebView escondida, sem tamanho de tela, o clique da página falha e o script inteiro parava. Correção: a WebView ganha tamanho de celular, cada toque é protegido e, se o clique falhar, o app chama a função de troca da própria página e registra o período. Se ainda falhar, a mensagem traz um detalhe técnico (só números e o erro). O script novo foi testado no Chrome, numa chamada real e sem salvar: 104 células, 0 erros, 4 períodos registrados.
- Design refeito depois da crítica do Arthur:
  - Início: cartão "Chamadas pendentes" com o botão "Fazer chamada" em cada aula.
  - Turma: botão principal "Fazer chamada" (abre direto ou deixa escolher a aula) e botões explícitos na lista de aulas.
  - Chamada: passos no topo, botões "Presente | Faltou" por aluno, "por hora-aula" escondido atrás de uma chave, e barra fixa embaixo com o resumo e "Revisar e lançar".

## 2026-11-11: chamada pela página oficial (a nativa saiu)
- Depois de dois testes com o professor, Arthur decidiu: a chamada é feita na página oficial do portal, aberta dentro do app já na aula certa. A tela nativa, o envio pela WebView escondida e a conferência foram retirados do código. O que se aprendeu sobre a página continua em docs/reconhecimento.md.
- Motivos: a interface nativa ficou confusa e o envio falhou nos testes reais ("não consegui marcar todos", nos dois casos sem enviar nada). A página oficial é a que o professor já conhece.
- O app continua mostrando as aulas sem chamada (Início e Turma), com um botão "Fazer chamada" em cada uma. Ele abre a página da aula com uma instrução curta no topo e, ao voltar, relê as pendências.
- Notas seguem o mesmo caminho: "Lançar notas" abre o quadro oficial, com o aviso de não usar "Encerrar" antes da hora.
- Testado com o professor em 2026-11-11: a chamada pela página oficial funcionou e a aula saiu das pendências ao voltar.

## 2026-11-13: login automático no Android (muda a regra 2)
- Pedido do Arthur: parar de fazer login no Portal toda hora, como acontece na versão de iPhone do amigo. No vídeo, a versão de iPhone é um site (`ufac-plus-ios.pages.dev`, Cloudflare Pages) com formulário próprio: CPF e senha são digitados no site dele, não na página da Ufac. Esse modelo quebra as regras 1 a 3 e não foi copiado.
- Escolha do Arthur entre três opções: senha guardada no celular. Como funciona:
  - Na tela de login, a chave "Entrar sozinho quando a sessão cair" vem ligada. Quando a pessoa aperta Entrar na página oficial, a página avisa o app (`loginDigitado`) e, se o login der certo, o CPF e a senha vão para o cofre (`lib/session/credenciais.dart`).
  - Quando uma leitura escondida cai na página de login, o app preenche o formulário oficial (portal: `j_username`/`j_password`; eTICKET: `cpf`/`password`), aperta Entrar e volta para a página pedida.
- Limites:
  - Uma tentativa por leitura. Se voltar para o login, marca a senha como recusada e para de tentar até um novo login à mão.
  - Com CAPTCHA, não preenche nada (regra 1).
  - Os valores entram no script como texto JSON.
  - Nada vai para log.
  - "Sair" (que apaga o cofre inteiro) e "Esquecer senha salva", nas Configurações, removem tudo.
- O selo da tela de login muda conforme a chave: "a senha fica cifrada só neste celular" ou "sua senha não passa pelo app".

## 2026-11-14: um repositório só, público, na organização ufac-plus
- `ufac-plus/ufac-plus` (público) junta tudo: Releases, Issues, site do GitHub Pages, `android/`, `iphone/`, `docs/` e `CLAUDE.md`. Arthur e Matheus são donos da organização.
- O código do Android entrou como uma foto atual, num commit só. O histórico privado fica arquivado em `ufac-plus/ufac-plus-antigo`, porque pode ter dados antigos.
- Os APKs já instalados procuram atualização no endereço antigo (`arthurleticiaclaude/ufac-no-bolso`). O GitHub redireciona pelo número interno do repositório, por isso esse nome nunca pode ser recriado. Da 0.1.11 em diante, o app usa `ufac-plus/ufac-plus`.
- Releases: `UFAC+ Android 0.1.x` (tag `v0.1.x`, sempre a Latest, com o `.apk`) e `UFAC+ iPhone 1.x` (tag `iphone-v1.x`, sempre `--latest=false`).
- O site (`ufac-plus.github.io/ufac-plus`) mostra primeiro a versão do celular de quem abre (Android ou iPhone).
- Commits no repositório público usam o e-mail anônimo do GitHub (`…@users.noreply.github.com`).

## 2026-11-14: professor em âmbar, telas do professor reorganizadas e aba Biblioteca
- **Cor do professor:** o vermelho deu lugar ao âmbar da Ufac (`#F2A516` claro, `#F5B23A` escuro), o mesmo do botão Mostrar QR do aluno. Sobre o âmbar o texto é escuro (`#1A1300`); o botão de destaque, que no aluno é âmbar, vira escuro no professor para não sumir no cartão; os botões de texto e as chaves do Material usam o tom escuro da aba ativa (`#8A5300`), porque âmbar sobre branco não passa no AA. O vermelho volta a ser só "perigo". Contraste conferido em `test/contraste_test.dart` (as quatro paletas).
- **Telas do professor:** cartão com Turmas, Alunos e Semestre; "Próxima aula" com a turma separada; "Para fazer" junta chamadas pendentes e notas abertas, cada uma com o botão da ação; na turma, números no topo, botões grandes e cada aula do mês com o botão na própria linha. A ação "Fazer chamada" é sempre âmbar.
- **Faixas da Início:** viraram um item só, colado ao cabeçalho. Antes, as faixas escondidas deixavam um vão no topo (no aluno e no professor).
- **Biblioteca (só aluno, decisão de Arthur):** a aba Biblioteca entra no lugar de Relatórios na barra; Relatórios vai para o Menu. A aba pesquisa no acervo, mostra os exemplares (localização e situação), o histórico de empréstimos (salvo no celular, relido ao abrir a aba no máximo a cada 6 horas) e abre Renovação e Reservas na página oficial: quem renova ou reserva é a pessoa, no site. O professor continua com Relatórios na barra.
- **Cardápio no formato novo (issue #1):** desde 12/11/2026 o eTICKET publica um item por linha (com `<br>`), rótulos como "SALADA:" e uma saudação no fim. O Android agora guarda as quebras de linha e separa os itens igual ao app do iPhone: frase com vírgulas ou uma linha por item, rótulo em "Salada: …", sem saudação nem "<3".

## 2026-11-14: conectar só o Portal ou só o eTICKET
- No login em duas etapas, cada etapa tem o botão **Pular** (não dá para pular as duas). Serve para quem só usa o RU, ou não usa o RU.
- O que foi pulado fica guardado no cofre (`sistemas_pulados`) e o app não lê nada daquele sistema: nem ao abrir, nem ao voltar. No lugar dos dados aparece um convite para conectar ("eTICKET não conectado" no cartão do RU; "Portal do Aluno não conectado" na Início).
- Para conectar depois: o próprio botão do cartão, ou **Configurações › Contas da Ufac**. Um login que dá certo naquele sistema desfaz o "pular". "Sair" apaga a escolha.
