import { ler } from '../lib/armazenamento.js';
import { oficial, URL_PORTAL_ALUNO, URL_PORTAL_PROFESSOR } from '../lib/config.js';
import { sair } from '../lib/sessao.js';
import { botaoRedondo, cabecalho, confirmar, html, ic, montar } from '../ui/componentes.js';

const atalho = (icone, nome, href) =>
  href ? html`<a class="cartao vidro tocavel" style="display:flex;flex-direction:column;gap:10px" href="${href}" target="_blank" rel="noopener"><span class="item" style="padding:0;min-height:0"><span class="icone">${ic(icone)}</span></span><span class="forte">${nome}</span></a>` : '';

export default async function menu(tela, { voltar, ir, perfil, acoes }) {
  const id = await ler('idInterno');
  const comunicacoes = await ler('urlComunicacoes');
  const professor = perfil === 'professor';
  montar(tela, html`<div class="pilha entra">
    ${cabecalho({ titulo: 'Menu', acoes: botaoRedondo('fechar', 'Fechar', 'voltar') })}
    <div class="rotulo apoio" style="font-weight:600">${professor ? 'Portal do Professor' : 'Portal do Aluno'} · abre no Safari</div>
    <div style="display:grid;grid-template-columns:1fr 1fr;gap:12px">
      ${!professor && id ? atalho('calendario', 'Matrícula', oficial.matricula(id)) : ''}
      ${!professor && id ? atalho('livro', 'Biblioteca', oficial.biblioteca(id)) : ''}
      ${comunicacoes ? atalho('megafone', 'Comunicações', comunicacoes) : ''}
      ${atalho('globo', 'Abrir site completo', professor ? URL_PORTAL_PROFESSOR : URL_PORTAL_ALUNO)}
    </div>
    <div class="apoio">No Safari, a Ufac pede o login de novo: a sessão do app fica só dentro do app.</div>
    <button class="cartao vidro item tocavel" data-acao="config"><span class="icone">${ic('engrenagem')}</span><span class="cresce titulo">Configurações</span><span class="seta">${ic('seta')}</span></button>
    <button class="botao perigo largo tocavel" data-acao="sair">${ic('sair')} Sair</button>
  </div>`);
  acoes.voltar = voltar;
  acoes.config = () => ir('configuracoes');
  acoes.sair = async () => {
    const ok = await confirmar({ titulo: 'Sair da conta?', texto: 'Apaga a sessão, os dados salvos, o QR do RU e a foto deste iPhone.', sim: 'Sair', perigo: true });
    if (!ok) return;
    await sair();
    ir('boas-vindas', { substituir: true });
  };
}
