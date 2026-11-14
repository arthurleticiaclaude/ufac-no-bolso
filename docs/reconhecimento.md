# Fase 0: reconhecimento

Tudo foi visto em 2026-11-04, com uma única conta (Arthur). Legenda: **Confirmado**, **Hipótese**, **Pendente**.

## Respostas às perguntas em aberto
- **Logar num sistema libera o outro?** Não entre Portal e eTICKET: cada um tem formulário próprio em domínio próprio. A etapa 2 do login é necessária, com o mesmo CPF e senha. Dentro do portal, sim: `/relatorios/` abriu com o login de `/aluno/`.
- **Horários e notas vêm em HTML ou JSON?** HTML nos dois casos, parte dele carregado por AJAX. Não vi JSON interno em nenhum sistema.
- **Os PDFs baixam direto?** Sim, os 7. Só "Mais relatórios" passa por um formulário de parâmetros.
- **Tem CAPTCHA?** Não apareceu nas telas de login.
- **Quanto dura a sessão?** **Pendente.** Precisa de um teste com tempo parado.

## Portal do Aluno (`portal.ufac.br`)
Servidor Java (Tomcat), versão V.2.0.202306021048, ASTEN. jQuery 1.6.2.

### Login e sessão
- Formulário `POST /aluno/j_security_check`, campos `j_username` (CPF) e `j_password`.
- Sessão expirada: redireciona para `/aluno/login.action;jsessionid=...?error=`.
- Cookie `JSESSIONID` com `Path=/aluno/`, `HttpOnly`, **sem `Secure`**.
- `JSESSIONIDSSO` com `Path=/` aparece na limpeza de cookies sem login. **Hipótese:** é ele que compartilha o login entre as áreas do portal.
- Os redirecionamentos passam por `http://` antes de voltar para `https://`. O Android bloqueia `http` por padrão, então o login na WebView pode falhar. Testar na etapa 3.
- **Pendente:** aviso de recadastramento (`#dialogRecadastramentoAluno` em `login.js`). Não apareceu nas leituras, mas pode abrir na tela depois do login.

### O identificador interno
- A página inicial tem `input#matricula` com um **número interno de 5 dígitos**, diferente da matrícula de 11 dígitos.
- Todas as páginas abaixo recebem esse número em `?matricula=`. O app lê da página inicial e nunca o fixa no código.

### Mapa de dados
| Dado | Onde | Como ler |
|---|---|---|
| Nome completo | Qualquer página logada | Botão em `#menu` |
| Matrícula, curso, período, semestre | `/aluno/aluno/relatorio/relatorios.action?matricula=` | `table.table-topo`, `span.label` seguido do valor |
| Horários | `/aluno/ajax/aluno/quadrohorario/quadrohorario.action?matricula=` | `#quadrohorario`: 8 colunas (hora + domingo a sábado). Cada aula é `.turmaqh a`, com `title` "Período: ... > Horário: ...", o nome e a turma |
| Local da aula | Não usado | A tabela existe em `/aluno/aluno/turma.action?turma=`, mas Arthur confirmou que nunca vem preenchida |
| Lista de disciplinas | `/aluno/aluno/nota/nota.action?matricula=` | `a.accordionTurma` (semestre) + `table.table-turmas`. Traz todos os semestres (45 disciplinas) |
| Notas e faltas | `/aluno/ajax/aluno/nota/notaturma.action?idCurricAluno=&ano=&periodo=` | `table.nota` + `.divInfo` (Situação, Média Final, Total de Faltas). Uma requisição por disciplina |
| Carga horária | `/aluno/aluno/turma.action?turma=` | Para calcular a frequência na v0.2, junto com o total de faltas |

### Relatórios (todos `application/pdf`, `inline`, sem redirecionar)
Base: `/aluno/aluno/relatorio/` + nome + `.action?matricula=`
- `atestadoMatricula`
- `comprovanteMatricula`
- `fichaCadastral`
- `historicoEscolarSimplificado`
- `integralizacaoCurricular`
- `solicitacaoMatricula`
- `com/historicoEscolarCRAprovados`

"Mais Relatórios": `/relatorios/relatorios.action?...aplicacaoWeb=1`. Lista em sanfona com 2 itens nesta conta, que abrem `/relatorios/relatorioparametros.action?aplicacaosi=&matricula=` (formulário). Melhor abrir na WebView.

