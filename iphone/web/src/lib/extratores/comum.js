// Base dos extratores. Todos devolvem null quando a página não tem o formato esperado,
// para o app nunca mostrar dado errado.

export const parse = (html) => new DOMParser().parseFromString(html, 'text/html');

export const limpo = (t) => (t ?? '').replace(/\s+/g, ' ').trim();

/** Portal às vezes escreve tudo em maiúsculas: "MARIA DE SOUZA" vira "Maria de Souza". */
export function nomeApresentavel(nome) {
  if (nome !== nome.toUpperCase()) return nome;
  const minusculas = new Set(['de', 'da', 'do', 'das', 'dos', 'e']);
  return nome
    .split(' ')
    .map((p) => {
      const m = p.toLowerCase();
      return minusculas.has(m) || !m ? m : m[0].toUpperCase() + m.slice(1);
    })
    .join(' ');
}

/** "R$ 5.00" (histórico) e "R$ 12,50" (saldo): aceita os dois. */
export function valorEmReais(texto) {
  const m = /R\$\s*([\d.,]+)/.exec(texto ?? '');
  if (!m) return null;
  const bruto = m[1];
  const normal = bruto.includes(',') ? bruto.replace(/\./g, '').replace(',', '.') : bruto;
  const n = Number(normal);
  return Number.isFinite(n) ? n : null;
}

/** Filhos diretos com uma tag (o DOM não tem :scope confiável em todo lugar). */
export const filhos = (el, tag) => [...(el?.children ?? [])].filter((c) => c.localName === tag);
