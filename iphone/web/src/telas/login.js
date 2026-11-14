import { apagar, ler } from '../lib/armazenamento.js';
import { SemConexao } from '../lib/api.js';
import { ErroLogin, ErroTrocarSenha, concluirSemEticket, entrar } from '../lib/sessao.js';
import { definirLigado, ligado as loginAutomaticoLigado } from '../lib/credenciais.js';
import { registrar } from '../lib/registro.js';
import { cpfFormatado } from '../lib/regras.js';
import { aplicarAparencia } from '../main.js';
import { botaoRedondo, cabecalho, confirmar, faixa, html, ic, montar } from '../ui/componentes.js';

// Portal e eTICKET são servidores diferentes e podem ter senhas diferentes. Por isso o login tem
// uma etapa (e um formulário) para cada um. O Chaves do iCloud guarda por (site, usuário): com o
// mesmo CPF nos dois, a segunda senha sobrescreveria a primeira. O usuário salvo leva então o nome
// do sistema ("123.456.789-00 · eTICKET"), e cada senha vira um item separado no Chaves.
const SISTEMAS = {
  portal: {
    nome: 'Portal do Aluno',
    rotuloChaves: 'Portal do Aluno',
    site: 'portal.ufac.br',
    icone: 'escola',
    campo: 'Senha do Portal do Aluno',
    texto: 'A senha que você usa no Portal do Aluno.',
    botao: 'Entrar no Portal',
  },
  professor: {
    nome: 'Portal do Professor',
    rotuloChaves: 'Portal do Professor',
    site: 'portal.ufac.br',
    icone: 'escola',
    campo: 'Senha do Portal do Professor',
    texto: 'A senha que você usa no Portal do Professor.',
    botao: 'Entrar no Portal',
  },
  eticket: {
    nome: 'eTICKET do RU',
    rotuloChaves: 'eTICKET',
    site: 'sistemas.ufac.br/eticket',
    icone: 'ru',
    campo: 'Senha do eTICKET (ID Ufac)',
    texto: 'A senha do ID Ufac que você usa no eTICKET do RU. Pode ser diferente da do Portal.',
    botao: 'Entrar no eTICKET',
  },
};

const soDigitos = (v) => v.replace(/\D/g, '').slice(0, 11);
const mascararCpf = (d) => d.replace(/(\d{3})(\d)/, '$1.$2').replace(/(\d{3})(\d)/, '$1.$2').replace(/(\d{3})(\d{1,2})$/, '$1-$2');