### Calendário
- A página é só um Google Agenda embutido, da conta `nurca.ufac@gmail.com`.
- O feed público (`calendar.google.com/calendar/ical/nurca.ufac%40gmail.com/public/basic.ics`) tem 129 eventos, e **o mais recente é de março de 2022**. Nenhum evento em 2026.
- Consequência: não serve como fonte de feriados. Ver "Conflitos" abaixo.

### Outros atalhos
- Matrícula: `/aluno/aluno/matricula/solicitacoes.action?matricula=`
- Biblioteca: `/biblioteca/pesquisa/pesquisar.action?matricula=`
- Comunicações: `/comunicacoes/noticia/list.action?...`
- Links externos: modal aberto por `modalLinksExternos()`. **Pendente:** ver o conteúdo.

## eTICKET (`sistemas.ufac.br/eticket/`)
Django atrás de nginx. HTML puro, sem JSON.

- **Login:** `POST /eticket/login/`, campos `csrfmiddlewaretoken`, `cpf`, `password`. Sessão expirada: `/eticket/login/?next=/eticket/`.
- **Saldo:** `/eticket/`, em `main h2`, formato "Saldo: R$ 12,50".
- **QR:** `/eticket/`, `img[alt="QR Code"]` (PNG em base64), com o número no `<p>` seguinte.
- **O número do QR é igual à matrícula de 11 dígitos** (comparação feita sem expor o valor; diferente do CPF). Falta confirmar em outra conta.
- **Perfil:** `/eticket/perfil/` traz foto, nome, matrícula, CPF, curso.
- **Recarga:** `/eticket/valorPaga/` tem um campo `valor` e envia `POST /eticket/pagamento/`. O histórico mostra PIX. **Não enviei o formulário**, então a tela seguinte não foi vista.
- **Histórico:** `/eticket/historico/` (crédito) e `/eticket/historico/refeicoes/` (`#historico-table`: Data, Hora, Refeição, Prato, Valor, Status). Refeição e prato podem vir vazios.
- **Avisos:** `/eticket/informacao/`, sem avisos no momento.

### Cardápio
| | Público `/eticket/menuExterno/` | Logado `/eticket/menu/` |
|---|---|---|
| Hoje | "Indisponível" nas 3 refeições | Café publicado; almoço e jantar "Não informado" |
| Preço | R$ 9,00 / R$ 15,00 / R$ 15,00 | R$ 1.00 nas 3 (provavelmente preço de aluno) |
| Marcação | `input.meal-description` (`value`) | `div.cardapio` (texto) |
| Nomes | Café Da Manhã, Almoço, Janta | Café da Manhã, Almoço, Jantar |
| Ordem | Café, almoço, janta | Almoço, café, jantar. **Ler pelo nome, não pela posição** |

- Segundo Arthur, o cardápio costuma aparecer no eTICKET pouco antes do horário da refeição. Isso explica o "Não informado" de almoço e jantar à tarde. O "Indisponível" da página pública pode ter a mesma causa, mas o café já estava publicado na logada, e não sei quando a pública atualiza.
- O texto é uma frase única, com itens separados por vírgula: não há campos de bebida, prato principal ou opção vegetariana.
- Não há cardápio da semana, nem data, nem horários das refeições em nenhuma das páginas.
- O RU publica o cardápio completo no Instagram (@ru.informa.ufac), em imagem. Em 04/11/2026 o post já trazia almoço e jantar, enquanto o eTICKET dizia "Não informado". O post avisa "Cardápio sujeito a alterações". O app não lê o Instagram.

## Conflitos com o CLAUDE.md
Resolvidos no próprio CLAUDE.md, com os motivos em `docs/decisoes.md`.

## Ainda falta
- [ ] Duração da sessão nos dois sistemas
- [ ] Login na WebView do celular (saltos `http`, aviso de recadastramento)
- [ ] Tela depois de `POST /eticket/pagamento/`, numa recarga real feita pelo Arthur
- [ ] Almoço e jantar com cardápio publicado
- [ ] Confirmar matrícula = QR em outra conta

## Arquivos
- `fixtures/`: páginas com login, com estrutura real e valores falsos preenchidos à mão. Alguns rótulos ficaram mascarados na leitura e foram deduzidos ("Prato", "Refeições Feitas", "Compra de", "Final"). Conferir no celular antes de um extrator depender deles. Algumas páginas foram resumidas (menos linhas, sem o menu do topo).
- `fixtures/public/`: páginas sem login.
- `tools/mascara.js`: leitura mascarada usada nesta fase.

