// Testa o PWA num iPhone emulado (WebKit), com um Worker falso que responde com as fixtures
// anonimizadas do projeto. Nenhum pedido vai para a Ufac.
import { mkdirSync } from 'node:fs';
import { resolve } from 'node:path';
import { expect, test } from '@playwright/test';

const PRINTS = resolve(import.meta.dirname, 'prints');
mkdirSync(PRINTS, { recursive: true });

// O Worker falso (e2e/worker-falso.mjs) roda em localhost:8787 e guarda o estado do login.
const WORKER = 'http://localhost:8787';

async function workerFalso(page) {
  await page.request.get(`${WORKER}/__reset`);
  return { pedidos: async () => (await page.request.get(`${WORKER}/__pedidos`)).json() };
}

/** Print depois que as animações terminam. */
async function print(page, nome, opcoes = {}) {
  await page.waitForFunction(() => document.getAnimations().every((a) => a.playState !== 'running'));
  await page.screenshot({ path: `${PRINTS}/${nome}.png`, ...opcoes });
}

async function entrar(page) {
  await page.goto('/');
  await page.getByRole('button', { name: 'Sou aluno' }).click();
  await page.getByLabel('CPF').fill('00000000000');
  await page.getByLabel('Senha do Portal do Aluno').fill('senha-de-teste');
  await expect(page.getByLabel('Conta salva no Chaves do iCloud')).toHaveValue('000.000.000-00 · Portal do Aluno');
  await page.getByRole('button', { name: 'Entrar no Portal' }).click();
  // Etapa 2: outra senha, outro item no Chaves.
  await expect(page.getByText('Agora é outra senha')).toBeVisible();
  await expect(page.getByLabel('Conta salva no Chaves do iCloud')).toHaveValue('000.000.000-00 · eTICKET');
  await page.getByLabel('Senha do eTICKET (ID Ufac)').fill('senha-eticket');
  await page.getByRole('button', { name: 'Entrar no eTICKET' }).click();
  await expect(page.getByRole('heading', { name: 'Olá, Pessoa' })).toBeVisible();
}

test.beforeEach(async ({ page }) => {
  // Segunda-feira, 2/11/2026, 18h40 em Rio Branco.
  await page.clock.setFixedTime(new Date('2026-11-02T18:40:00-05:00'));
});

test('manifest e metas do iPhone', async ({ page, request }) => {
  await page.goto('/');
  await expect(page.locator('meta[name="viewport"]')).toHaveAttribute('content', /viewport-fit=cover/);
  await expect(page.locator('meta[name="apple-mobile-web-app-capable"]')).toHaveAttribute('content', 'yes');
  await expect(page.locator('link[rel="apple-touch-icon"]')).toHaveAttribute('href', '/icones/icone-180.png');
  const manifest = await (await request.get('/manifest.webmanifest')).json();
  expect(manifest).toMatchObject({ display: 'standalone', start_url: '/#/inicio', lang: 'pt-BR' });
  for (const icone of manifest.icons) expect((await request.get(icone.src)).ok()).toBe(true);
  expect((await request.get('/icones/icone-180.png')).ok()).toBe(true);
  await expect(page.getByText('Não é um aplicativo oficial da Ufac')).toBeVisible();
  await print(page, '01-boas-vindas');
});

test('login em etapas, claro e escuro', async ({ page }) => {
  await workerFalso(page);
  await page.goto('/#/login/aluno');
  await page.getByLabel('CPF').fill('00000000000');
  await print(page, '12-login-portal');
  await page.getByLabel('Senha do Portal do Aluno').fill('senha-de-teste');
  await page.getByRole('button', { name: 'Entrar no Portal' }).click();
  await expect(page.getByText('Agora é outra senha')).toBeVisible();
  await page.emulateMedia({ colorScheme: 'dark' });
  await print(page, '13-login-eticket-escuro');
  // Senha do Portal no eTICKET: o erro diz qual sistema recusou.
  await page.getByLabel('Senha do eTICKET (ID Ufac)').fill('senha-de-teste');
  await page.getByRole('button', { name: 'Entrar no eTICKET' }).click();
  await expect(page.getByText('O eTICKET não aceitou')).toBeVisible();
});

test('senha errada mostra erro humano', async ({ page }) => {
  await workerFalso(page);
  await page.goto('/#/login/aluno');
  await page.getByLabel('CPF').fill('00000000000');
  await page.getByLabel('Senha do Portal do Aluno').fill('errada');
  await page.getByRole('button', { name: 'Entrar no Portal' }).click();
  await expect(page.getByText('O Portal não aceitou o CPF ou a senha')).toBeVisible();
});

