// "Entrar sozinho quando a sessão cair": o app guarda (cifrados, só neste iPhone) o CPF e as senhas
// que a pessoa digitou e refaz o login quando a sessão da Ufac cai. Uma tentativa; senha recusada
// ou CAPTCHA param tudo até a pessoa entrar de novo à mão.
import { beforeEach, describe, expect, test, vi } from 'vitest';

// IndexedDB não existe no Node: o armazenamento vira um Map (o resto do código é o real).
const banco = new Map();
vi.mock('../src/lib/armazenamento.js', () => ({
  ler: async (k) => banco.get(k),
  gravar: async (k, v) => void banco.set(k, v),
  apagar: async (k) => void banco.delete(k),
  apagarTudo: async () => banco.clear(),
}));

const cred = await import('../src/lib/credenciais.js');
const { lerPagina } = await import('../src/lib/api.js');
const { entrar, sair } = await import('../src/lib/sessao.js');
const { baixarRelatorio } = await import('../src/lib/dados.js');

const CPF = '12345678901';
const LOGIN_PORTAL = '<form action="j_security_check"><input name="j_username"><input name="j_password"></form>';
const LOGIN_ETICKET = '<form><input type="hidden" name="csrfmiddlewaretoken" value="TOKEN"><input name="cpf"><input name="password"></form>';

/** Ufac falsa (pelo Worker): o Portal aceita "senha-portal" e o eTICKET "senha-eticket". */
function ufacFalsa({ captcha = false } = {}) {
  const estado = { portal: false, eticket: false, posts: [] };
  const resp = (corpo, final) => new Response(corpo, { status: 200, headers: { 'X-Url-Final': final, 'X-Sessao': 's' } });
  vi.stubGlobal('fetch', async (url, { method = 'GET', body } = {}) => {
    const u = new URL(url);
    if (method === 'POST') estado.posts.push({ caminho: u.pathname, body });
    if (u.pathname.startsWith('/portal')) {
      if (u.pathname.includes('j_security_check')) {
        estado.portal = body.includes('j_password=senha-portal');
        return estado.portal ? resp('<p>inicio</p>', 'https://portal.ufac.br/aluno/index.action') : resp(LOGIN_PORTAL, 'https://portal.ufac.br/aluno/login.action?error=');
      }
      if (!estado.portal) return resp(LOGIN_PORTAL + (captcha ? '<div class="g-recaptcha"></div>' : ''), 'https://portal.ufac.br/aluno/login.action');
      if (u.pathname.includes('/relatorio/')) return new Response('%PDF-1.4', { status: 200, headers: { 'X-Url-Final': `https://portal.ufac.br${u.pathname.slice(7)}`, 'Content-Type': 'application/pdf' } });
      return resp('<p>notas</p>', `https://portal.ufac.br${u.pathname.slice('/portal'.length)}`);
    }
    const e = u.pathname.slice('/eticket'.length);
    if (e === '/login/' && method === 'POST') {
      estado.eticket = body.includes('password=senha-eticket');
      return estado.eticket ? resp('<p>home</p>', 'https://sistemas.ufac.br/eticket/') : resp(LOGIN_ETICKET, 'https://sistemas.ufac.br/eticket/login/');
    }
    if (!estado.eticket) return resp(LOGIN_ETICKET + (captcha ? '<div class="h-captcha"></div>' : ''), 'https://sistemas.ufac.br/eticket/login/?next=/eticket/');
    return resp('<p>menu</p>', `https://sistemas.ufac.br/eticket${e}`);
  });
  return estado;
}

beforeEach(() => {
  banco.clear();
  cred.limparMemoria();
});

describe('cofre das credenciais', () => {
  test('vem ligado por padrão', async () => {
    expect(await cred.ligado()).toBe(true);
  });

  test('devolve o CPF e a senha de cada sistema', async () => {
    await cred.guardar('portal', '123.456.789-01', 'senha-portal');
    await cred.guardar('eticket', CPF, 'senha-eticket');
    expect(await cred.paraLoginAutomatico('portal')).toEqual({ cpf: CPF, senha: 'senha-portal' });
    expect(await cred.paraLoginAutomatico('eticket')).toEqual({ cpf: CPF, senha: 'senha-eticket' });
  });

  test('a senha não fica legível no armazenamento', async () => {
    await cred.guardar('portal', CPF, 'senha-portal');
    const tudo = JSON.stringify([...banco.values()], (_, v) => (v instanceof ArrayBuffer || ArrayBuffer.isView(v) ? [...new Uint8Array(v.buffer ?? v)] : v));
    expect(tudo).not.toContain('senha-portal');
    expect(tudo).not.toContain(CPF);
    // Nem relendo do zero (outra abertura do app), sem a memória.
    cred.limparMemoria();
    expect(await cred.paraLoginAutomatico('portal')).toEqual({ cpf: CPF, senha: 'senha-portal' });
  });

  test('desligar a chave apaga as senhas guardadas', async () => {
    await cred.guardar('portal', CPF, 'senha-portal');
    await cred.definirLigado(false);
    expect(await cred.ligado()).toBe(false);
    expect(await cred.temSalvas()).toBe(false);
    expect(await cred.paraLoginAutomatico('portal')).toBeNull();
  });

  test('com a chave desligada não guarda nada', async () => {
    await cred.definirLigado(false);
    await cred.guardar('portal', CPF, 'senha-portal');
    expect(await cred.temSalvas()).toBe(false);
  });

  test('"Esquecer senha salva" apaga, mas mantém a chave', async () => {
    await cred.guardar('portal', CPF, 'senha-portal');
    await cred.esquecer();
    expect(await cred.temSalvas()).toBe(false);
    expect(await cred.ligado()).toBe(true);
  });

  test('depois de uma recusa, para de tentar até guardar de novo', async () => {
    await cred.guardar('portal', CPF, 'senha-portal');
    await cred.marcarFalha('portal');
    expect(await cred.paraLoginAutomatico('portal')).toBeNull();
    cred.limparMemoria(); // a recusa vale também na próxima abertura do app
    expect(await cred.paraLoginAutomatico('portal')).toBeNull();
    await cred.guardar('portal', CPF, 'senha-portal');
    expect(await cred.paraLoginAutomatico('portal')).not.toBeNull();
  });
});

