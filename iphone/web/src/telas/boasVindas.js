import { instalado } from '../lib/push.js';
import { html, ic, montar } from '../ui/componentes.js';

const ehIphone = () => /iPhone|iPad|iPod/.test(navigator.userAgent) || (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);

export default function boasVindas(tela, { ir, acoes }) {
  document.documentElement.dataset.perfil = 'aluno';
  montar(tela, html`
    <div class="boas-vindas pilha entra">
      <img class="marca" src="/icones/icone-192.png" alt="" width="92" height="92">
      <div>
        <h1 class="titulo-app">UFAC+</h1>
        <div class="apoio" style="font-size:16px;margin-top:4px">Portal do Aluno e RU num lugar só, com seu login da Ufac.</div>
      </div>
      ${ehIphone() && !instalado()
        ? html`<a class="faixa tocavel" href="/instalar/">${ic('celular')}<div class="cresce"><div class="titulo">Instale na Tela de Início</div><div>Assim ele abre como app e pode avisar das aulas. Toque para ver como.</div></div></a>`
        : ''}
      <div class="cartao vidro pilha" style="gap:12px">
        <div class="linha">${ic('cadeado')}<div><div class="forte">Sua senha não fica guardada</div><div class="apoio">Ela vai direto para os sites da Ufac só na hora de entrar.</div></div></div>
        <div class="linha">${ic('celular')}<div><div class="forte">Seus dados ficam no seu iPhone</div><div class="apoio">Notas, horários e saldo ficam salvos só aqui.</div></div></div>
      </div>
      <button class="botao largo tocavel" data-acao="aluno">${ic('escola')} Sou aluno</button>
      <button class="botao largo contorno tocavel" data-acao="professor">Sou professor</button>
      <div class="apoio" style="text-align:center">App independente, feito por um aluno. Não é um aplicativo oficial da Ufac. <a href="/privacidade/" style="text-decoration:underline">Privacidade</a></div>
    </div>`);
  acoes.aluno = () => ir('login/aluno');
  acoes.professor = () => ir('login/professor');
}