test('login em 2 etapas e telas do aluno', async ({ page }) => {
  const estado = await workerFalso(page);
  await entrar(page);
  // Os dois POSTs de login aconteceram, com a senha só no corpo.
  expect((await estado.pedidos()).filter((p) => p.startsWith('POST'))).toEqual(['POST /portal/aluno/j_security_check', 'POST /eticket/login/']);

  await expect(page.getByText('R$ 12,50').first()).toBeVisible();
  await expect(page.getByText('12345678901')).toBeVisible();
  await expect(page.getByText('Curso Exemplo · Ufac')).toBeVisible();
  await expect(page.getByText('Próxima refeição · Jantar')).toBeVisible();
  await print(page, '02-inicio-claro', { fullPage: true });

  await page.getByRole('link', { name: 'Horários' }).click();
  await expect(page.getByText('Disciplina Segunda')).toBeVisible();
  await print(page, '03-horarios');

  await page.getByRole('link', { name: 'Notas' }).click();
  await expect(page.getByText('Disciplina Atual')).toBeVisible();
  await page.getByText('Disciplina Atual').click();
  await expect(page.getByRole('cell', { name: 'Média Final' })).toBeVisible();
  await expect(page.getByText('4 de 16 faltas permitidas').first()).toBeVisible();
  await print(page, '04-notas');

  await page.getByRole('link', { name: 'Relatórios' }).click();
  await expect(page.getByText('Histórico Escolar CR – Aprovados (SIE)')).toBeVisible();
  await page.getByRole('button', { name: 'Visualizar Atestado de Matrícula' }).click();
  await expect(page.locator('iframe[title="Atestado de Matrícula"]')).toBeVisible();
  await page.getByRole('button', { name: 'Fechar' }).click();
  await print(page, '05-relatorios');
  // Voltar do iPhone (histórico) leva à aba anterior.
  await page.goBack();
  await expect(page.getByRole('heading', { name: 'Notas' })).toBeVisible();
  await page.goForward();
  await expect(page.getByRole('heading', { name: 'Relatórios' })).toBeVisible();

  await page.getByRole('link', { name: 'RU' }).click();
  await expect(page.getByRole('tab', { name: /Jantar/ })).toHaveAttribute('aria-selected', 'true');
  await expect(page.getByText('O cardápio do jantar ainda não saiu')).toBeVisible();
  await page.getByRole('tab', { name: /Café/ }).click();
  await expect(page.getByText('Café preto')).toBeVisible();
  await print(page, '06-ru');

  await page.getByRole('button', { name: 'Mostrar QR de entrada' }).click();
  const qr = page.getByRole('dialog', { name: 'QR do RU' });
  await expect(qr.locator('svg').first()).toBeVisible();
  await expect(qr.getByText('•••••••8901')).toBeVisible();
  await print(page, '07-qr');
});

test('Portal entra sozinho quando a sessão cai, e para quando a chave é desligada', async ({ page }) => {
  const estado = await workerFalso(page);
  const loginsDoPortal = async () => (await estado.pedidos()).filter((p) => p === 'POST /portal/aluno/j_security_check').length;
  await page.goto('/#/login/aluno');
  await expect(page.getByLabel('Entrar sozinho quando a sessão cair')).toBeChecked();
  await entrar(page);
  expect(await loginsDoPortal()).toBe(1);

  // A sessão do Portal cai; o PDF abre mesmo assim, sem tela de login.
  await page.request.get(`${WORKER}/__expirar-portal`);
  await page.getByRole('link', { name: 'Relatórios' }).click();
  await page.getByRole('button', { name: 'Visualizar Atestado de Matrícula' }).click();
  await expect(page.locator('iframe[title="Atestado de Matrícula"]')).toBeVisible();
  expect(await loginsDoPortal()).toBe(2);
  await page.getByRole('button', { name: 'Fechar' }).click();

  // Desligar a chave apaga a senha: com a sessão caída de novo, o app pede login.
  await page.goto('/#/configuracoes');
  await expect(page.getByRole('button', { name: /Esquecer senha salva/ })).toBeVisible();
  await page.getByText('Entrar sozinho quando a sessão cair').click();
  await expect(page.getByRole('button', { name: /Esquecer senha salva/ })).toBeHidden();
  await page.request.get(`${WORKER}/__expirar-portal`);
  await page.goto('/#/relatorios');
  await page.getByRole('button', { name: 'Visualizar Atestado de Matrícula' }).click();
  await expect(page.getByText('Senha do Portal do Aluno')).toBeVisible();
  expect(await loginsDoPortal()).toBe(2);
});