describe('login à mão', () => {
  test('com "lembrar", guarda a senha de cada etapa', async () => {
    ufacFalsa();
    await entrar('aluno', CPF, 'senha-portal', { etapa: 'portal', concluir: false, lembrar: true });
    await entrar('aluno', CPF, 'senha-eticket', { etapa: 'eticket', lembrar: true });
    expect(await cred.paraLoginAutomatico('portal')).toEqual({ cpf: CPF, senha: 'senha-portal' });
    expect(await cred.paraLoginAutomatico('eticket')).toEqual({ cpf: CPF, senha: 'senha-eticket' });
  });

  test('sem "lembrar", não guarda', async () => {
    ufacFalsa();
    await entrar('aluno', CPF, 'senha-portal', { etapa: 'portal' });
    expect(await cred.temSalvas()).toBe(false);
  });

  test('senha recusada não é guardada', async () => {
    ufacFalsa();
    await expect(entrar('aluno', CPF, 'errada', { etapa: 'portal', lembrar: true })).rejects.toThrow();
    expect(await cred.temSalvas()).toBe(false);
  });

  test('"Sair da conta" apaga as senhas', async () => {
    vi.stubGlobal('navigator', {});
    await cred.guardar('portal', CPF, 'senha-portal');
    await sair();
    cred.limparMemoria();
    expect(await cred.temSalvas()).toBe(false);
  });
});

describe('sessão caída', () => {
  test('o Portal entra sozinho e a página pedida vem', async () => {
    const ufac = ufacFalsa();
    await cred.guardar('portal', CPF, 'senha-portal');
    expect(await lerPagina('portal', '/aluno/nota/nota.action')).toBe('<p>notas</p>');
    expect(ufac.posts).toHaveLength(1);
    expect(banco.get('expirados') ?? []).not.toContain('portal');
  });

  test('o eTICKET entra sozinho com a senha dele', async () => {
    const ufac = ufacFalsa();
    await cred.guardar('eticket', CPF, 'senha-eticket');
    expect(await lerPagina('eticket', '/menu/')).toBe('<p>menu</p>');
    expect(ufac.posts[0].body).toContain('csrfmiddlewaretoken=TOKEN');
    expect(ufac.posts[0].body).toContain(`cpf=${encodeURIComponent('123.456.789-01')}`);
  });

  test('sem senha guardada, só marca a sessão como encerrada', async () => {
    const ufac = ufacFalsa();
    expect(await lerPagina('portal', '/aluno/nota/nota.action')).toBeNull();
    expect(ufac.posts).toHaveLength(0);
    expect(banco.get('expirados')).toContain('portal');
  });

  test('senha recusada: uma tentativa só, e não tenta mais', async () => {
    const ufac = ufacFalsa();
    await cred.guardar('portal', CPF, 'senha-trocada');
    expect(await lerPagina('portal', '/aluno/nota/nota.action')).toBeNull();
    expect(await lerPagina('portal', '/aluno/nota/nota.action')).toBeNull();
    expect(ufac.posts).toHaveLength(1);
    expect(banco.get('expirados')).toContain('portal');
  });

  test('com CAPTCHA na página, não envia nada e para de tentar', async () => {
    const ufac = ufacFalsa({ captcha: true });
    await cred.guardar('eticket', CPF, 'senha-eticket');
    expect(await lerPagina('eticket', '/menu/')).toBeNull();
    expect(ufac.posts).toHaveLength(0);
    expect(await cred.paraLoginAutomatico('eticket')).toBeNull();
  });

  test('várias telas ao mesmo tempo fazem um login só', async () => {
    const ufac = ufacFalsa();
    await cred.guardar('portal', CPF, 'senha-portal');
    const paginas = await Promise.all([lerPagina('portal', '/aluno/a.action'), lerPagina('portal', '/aluno/b.action'), lerPagina('portal', '/aluno/c.action')]);
    expect(paginas.every((p) => p === '<p>notas</p>')).toBe(true);
    expect(ufac.posts).toHaveLength(1);
  });

  test('com a chave desligada, não entra sozinho', async () => {
    const ufac = ufacFalsa();
    await cred.guardar('portal', CPF, 'senha-portal');
    await cred.definirLigado(false);
    expect(await lerPagina('portal', '/aluno/nota/nota.action')).toBeNull();
    expect(ufac.posts).toHaveLength(0);
  });

  test('o PDF de um relatório também entra sozinho', async () => {
    const ufac = ufacFalsa();
    banco.set('idInterno', '999');
    await cred.guardar('portal', CPF, 'senha-portal');
    const pdf = await baixarRelatorio('atestadoMatricula');
    expect(pdf).not.toBeNull();
    expect(ufac.posts).toHaveLength(1);
  });
});
