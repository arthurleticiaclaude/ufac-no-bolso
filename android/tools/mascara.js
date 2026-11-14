// Leitura mascarada para a Fase 0: mostra a estrutura da página sem os dados reais.
// Só palavras da lista OK aparecem; o resto vira "xxx" e todo dígito vira 0.
(() => {
  const OK = new Set(`a o as os e de da do das dos em no na nos nas por para com sem ou um uma ao à às se que é
  início inicio página inicial portal aluno alunos matrícula matricula relatórios relatorios relatório relatorio horários horarios horário horario
  notas nota calendário calendario acadêmico academico biblioteca comunicações comunicacoes links link externos mais
  atestado comprovante ficha cadastral histórico historico escolar simplificado integralização integralizacao solicitação solicitacao aprovados sie cr
  nome curso período periodo atual semestre ano turma disciplina disciplinas código codigo professor docente sala local dia dias
  segunda terça quarta quinta sexta sábado domingo feira hora início fim frequência frequencia faltas falta média media situação situacao resultado
  aprovado reprovado cursando carga horária horaria créditos creditos crédito credito total turno manhã tarde noite
  recarregar recarga perfil cardápio cardapio sair saldo valor data home qr code código entrada usuário usuario cpf senha email telefone
  café almoço janta jantar voltar pagar pagamento pix boleto cartão confirmar enviar salvar gerar baixar imprimir visualizar ver abrir fechar buscar pesquisar
  feriado feriados recesso letivo letivos férias evento eventos mês janeiro fevereiro março abril maio junho julho agosto setembro outubro novembro dezembro
  notícia notícias últimas ajuda instruções versão bem vindo vinda bem-vindo uso refeição refeições tipo status
  empréstimo empréstimos emprestimo emprestimos renovação renovacao renovações renovar renovado devolução devolucao devolver
  livro livros exemplar exemplares obra obras título titulo autor acervo reserva reservas multa multas pendência pendências
  prazo vencimento vencido atraso meu minha meus minhas espaço aquisição pedido pedidos nenhum nenhuma não há possui você
  biblioteca biblioteca(s) unidade setorial central quantidade limite selecione selecionar todos marcar ação`.split(/\s+/));
  const texto = s => s.replace(/\s+/g, ' ').trim().replace(/\d/g, '0')
    .replace(/\p{L}+/gu, w => OK.has(w.toLowerCase()) ? w : 'x'.repeat(w.length));
  const url = u => { if (u.startsWith('data:')) return 'data:(omitido)';
    const l = u.replace(/;jsessionid=[^?#]*/gi, '').replace(/\d/g, '0');
    return l.length > 110 ? l.slice(0, 110) + '…' : l; };
  const IGNORA = new Set(['SCRIPT', 'STYLE', 'NOSCRIPT', 'HEAD', 'META', 'LINK', 'BR', 'HR']);
  const arvore = (raiz, max = 12000) => {
    let out = '';
    const anda = (el, n) => {
      if (out.length > max || IGNORA.has(el.tagName)) return;
      let l = el.tagName.toLowerCase();
      if (el.id) l += '#' + el.id.replace(/\d/g, '0');
      if (el.classList.length) l += '.' + [...el.classList].slice(0, 3).join('.');
      const a = [];
      for (const at of el.attributes) {
        const k = at.name;
        if (['href', 'src', 'action'].includes(k)) a.push(`${k}=${url(at.value.replace(/,\s*'[^']*'/g, ", 'xxx'"))}`);
        else if (['name', 'type', 'method', 'target'].includes(k)) a.push(`${k}=${at.value.replace(/\d/g, '0')}`);
        else if (['value', 'alt', 'title', 'placeholder'].includes(k) || k.startsWith('data-')) a.push(`${k}=${texto(at.value)}`);
        else if (k === 'onclick' || k === 'onchange') a.push(`${k}=${url(at.value.replace(/,\s*'[^']*'/g, ", 'xxx'"))}`);
      }
      const t = texto([...el.childNodes].filter(c => c.nodeType === 3).map(c => c.nodeValue).join(' '));
      const util = a.length || t || ['TABLE', 'TR', 'FORM', 'CANVAS', 'IFRAME', 'SVG', 'UL', 'LI'].includes(el.tagName);
      if (util) out += '  '.repeat(n) + l + (a.length ? ' [' + a.join(' ') + ']' : '') + (t ? ' "' + t + '"' : '') + '\n';
      for (const c of el.children) anda(c, util ? n + 1 : n);
    };
    anda(raiz, 0);
    return out.length > max ? out.slice(0, max) + '\n…(cortado)' : out;
  };
  const rotas = doc => [...new Set([...doc.querySelectorAll('script:not([src])')]
    .flatMap(s => s.textContent.match(/["'`][^"'`\s]*(\.action|\/api\/|\.json|\/eticket\/)[^"'`\s]*["'`]/g) || []).map(url))];
  // Lê uma página pelo fetch, sem navegar. Nunca toca em sair/logout nem envia nada. PDF: só cabeçalhos.
  const ver = async (u, sel, max) => {
    if (/logout|sair/i.test(u)) return 'bloqueado: sair';
    const c = new AbortController();
    const r = await fetch(u, { credentials: 'same-origin', signal: c.signal });
    const tipo = r.headers.get('content-type') || '';
    const cab = `status=${r.status} tipo=${tipo} final=${url(r.url)} disp=${(r.headers.get('content-disposition') || '').replace(/filename=.*/i, 'filename=(omitido)')}\n`;
    if (!tipo.includes('html')) { c.abort(); return cab; }
    const doc = new DOMParser().parseFromString(await r.text(), 'text/html');
    return cab + 'rotas=' + rotas(doc).join(' ') + '\n' + arvore(sel ? doc.querySelector(sel) || doc.body : doc.body, max);
  };
  const aqui = (sel, max) => 'rotas=' + rotas(document).join(' ') + '\nxhr=' +
    performance.getEntriesByType('resource').filter(e => ['xmlhttprequest', 'fetch'].includes(e.initiatorType)).map(e => url(e.name)).join(' ') +
    '\n' + arvore(sel ? document.querySelector(sel) || document.body : document.body, max);
  window.__m = { texto, url, arvore, rotas, ver, aqui };
  return 'ok';
})()