test('modo escuro', async ({ page }) => {
  await page.emulateMedia({ colorScheme: 'dark' });
  await workerFalso(page);
  await entrar(page);
  await expect(page.locator('html')).toHaveCSS('background-color', 'rgb(0, 0, 0)');
  await print(page, '08-inicio-escuro', { fullPage: true });
  await page.getByRole('link', { name: 'RU' }).click();
  await expect(page.getByRole('button', { name: 'Mostrar QR de entrada' })).toBeVisible();
  await print(page, '09-ru-escuro');
});

test('abre offline com o QR do RU', async ({ page, context }) => {
  await workerFalso(page);
  await entrar(page);
  await page.evaluate(async () => {
    await navigator.serviceWorker.ready;
  });
  await page.reload();
  await page.waitForFunction(() => !!navigator.serviceWorker.controller);
  await context.setOffline(true);
  await page.reload();
  await expect(page.getByRole('heading', { name: 'Olá, Pessoa' })).toBeVisible();
  await expect(page.getByText('Não consegui falar com o eTICKET agora').or(page.getByText('R$ 12,50')).first()).toBeVisible();
  await page.getByRole('button', { name: 'Mostrar QR' }).click();
  await expect(page.getByRole('dialog', { name: 'QR do RU' }).getByText('Funciona offline')).toBeVisible();
  await print(page, '10-offline-qr');
});

test('sair apaga tudo', async ({ page }) => {
  await workerFalso(page);
  await entrar(page);
  await page.getByRole('button', { name: 'Menu' }).click();
  await page.getByRole('button', { name: 'Sair' }).click();
  await page.getByRole('dialog').getByRole('button', { name: 'Sair' }).click();
  await expect(page.getByRole('button', { name: 'Sou aluno' })).toBeVisible();
  const restou = await page.evaluate(() => new Promise((ok) => {
    const r = indexedDB.open('ufacplus', 1);
    r.onsuccess = () => { const q = r.result.transaction('kv').objectStore('kv').count(); q.onsuccess = () => ok(q.result); };
  }));
  expect(restou).toBe(0);
});

test('páginas de instalação e privacidade', async ({ page }) => {
  await page.goto('/instalar/');
  await expect(page.getByRole('heading', { name: 'Adicionar à Tela de Início' })).toBeVisible();
  await print(page, '11-instalar', { fullPage: true });
  await page.goto('/privacidade/');
  await expect(page.getByRole('heading', { name: 'O repassador (Cloudflare Worker)' })).toBeVisible();
});