## Teste no celular (moto g35, 2026-11-04)
- A página de login do portal abre na WebView com os saltos `http` trocados por `https`.
- **Pendente:** login completo nos dois sistemas, preenchimento automático e sessão depois de fechar o app (Arthur vai testar).
- Depois do ajuste, as duas páginas de login vazias foram conferidas no celular: o eTICKET fica no formato de celular, e o portal abre mais perto do formulário. Falta Arthur confirmar digitando.
- Saldo, QR, modo avião e leitura em outro aparelho: Arthur confirmou que tudo bate. Falta passar na catraca do RU.
- O celular está sem serviço de preenchimento automático ativo (`autofill_service` = null), então o Android não oferece senha. O preenchimento dentro do app ainda não foi testado.

## Duração da sessão (PC, 2026-11-04)
- Última requisição por volta das 16h em Rio Branco; teste às 17h.
- **Portal:** caiu em menos de 1 hora parado (redirecionou para `/aluno/login.action`). O limite exato não foi medido. Dentro do PC, um `fetch` nesse redirecionamento falha por causa do salto `http`.
- **eTICKET:** ainda ativo depois de cerca de 1 hora. O limite real não foi medido.

## Biblioteca (2026-11-10)
- Mesmo sistema do Portal (ASTEN), em `portal.ufac.br/biblioteca/`. Entrada: `/biblioteca/pesquisa/pesquisar.action?matricula=` (número interno).
- Menu: Pesquisar Acervo (`/biblioteca/pesquisa/pesquisar.action`, formulário GET para `/biblioteca/pesquisa/resultado.action?keyword=`), Meu Espaço da Biblioteca (`/biblioteca/usuario/index.action`), Renovação (`/biblioteca/usuario/renovacao/emprestimos.action`) e Aquisição (`/biblioteca/usuario/pedidos/solicitar.action`). Há também uma rota de vínculos (`/biblioteca/vinculos/desvincular.action`).
- **Problema:** Meu Espaço e Renovação caem em `/biblioteca/500.action` ("Requisição Incompleta"), inclusive clicando no link do próprio site, logado no Portal. **Pendente:** saber se acontece também no navegador do Arthur, ou se falta vínculo ou um login próprio da Biblioteca.
- **2026-11-11, conta do Arthur no Chrome dele:** o erro 500 sumiu. Meu Espaço (`/biblioteca/usuario/index.action`) abre com 4 blocos que navegam por `window.location`:
  - Reservas: `/biblioteca/usuario/reserva/reservas.action`
  - Renovação: `/biblioteca/usuario/renovacao/emprestimos.action`. Responde e volta para Meu Espaço passando por `http://` (por isso um `fetch` no PC falha). Provável motivo: sem empréstimo ativo.
  - Pedidos: `/biblioteca/usuario/pedidos/meuspedidos.action`
  - Histórico: `/biblioteca/usuario/emprestimo/historico.action`. Abre, com a tabela de empréstimos vazia (0 linhas).
- **Pendente:** ver Renovação e Histórico de alguém com livro emprestado, para conhecer as colunas (título, devolução prevista, renovações) e o botão de renovar. Leitura sempre com a máscara.

## Portal do Professor (2026-11-11)
Leitura mascarada com um professor voluntário, que entrou com o próprio login no Chrome do Arthur. Nada de dado real foi guardado. Nenhuma página que lança ou grava algo foi aberta.

- **Endereço:** `portal.ufac.br/professor/index.action`. Mesmo login (ID Ufac) e mesmo sistema (ASTEN) do Portal do Aluno.
- **Menu** (blocos que navegam por `window.location`):
  - Frequência: `/professor/professor/frequencia/minhasturmas/minhasturmas.action`
  - Notas: `/professor/professor/nota/minhasturmas.action`
  - Programa: `/professor/professor/programa/minhasturmas.action`
  - Relatórios: `/professor/professor/relatorio/relatorios.action`
  - Links: `/professor/professor/links/links.action`
  - Comunicações, Biblioteca e Links externos: os mesmos do aluno.
  - Não há bloco "Horários": o horário fica na página de cada turma.