// parametro: 'aluno' | 'professor' (primeiro login) ou 'portal' | 'eticket' (entrar de novo).
export default async function login(tela, { parametro, ir, voltar, acoes }) {
  const relogin = parametro === 'portal' || parametro === 'eticket';
  const perfil = relogin ? ((await ler('perfil')) ?? 'aluno') : parametro === 'professor' ? 'professor' : 'aluno';
  document.documentElement.dataset.perfil = perfil;
  const portal = perfil === 'professor' ? 'professor' : 'portal';
  const etapas = relogin ? [parametro === 'portal' ? portal : 'eticket'] : perfil === 'professor' ? ['professor'] : ['portal', 'eticket'];
  let indice = 0;
  let cpf = ''; // só dígitos, só na memória durante o login
  let lembrar = await loginAutomaticoLigado(); // chave Entrar sozinho quando a sessão cair
  // Voltar na etapa 2 volta para a etapa 1, sem abandonar o login pela metade.
  acoes.voltar = async () => {
    if (indice === 0) return voltar();
    indice--;
    await apagar('sessao'); // refaz o Portal de verdade, com a senha que for digitada agora
    desenhar();
  };
  // Primeiro login começa do zero: sem isso, uma sessão do Portal que sobrou de um login abandonado
  // aceitaria qualquer senha (e o Safari ofereceria salvar a senha errada no Chaves).
  if (!relogin) await apagar('sessao');

  // Quem ainda não tem acesso ao eTICKET (ou não consegue entrar nele) segue só com o Portal, que continua
  // obrigatório. A etapa 1 já foi feita quando este botão aparece.
  let enviando = false; // um login em andamento não pode correr junto com o "Continuar sem"
  acoes['pular-eticket'] = async () => {
    if (enviando) return;
    const ok = await confirmar({
      titulo: 'Continuar sem o eTICKET?',
      texto: 'Você usa o Portal e o cardápio do RU normalmente. Saldo, QR de entrada e histórico ficam para quando conectar o eTICKET, o que dá para fazer depois em qualquer aba.',
      sim: 'Continuar sem o eTICKET',
    });
    // A folha pode ter ficado aberta enquanto o login terminava e o app já foi para a Início.
    if (!ok || enviando || !location.hash.startsWith('#/login')) return;
    cpf = '';
    await concluirSemEticket();
    await aplicarAparencia();
    ir('inicio', { substituir: true });
  };

  // Só na etapa do eTICKET do primeiro login (o Portal já entrou). No "Conectar" das abas, voltar basta.
  const podePular = () => !relogin && etapas[indice] === 'eticket';

  function indicador() {
    if (etapas.length < 2) return '';
    return html`<ol class="etapas" aria-label="Etapas do login">
      ${etapas.map((e, i) => html`<li class="${i < indice ? 'feita' : i === indice ? 'atual' : ''}" ${i === indice ? html`aria-current="step"` : ''}>
        <span class="num">${i < indice ? ic('check') : String(i + 1)}</span>${SISTEMAS[e].nome}</li>`)}
    </ol>`;
  }

  function desenhar() {
    const sistema = etapas[indice];
    const s = SISTEMAS[sistema];
    const segunda = indice > 0;
    montar(tela, html`
      <div class="pilha entra">
        ${cabecalho({ titulo: 'Entrar', sub: etapas.length > 1 ? `Etapa ${indice + 1} de ${etapas.length}` : s.nome, acoes: botaoRedondo('voltar', 'Voltar', 'voltar') })}
        ${indicador()}
        <section class="cartao vidro etapa-login" data-sistema="${sistema}">
          <div class="etapa-topo">
            <span class="etapa-icone">${ic(s.icone)}</span>
            <div class="cresce">
              <div class="etapa-site">${s.site}</div>
              <h2>${s.nome}</h2>
            </div>
          </div>
          ${segunda ? faixa({ icone: 'alerta', titulo: 'Agora é outra senha', texto: 'O eTICKET é outro sistema da Ufac. Use a senha do ID Ufac, mesmo que seja diferente da do Portal.' }) : ''}
          <p class="apoio" style="margin:0">${s.texto}</p>
          <form class="pilha" id="form-${sistema}" method="post" action="/entrar/${sistema}" autocomplete="on" novalidate>
            <div class="campo" ${segunda ? html`hidden` : ''}>
              <label for="cpf">CPF</label>
              <input id="cpf" name="cpf" inputmode="numeric" autocomplete="off" placeholder="000.000.000-00" maxlength="14" value="${mascararCpf(cpf)}">
            </div>
            <div class="conta-chaves" ${cpf ? '' : html`data-vazio`}>
              <span class="apoio">Salvo no Chaves como</span>
              <input id="conta" class="selo-conta" name="username" type="text" autocomplete="username" tabindex="-1" aria-label="Conta salva no Chaves do iCloud" value="${cpf ? `${cpfFormatado(cpf)} · ${s.rotuloChaves}` : ''}">
            </div>
            <div class="campo">
              <label for="senha">${s.campo}</label>
              <input id="senha" name="password" type="password" autocomplete="current-password" required>
            </div>
            <label class="item lembrar" style="cursor:pointer;padding:4px 0">
              <span class="cresce"><span class="titulo">Entrar sozinho quando a sessão cair</span>
                <span class="apoio" style="display:block">Guarda o CPF e a senha cifrados só neste iPhone, para o app entrar de novo sem pedir login.</span></span>
              <input type="checkbox" class="interruptor" id="lembrar" aria-label="Entrar sozinho quando a sessão cair" ${lembrar ? html`checked` : ''}>
            </label>
            <div id="erro" aria-live="polite"></div>
            <button class="botao largo tocavel" id="entrar" type="submit">${s.botao}</button>
          </form>
        </section>
        <div class="apoio" style="text-align:center">O Chaves do iCloud guarda as duas senhas separadas, com o nome de cada sistema. Com "Entrar sozinho" ligado, o UFAC+ também guarda, cifradas e só neste iPhone; elas só vão para a Ufac.</div>
        ${podePular() ? html`<section class="cartao vidro pular-eticket">
          <div class="forte">Ainda não tem acesso ao eTICKET?</div>
          <div class="apoio">Entre só com o Portal e conecte o eTICKET depois.</div>
          <button class="botao largo claro tocavel" style="margin-top:10px" data-acao="pular-eticket">Continuar sem o eTICKET</button>
        </section>` : ''}
        <button class="botao largo claro tocavel" data-acao="relatar">${ic('info')} Problemas para entrar? Relatar</button>
      </div>`);
    ligar(sistema);
    if (segunda) tela.querySelector('#senha').focus();
  }

  function ligar(sistema) {
    const s = SISTEMAS[sistema];
    const campoCpf = tela.querySelector('#cpf');
    tela.querySelector('#lembrar').addEventListener('change', async (e) => {
      lembrar = e.target.checked;
      await definirLigado(lembrar); // desligar apaga na hora o que estava guardado
    });
    const conta = tela.querySelector('#conta');
    const caixaConta = tela.querySelector('.conta-chaves');
    const rotular = () => {
      conta.value = cpf.length === 11 ? `${cpfFormatado(cpf)} · ${s.rotuloChaves}` : '';
      caixaConta.toggleAttribute('data-vazio', !conta.value);
    };
    campoCpf.addEventListener('input', () => {
      cpf = soDigitos(campoCpf.value);
      campoCpf.value = mascararCpf(cpf);
      rotular();
    });
    // Quando o Chaves preenche o item escolhido, o CPF vem dentro do rótulo.
    conta.addEventListener('input', () => {
      const d = soDigitos(conta.value);
      if (d.length === 11 && indice > 0 && d !== cpf) {
        // Etapa 2: o eTICKET tem de ser da mesma pessoa do Portal. Item do Chaves de outro CPF não troca nada.
        montar(tela.querySelector('#erro'), faixa({ icone: 'alerta', titulo: 'Esse item do Chaves é de outro CPF.', texto: 'Escolha o item com o seu CPF e "eTICKET".', tipo: 'perigo' }));
        tela.querySelector('#senha').value = '';
      } else if (d.length === 11) {
        cpf = d;
        campoCpf.value = mascararCpf(cpf);
      }
      rotular();
    });

    tela.querySelector('form').addEventListener('submit', async (e) => {
      e.preventDefault();
      const senha = tela.querySelector('#senha');
      const botao = tela.querySelector('#entrar');
      const erro = tela.querySelector('#erro');
      montar(erro, '');
      if (cpf.length !== 11 || !senha.value) {
        montar(erro, faixa({ icone: 'alerta', titulo: cpf.length !== 11 ? 'Preencha o CPF (11 números).' : `Digite a ${s.campo[0].toLowerCase()}${s.campo.slice(1)}.`, tipo: 'perigo' }));
        return;
      }
      botao.disabled = true;
      botao.textContent = 'Entrando…';
      enviando = true;
      const ultima = indice === etapas.length - 1;
      try {
        await entrar(perfil, cpf, senha.value, { etapa: sistema === 'professor' ? 'portal' : sistema, concluir: ultima, lembrar });
        // Não limpar a senha antes de tirar o formulário da tela: o Safari usa isso para oferecer salvar.
        if (!ultima) {
          enviando = false;
          indice++;
          desenhar();
          return;
        }
        cpf = '';
        await aplicarAparencia();
        ir('inicio', { substituir: true });
      } catch (falha) {
        enviando = false;
        const texto = falha instanceof ErroLogin ? falha.message : falha instanceof SemConexao ? 'Sem conexão com a Ufac agora. Confira a internet e tente de novo.' : 'Algo deu errado ao entrar. Tente de novo.';
        if (!(falha instanceof ErroLogin) && !(falha instanceof SemConexao)) registrar('app', { erro: falha?.message ?? String(falha), onde: 'login', sistema });
        // Senha certa e mesmo assim não entra: o relato leva onde o login parou.
        montar(
          erro,
          falha instanceof ErroTrocarSenha
            ? faixa({ icone: 'cadeado', titulo: texto, texto: 'Sua senha está certa, mas venceu. Troque no site da Ufac e depois entre aqui com a senha nova.', acao: 'trocar-senha-portal', rotuloAcao: 'Abrir o site' })
            : podePular()
              ? faixa({ icone: 'alerta', titulo: texto, texto: 'Sem acesso ao eTICKET agora? Dá para entrar só com o Portal e conectar depois.', tipo: 'perigo', acao: 'pular-eticket', rotuloAcao: 'Continuar sem' })
              : faixa({ icone: 'alerta', titulo: texto, texto: 'Se a senha está certa e o erro continua, relate.', tipo: 'perigo', acao: 'relatar', rotuloAcao: 'Relatar' }),
        );
        botao.disabled = false;
        botao.textContent = s.botao;
      }
    });
  }

  desenhar();
}