test.describe('Classroom', () => {
  // O Playwright não intercepta pedidos que passam pelo service worker.
  test.use({ serviceWorkers: 'block' });
test('conecta pelo Google (simulado) e mostra as atividades', async ({ page }) => {
  await workerFalso(page);
  // Google simulado: confere o pedido e volta para o app com o código.
  await page.route('https://accounts.google.com/**', (rota) => {
    const u = new URL(rota.request().url());
    expect(u.searchParams.get('code_challenge_method')).toBe('S256');
    expect(u.searchParams.get('access_type')).toBe('offline');
    expect(u.searchParams.get('scope')).toContain('classroom.coursework.me.readonly');
    const volta = `${u.searchParams.get('redirect_uri')}?code=codigo-falso&state=${u.searchParams.get('state')}`;
    return rota.fulfill({ contentType: 'text/html', body: `<script>location.replace(${JSON.stringify(volta)})</script>` });
  });
  await page.route('https://classroom.googleapis.com/**', (rota) => {
    if (rota.request().method() === 'OPTIONS') {
      return rota.fulfill({ status: 204, headers: { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'Authorization' } });
    }
    expect(rota.request().headers().authorization).toMatch(/^Bearer A/);
    const u = new URL(rota.request().url());
    let corpo = {};
    if (u.pathname === '/v1/courses') corpo = { courses: [{ id: 'T1', name: 'Direito Civil VII', alternateLink: 'https://classroom.google.com/c/T1' }] };
    else if (u.pathname.endsWith('/courseWork')) corpo = { courseWork: [{ id: 'W1', title: 'Fichamento do capítulo 3', dueDate: { year: 2026, month: 11, day: 3 }, dueTime: { hours: 23, minutes: 59 }, alternateLink: 'https://classroom.google.com/c/T1/a/W1' }] };
    else corpo = { studentSubmissions: [{ courseWorkId: 'W1', state: 'CREATED' }] };
    return rota.fulfill({ json: corpo, headers: { 'Access-Control-Allow-Origin': '*' } });
  });
  await entrar(page);
  await page.getByRole('button', { name: 'Conectar Classroom' }).click();
  await expect(page.getByText('Classroom conectado.')).toBeVisible();
  await expect(page).toHaveURL(/\/#\/inicio$/);
  await expect(page.getByText('Fichamento do capítulo 3')).toBeVisible();
  await expect(page.getByRole('link', { name: 'Abrir o Classroom' })).toBeVisible();
  await print(page, '14-classroom', { fullPage: true });
  // Desconectar apaga a autorização e as atividades.
  await page.goto('/#/configuracoes');
  await page.getByText('Desconectar o Classroom').click();
  await page.getByRole('button', { name: 'Desconectar', exact: true }).click();
  await expect(page.getByText('Classroom desconectado.')).toBeVisible();
  expect(await (await page.request.get('http://localhost:8787/__pedidos')).json()).toContain('POST /google/desconectar');
});
});

/** Puxar para atualizar com o dedo (eventos de toque, como no iPhone). */
async function puxar(page) {
  await page.evaluate(() => {
    const tela = document.querySelector('main.tela');
    // O WebKit do teste não deixa criar Touch: um Event com as mesmas listas basta para o app.
    const toque = (tipo, y) => {
      const e = new Event(tipo, { bubbles: true });
      const lista = [{ identifier: 1, target: tela, clientX: 200, clientY: y }];
      Object.defineProperty(e, 'touches', { value: tipo === 'touchend' ? [] : lista });
      Object.defineProperty(e, 'changedTouches', { value: lista });
      tela.dispatchEvent(e);
    };
    toque('touchstart', 150);
    toque('touchmove', 300);
    toque('touchend', 300);
  });
}

test('atualizar com o eTICKET fora do ar não fica girando para sempre', async ({ page }) => {
  test.setTimeout(90000);
  await workerFalso(page);
  await entrar(page);
  await page.request.get(`${WORKER}/__eticket-mudo`);
  await puxar(page);
  await expect(page.locator('.puxar.girando')).toBeVisible();
  // O app desiste em 25 s, mostra a falha e mantém os dados salvos.
  await expect(page.locator('.puxar.girando')).toHaveCount(0, { timeout: 40000 });
  await expect(page.getByText('Não consegui falar com o eTICKET agora')).toBeVisible();
  await expect(page.getByText('R$ 12,50').first()).toBeVisible();
});

test('Início e RU atualizam sem recriar os cartões (sem piscar)', async ({ page }) => {
  await workerFalso(page);
  await entrar(page);
  const marcar = () => page.evaluate(() => document.querySelectorAll('main.tela .pilha > *').forEach((e) => (e.__marca = true)));
  const mantidos = () => page.evaluate(() => [...document.querySelectorAll('main.tela .pilha > section')].every((e) => e.__marca));
  await marcar();
  await puxar(page);
  await expect(page.locator('.puxar.girando')).toHaveCount(0);
  expect(await mantidos()).toBe(true);

  await page.getByRole('link', { name: 'RU' }).click();
  await expect(page.getByRole('heading', { name: 'RU' })).toBeVisible();
  await marcar();
  await page.getByRole('tab', { name: /Café/ }).click();
  await expect(page.getByText('Café preto')).toBeVisible();
  expect(await mantidos()).toBe(true);
});

/** Etapa 1 (Portal) do primeiro login; para na etapa do eTICKET. */
async function entrarSoNoPortal(page) {
  await page.goto('/');
  await page.getByRole('button', { name: 'Sou aluno' }).click();
  await page.getByLabel('CPF').fill('00000000000');
  await page.getByLabel('Senha do Portal do Aluno').fill('senha-de-teste');
  await page.getByRole('button', { name: 'Entrar no Portal' }).click();
  await expect(page.getByText('Ainda não tem acesso ao eTICKET?')).toBeVisible();
}

test('entrar sem o eTICKET: aviso em todas as abas e conectar depois', async ({ page }) => {
  const worker = await workerFalso(page);
  await entrarSoNoPortal(page);
  // Senha errada no eTICKET: a faixa de erro oferece seguir só com o Portal.
  await page.getByLabel('Senha do eTICKET (ID Ufac)').fill('senha-errada');
  await page.getByRole('button', { name: 'Entrar no eTICKET' }).click();
  await expect(page.getByText('O eTICKET não aceitou o CPF ou a senha')).toBeVisible();
  await print(page, '30-login-sem-eticket');
  const antes = (await worker.pedidos()).length;
  await page.getByRole('button', { name: 'Continuar sem', exact: true }).click();
  await page.getByRole('button', { name: 'Continuar sem o eTICKET' }).last().click();
  await expect(page.getByRole('heading', { name: 'Olá, Pessoa' })).toBeVisible();

  const aviso = page.locator('.faixa.eticket');
  await expect(aviso).toHaveCount(1);
  await expect(page.getByText('Sua sessão do eTICKET terminou')).toHaveCount(0);
  await expect(page.getByRole('button', { name: 'Mostrar QR' })).toHaveCount(0);
  await print(page, '31-inicio-sem-eticket');
  for (const [aba, titulo] of [['Horários', 'Horários'], ['Notas', 'Notas'], ['Relatórios', 'Relatórios'], ['RU', 'RU']]) {
    await page.locator('.abas').getByText(aba, { exact: true }).click();
    await expect(page.locator('main[data-tela]').getByRole('heading', { name: titulo, exact: true })).toBeVisible();
    await expect(page.locator('main:not([style*="hidden"]) .faixa.eticket')).toHaveCount(1);
  }
  // O cardápio vem da página pública, sem login.
  await page.getByRole('tab', { name: /Café/ }).click();
  await expect(page.getByText('Café preto')).toBeVisible();
  await print(page, '32-ru-sem-eticket');
  // Depois de pular, nenhum pedido ao eTICKET além do cardápio público.
  const depois = (await worker.pedidos()).slice(antes);
  expect(depois.some((p) => p.includes('/eticket/menuExterno/'))).toBe(true);
  expect(depois.filter((p) => /^\w+ \/eticket\//.test(p) && !p.includes('/eticket/menuExterno/'))).toEqual([]);

  // Conectar depois, pelo aviso.
  await page.locator('main:not([style*="hidden"]) .faixa.eticket').getByRole('button', { name: 'Conectar' }).click();
  await expect(page.getByText('Ainda não tem acesso ao eTICKET?')).toHaveCount(0); // no Conectar não se oferece pular
  await page.getByLabel('CPF').fill('00000000000');
  await page.getByLabel('Senha do eTICKET (ID Ufac)').fill('senha-eticket');
  await page.getByRole('button', { name: 'Entrar no eTICKET' }).click();
  await expect(page.getByRole('heading', { name: 'Olá, Pessoa' })).toBeVisible();
  await expect(page.locator('.faixa.eticket')).toHaveCount(0);
  await expect(page.getByRole('button', { name: 'Mostrar QR' })).toBeVisible();
});

test('sem eTICKET pelo cartão: cancelar mantém a etapa; senha errada no Conectar mantém o aviso; Sair limpa', async ({ page }) => {
  await workerFalso(page);
  await entrarSoNoPortal(page);
  await page.getByRole('button', { name: 'Continuar sem o eTICKET' }).click();
  await page.getByRole('button', { name: 'Cancelar' }).click();
  await expect(page.getByLabel('Senha do eTICKET (ID Ufac)')).toBeVisible();
  await page.getByRole('button', { name: 'Continuar sem o eTICKET' }).first().click();
  await page.getByRole('button', { name: 'Continuar sem o eTICKET' }).last().click();
  await expect(page.getByRole('heading', { name: 'Olá, Pessoa' })).toBeVisible();

  // Senha errada no Conectar: erro normal (Relatar), e o aviso continua na Início.
  await page.locator('.faixa.eticket').getByRole('button', { name: 'Conectar' }).click();
  await page.getByLabel('CPF').fill('00000000000');
  await page.getByLabel('Senha do eTICKET (ID Ufac)').fill('senha-errada');
  await page.getByRole('button', { name: 'Entrar no eTICKET' }).click();
  await expect(page.getByRole('button', { name: 'Relatar', exact: true })).toBeVisible();
  await expect(page.getByRole('button', { name: 'Continuar sem', exact: true })).toHaveCount(0);
  await page.getByRole('button', { name: 'Voltar' }).click();
  await expect(page.locator('.faixa.eticket')).toHaveCount(1);

  // Sair apaga a escolha: o próximo login completo não mostra o aviso.
  await page.getByRole('button', { name: 'Menu' }).click();
  await page.getByRole('button', { name: 'Configurações' }).click();
  await expect(page.getByText('Conectar o eTICKET do RU')).toBeVisible();
  await page.getByRole('button', { name: 'Voltar' }).click();
  await page.getByRole('button', { name: 'Sair' }).click();
  await page.getByRole('dialog').getByRole('button', { name: 'Sair' }).click();
  await expect(page.getByRole('button', { name: 'Sou aluno' })).toBeVisible();
  await entrar(page);
  await expect(page.locator('.faixa.eticket')).toHaveCount(0);
});
