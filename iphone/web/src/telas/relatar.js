// Relatar um problema: a pessoa descreve, vê o que vai junto e escolhe por onde mandar. Nada sai sem ela enviar.
import { abrirEmail, abrirWhatsapp, canais, compartilhar, montarRelato, textoTecnico } from '../lib/relato.js';
import { avisar, botaoRedondo, cabecalho, faixa, html, ic, montar } from '../ui/componentes.js';

export default async function relatar(tela, { voltar, parametro, acoes }) {
  const origem = decodeURIComponent(parametro || '');
  const tecnico = await textoTecnico(origem);
  const { email, whatsapp, compartilhar: podeCompartilhar } = canais();
  montar(tela, html`<div class="pilha entra">
    ${cabecalho({ titulo: 'Relatar um problema', sub: 'Vai direto para quem cuida do app', acoes: botaoRedondo('voltar', 'Voltar', 'voltar') })}
    <section class="cartao vidro">
      <div class="campo">
        <label for="descricao">O que aconteceu?</label>
        <textarea id="descricao" class="caixa-texto" rows="5" placeholder="Ex.: toquei em Entrar no Portal, a senha está certa e voltou para a mesma tela."></textarea>
      </div>
      <div class="apoio" style="margin-top:10px">Não escreva sua senha aqui. Se puder, diga o que você tocou e o que apareceu.</div>
    </section>
    <section class="cartao vidro">
      <details>
        <summary class="forte tocavel">O que vai junto (toque para ver)</summary>
        <div class="apoio" style="margin:8px 0">Versão do app, do iOS e os últimos erros. Sem nome, CPF, matrícula, notas, saldo ou senha: números longos viram #.</div>
        <pre class="registro-tecnico">${tecnico}</pre>
      </details>
    </section>
    ${!email && !whatsapp && !podeCompartilhar ? faixa({ icone: 'alerta', titulo: 'Este iPhone não oferece um jeito de enviar daqui.', texto: 'Use "Copiar" e cole numa conversa com quem te passou o app.' }) : ''}
    ${whatsapp ? html`<button class="botao largo tocavel" data-acao="whatsapp">${ic('celular')} Enviar pelo WhatsApp</button>` : ''}
    ${email ? html`<button class="botao largo ${whatsapp ? 'claro' : ''} tocavel" data-acao="email">${ic('megafone')} Enviar por e-mail</button>` : ''}
    ${podeCompartilhar ? html`<button class="botao largo claro tocavel" data-acao="compartilhar">${ic('compartilhar')} Enviar por outro app</button>` : ''}
    <button class="botao largo claro tocavel" data-acao="copiar">${ic('copiar')} Copiar o relato</button>
  </div>`);

  const texto = () => montarRelato(tela.querySelector('#descricao').value, tecnico);
  acoes.voltar = voltar;
  acoes.whatsapp = () => abrirWhatsapp(texto());
  acoes.email = () => abrirEmail(texto());
  acoes.compartilhar = () => compartilhar(texto());
  acoes.copiar = async () => {
    try {
      await navigator.clipboard.writeText(texto());
      avisar('Relato copiado. Cole numa conversa com quem te passou o app.');
    } catch {
      avisar('Não consegui copiar. Tente "Enviar por outro app".');
    }
  };
}