- **Minhas turmas** (Frequência e Notas): tabela com Período, Disciplina (nome + código), Turma e Situação. Na Frequência, a situação é algo como "Frequência Não …". Nas Notas: "Lançamento Aberto" e uma coluna sobre as avaliações. As páginas abrem por `fetch` normal, sem o desvio por http.
- **Turma** (`/professor/professor/turma.action`, com o id da turma no endereço): vagas e totais de alunos, curso, disciplina, professores da turma, **Horários** (Dia da semana, Hora início, Hora fim, tipo de aula, data de início e fim do período), avaliações com peso (%) e o Programa da Turma. É a fonte para "Minhas turmas" e "Horários" do professor.
- **Só escrita, não abrir no app sem decisão:** `nota/lancamento/quadro.action`, `conceito/lancamento/lancamento.action` (lançar notas) e `frequencia/agenda/agendaturma/agenda.action` (formulário para registrar a aula; mostra também "CH ministrada/prevista").
- **Relatórios do professor** (nomes pelos endereços): quadro de horário, frequência, quadro de frequência, relatório de fechamento, diário de classe, atendimento domiciliar, e "Mais Relatórios" (`/relatorios/relatorios.action`). O diário de classe por turma: `/professor/professor/relatorio/diarioclasseturma.action`.
- **Pendente:** perguntar ao professor o que ele quer no celular; salvar fixtures anonimizadas da lista de turmas e da página da turma (escritas à mão a partir da estrutura mascarada, sem HTML real); ver se os relatórios saem em PDF direto com o cookie.

### Lançamento de notas (2026-11-11, só leitura da estrutura, nada enviado)
- Entrada: `nota/lancamento/quadro.action?turma=<id>` guarda a turma na sessão e redireciona (por `http://`) para `nota/lancamento/lancamento.action`. Às vezes responde 503 na primeira tentativa.
- Formulário único: `POST /professor/professor/nota/lancamento/save.action`, com cerca de 320 campos numa turma de 26 alunos e 2 avaliações. Por aluno (N = posição na lista):
  - `alunoNcheck` (checkbox): escolhe de quem as notas serão salvas. Há "marcar todos" no topo e no rodapé.
  - `idAlunoN`, `idCurricAlunoN`, `totalFaltasAllTurmasN` (ocultos).
  - `notaaluno{N}nota{K}aval{M}` (texto, até 4 caracteres): **o único campo que o professor digita**, um por avaliação.
  - Calculados pelo site, só leitura: `totalnota{K}aluno{N}`, `inputmediaaluno{N}`, `inputexamealuno{N}` e `inputmediafinalaluno{N}`. Há também um botão "simular" por aluno.
  - Ocultos gerais: `turma`, `numHorasAulas`, `permitirLancarTotalFaltas`, `ativarInfoDicenteIndigena`, `ativarInfoDeficienciasDicente`.
- Botões: **Salvar** (`botaoSalvar`) e **Encerrar** (`botaoEncerrar`), um par no topo e outro no rodapé. **O app nunca aciona "Encerrar"**: deve fechar o lançamento de vez.
- Segundo formulário: `configuracao/nota/configuracao/liberar.action` (turma, alunos, retornarPara). Não usar.
- Na turma vista, todas as notas estavam vazias.

### Frequência / agenda (2026-11-11)
- `frequencia/agenda/agendaturma/agenda.action?turma=<id>` ("Agenda da Turma"): calendário montado por script, sem pedidos XHR. Formulários vistos: `copiarPeriodo.action` (copiar período, com "confirmar alteração de tudo") e `substituiraula.action` (data, intervalo, início e fim, tipo de aula, informação do dia, tipo de compromisso).
- **Ainda não vista:** a tela da chamada aluno a aluno. Ela deve abrir a partir de um dia do calendário. Falta o professor mostrar o caminho que ele usa.
- **Lista de aulas da Agenda (só leitura):** por mês, uma linha por aula com dia da semana, horário, "Frequência Lançada" ou "Frequência Não Lançada", e o conteúdo registrado. Serve para o cartão "Pendências" do professor.
- **Chamada de uma aula:** link da linha da Agenda, `frequencia/lancamento/horaaula/horaaula.action?agenda=<id>&indexAba=<n>` ("Lançamento de Frequência").
  - Tabela dentro do formulário, uma linha por aluno: Nome | Situação (ex.: "Matrícula") | Faltas (total) | P1 P2 P3 P4 (uma coluna por hora-aula do dia).
  - Cada célula P é um `div` clicável. O estado está na classe: `aluno-presente-local`, `aluno-ausente-local`, `aluno-branco-local` (não marcado) e `aluno-ad-local` (provável falta justificada). O atributo `aluno` guarda o id do aluno.
  - Script do portal: `/professor/js/professor/frequencia/horaaulatabela.js`. Tem marcar tudo, troca de situação por hora-aula e um aviso quando algum aluno fica em branco.
  - Envio: `POST /professor/professor/frequencia/lancamento/horaaula/save.action` com `agenda`, `turma` e `indexAba`. Ao salvar, `prepareCommand` cria em `#camposFrequencia`, para cada aluno e hora-aula, os campos `horasAula[<aluno>][<período>].periodo` e `horasAula[<aluno>][<período>].presente`, e envia o formulário. Não salva com aluno em branco num período.
  - Botões: Salvar (`.enviar`) e Cancelar (`.cancelar`).
