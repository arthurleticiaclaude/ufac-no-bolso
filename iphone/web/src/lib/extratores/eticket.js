// Extratores do eTICKET. Porte de lib/extractors/eticket_*.dart.
import { limpo, parse, valorEmReais } from './comum.js';

/** Saldo e número do QR da página inicial logada. */
export function lerEticketInicio(pagina) {
  const doc = parse(pagina);
  const titulo = [...doc.querySelectorAll('h2')].find((e) => e.textContent.includes('Saldo'));
  const valor = titulo ? /R\$\s*([\d.,]+)/.exec(titulo.textContent)?.[1] : null;
  const saldo = valor == null ? null : Number(valor.replace(/\./g, '').replace(',', '.'));
  const numero = doc.querySelector('img[alt="QR Code"]')?.parentElement?.querySelector('p')?.textContent.trim();
  if (saldo == null || !Number.isFinite(saldo) || !numero || !/^\d{6,}$/.test(numero)) return null;
  return { saldo, numeroQr: numero };
}

function refeicaoDoTitulo(titulo) {
  const t = titulo.toLowerCase();
  if (t.includes('café') || t.includes('cafe')) return 'cafe';
  if (t.includes('almoço') || t.includes('almoco')) return 'almoco';
  if (t.includes('jant')) return 'jantar';
  return null;
}

/** textContent, mas com <br> virando quebra de linha (o eTICKET passou a publicar um item por linha). */
function textoComQuebras(el) {
  const copia = el.cloneNode(true);
  copia.querySelectorAll('br').forEach((br) => br.replaceWith('\n'));
  return copia.textContent.trim();
}

/** Texto da refeição: `div.cardapio` (página logada) ou `input.meal-description` (página pública). */
function textoDaRefeicao(titulo) {
  // Percorre o que vem depois do título, em ordem, até o próximo título (aceita elementos aninhados).
  const doc = titulo.ownerDocument;
  const andar = doc.createTreeWalker(doc.body, 1);
  andar.currentNode = titulo;
  for (let el = andar.nextNode(); el; el = andar.nextNode()) {
    if (el.classList.contains('meal-title')) return null;
    if (titulo.contains(el)) continue;
    if (el.classList.contains('cardapio')) return textoComQuebras(el);
    if (el.classList.contains('meal-description')) return (el.getAttribute('value') ?? el.textContent ?? '').trim();
  }
  return null;
}

/**
 * Página /eticket/menu/ (logada) ou /eticket/menuExterno/ (pública).
 * A ordem das refeições muda, então o nome é o que vale. Null se nenhuma refeição tiver texto de verdade
 * (a página pública diz "Indisponível" nas três mesmo quando a logada já tem o cardápio).
 */
export function lerEticketCardapio(pagina) {
  const textos = {};
  for (const titulo of parse(pagina).querySelectorAll('.meal-title')) {
    const refeicao = refeicaoDoTitulo(titulo.textContent);
    const texto = refeicao ? textoDaRefeicao(titulo) : null;
    if (texto != null) textos[refeicao] = texto;
  }
  const algumDeVerdade = Object.values(textos).some((t) => !/^indispon[ií]vel$/i.test(t.trim()));
  return Object.keys(textos).length && algumDeVerdade ? textos : null;
}

/** Null se a página não for o histórico. Lista vazia é quem nunca usou o RU. */
export function lerHistoricoRefeicoes(pagina) {
  const doc = parse(pagina);
  const tabela = doc.querySelector('#historico-table');
  if (!tabela) return doc.querySelector('h1')?.textContent.includes('Refeições') ? [] : null;
  return [...tabela.querySelectorAll('tbody tr')]
    .filter((l) => l.children.length >= 6)
    .map((l) => {
      const c = [...l.children].map((td) => limpo(td.textContent));
      return { data: c[0], hora: c[1], refeicao: c[2], prato: c[3], valor: valorEmReais(c[4]), status: c[5] };
    });
}

/** Null se a página não for o histórico de crédito. */
export function lerHistoricoRecargas(pagina) {
  const doc = parse(pagina);
  if (![...doc.querySelectorAll('h1')].some((h) => h.textContent.includes('Crédito'))) return null;
  const registros = [];
  for (const linha of doc.querySelectorAll('table tr')) {
    const textos = [...linha.querySelectorAll('h6')].map((h) => limpo(h.textContent));
    if (!textos.length) continue;
    const depoisDe = (rotulo) => {
      const achado = textos.find((t) => t.includes(rotulo));
      return achado ? achado.slice(achado.indexOf(rotulo) + rotulo.length).trim() : '';
    };
    registros.push({
      valor: valorEmReais(textos[0]),
      forma: depoisDe('Pagamento:'),
      data: depoisDe('Data:'),
      hora: depoisDe('Hora:'),
      situacao: depoisDe('Situação:'),
    });
  }
  return registros;
}

/** O token do formulário de login do eTICKET (Django). */
export const lerTokenLoginEticket = (pagina) =>
  parse(pagina).querySelector('input[name="csrfmiddlewaretoken"]')?.getAttribute('value') ?? null;