- Nada foi salvo. A aula aberta estava como "Não Lançada" e continua assim.
- **Aulas por mês (Agenda):** montadas por `agenda.js`. Os meses são links `a.mesesAccordion` (atributos `index`, `mes`, `ano` e `anomes` = "AAAA_MM"). O mês corrente abre sozinho. Os outros vêm de `GET /professor/ajax/professor/frequencia/agenda/agendaturma/buscarDadosAccordion.action` com `anoMesToSearchAgendas`, `idTurma`, `indexAba`, `lancamento` e `as`, e a resposta é um trecho de HTML.
  - Cabeçalho: Data | Compromisso | Horários | Situação | Qtd. de Períodos | (ícones) | Conteúdo Ministrado.
  - Linha (`tr.row`): `td.primeira-coluna` "Quarta-feira, dia 12" | "Aula" | "08:00 às 10:00" | "Frequência Lançada"/"Frequência Não Lançada" | nº de períodos | ícones, entre eles o link `horaaula.action?agenda=…&indexAba=…` | `a.add-cont-min` com o conteúdo ou "Sem conteúdo".
  - Na página há também `isPeriodoLancamento` (true/false) e o início e fim do período atual, no elemento `#auxjs_auxiliarAgenda`.
- **Turma:** os dados gerais vêm em pares `span.label` + texto (Curso, Disciplina, Ano, Tipo de Turma, Período, **Carga Horária Realizada**). As vagas ficam em `table.tablevagas` (Vagas Totais, Vagas Ocupadas, Total de Solicitações, Total de Matrículas). Professores: tabela "Nome do Docente | Papel do Docente". Horários: `table.tableborder` com Dia da Semana | Hora Início | Hora Fim | Aula | Data Início Período | Data Fim Período. Modelo de notas: `table.tableNotas`, com `a.linkNota` "Nota 1" e o peso "(50.00%)", e dentro uma `table.tableavaliacao` com Código | Peso | Nome.
- **Nome do professor:** no topo de todas as páginas, em `span.menu-botao > button`.
- **Minhas turmas:** `table#turmasLiberadas.tablesorter`. Período em `strong`; disciplina em `strong` com o código entre parênteses; curso em `span.curso`; situação em `div`; o link da turma (`turma.action?turma=<id>`) leva o nome da turma; o último link vai para a Agenda.
- **Chamada, como o script do portal funciona** (`horaaulatabela.js`, lido em 2026-11-11):
  - Linha do aluno: `a.nome-aluno` (atributos `idaluno` e `idcurricaluno`, com o nome no texto) | situação | `span.total-faltas` | uma célula `div.periodoLocal` por hora-aula, com os atributos `periodo` e `aluno` e o estado na classe.
  - Clique numa célula (`.periodoLocal`, menos `.aluno-ad-local`): alterna presente ⇄ ausente (`trocarSituacaoPeriodoLocal`) e registra o período em `GERENCIAR_PERIODOS_MODIFICADOS`. O cabeçalho de cada período (`periodoGeral`) marca a coluna inteira.
  - Salvar (`.enviar`): `prepareCommand()` monta os campos **só dos períodos modificados**. Ausente e em branco viram `presente=false`; presente e `ad` viram `true`. Se algum aluno ficar em branco num período modificado, aparece um aviso e nada é enviado; se não, `form#horaAulaCommand` é enviado.
  - Por isso, trocar só a classe da célula não basta: o período não entra no envio. O app tem que passar pelo clique da própria página.
  - `<auxjs>` traz `permitealteracao` (true/false) e os títulos "Aluno Presente" e "Aluno Ausente".
