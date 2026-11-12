// Service worker do UFAC+: abre offline (inclusive o QR do RU) e monta as notificações.
// O push chega só com { t: tipo, r: referência }; o texto sai dos dados já salvos neste iPhone.
const CACHE = 'ufacplus-app';

self.addEventListener('install', (e) => {
  e.waitUntil(
    (async () => {
      const { versao, arquivos } = await (await fetch('/arquivos.json', { cache: 'no-store' })).json();
      const cache = await caches.open(`${CACHE}-${versao}`);
      await cache.addAll(arquivos);
      await self.skipWaiting();
    })(),
  );
});

self.addEventListener('activate', (e) => {
  e.waitUntil(
    (async () => {
      const nomes = await caches.keys();
      const atual = nomes.filter((n) => n.startsWith(CACHE)).sort().pop();
      await Promise.all(nomes.filter((n) => n.startsWith(CACHE) && n !== atual).map((n) => caches.delete(n)));
      await self.clients.claim();
    })(),
  );
});

self.addEventListener('fetch', (e) => {
  const url = new URL(e.request.url);
  if (e.request.method !== 'GET' || url.origin !== location.origin) return; // Worker e Google passam direto
  if (e.request.mode === 'navigate') {
    // Página: tenta a rede (versão nova) e cai no cache sem internet.
    e.respondWith(
      fetch(e.request).catch(async () => (await caches.match(e.request)) ?? (await caches.match('/'))),
    );
    return;
  }
  e.respondWith((async () => (await caches.match(e.request)) ?? fetch(e.request))());
});

// ---------- Notificações ----------

function lerDoBanco(chave) {
  return new Promise((ok) => {
    const r = indexedDB.open('ufacplus', 1);
    r.onupgradeneeded = () => r.result.createObjectStore('kv');
    r.onerror = () => ok(undefined);
    r.onsuccess = () => {
      const tx = r.result.transaction('kv', 'readonly');
      const pedido = tx.objectStore('kv').get(chave);
      pedido.onsuccess = () => ok(pedido.result);
      pedido.onerror = () => ok(undefined);
    };
  });
}

const hora = (min) => {
  const h = Math.floor(min / 60), m = min % 60;
  return m === 0 ? `${h}h` : `${h}h${String(m).padStart(2, '0')}`;
};
const mesmoDia = (a, b) => a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
const REFEICOES = { cafe: ['Café', 6 * 60 + 30], almoco: ['Almoço', 11 * 60], jantar: ['Jantar', 18 * 60] };

async function aviso(t, r) {
  const agora = new Date();
  if (t === 'aula') {
    const [dia, ini] = r.split('-').map(Number);
    let aulas = (await lerDoBanco('horarios'))?.aulas ?? [];
    if ((await lerDoBanco('perfil')) === 'professor') {
      aulas = ((await lerDoBanco('professor'))?.turmas ?? []).flatMap((x) =>
        (x.detalhe?.horarios ?? []).map((h) => ({ disciplina: `${x.turma.disciplina} · ${x.turma.nome}`, diaSemana: h.diaSemana, inicioMin: h.inicioMin })),
      );
    }
    const aula = aulas.find((a) => a.diaSemana === dia && a.inicioMin === ini);
    return {
      titulo: aula ? aula.disciplina : 'Próxima aula',
      corpo: `Começa às ${hora(ini)}, daqui a 15 minutos.`,
      url: '/#/horarios',
      tag: `aula-${r}`,
    };
  }
  if (t === 'refeicao') {
    const [nome, ini] = REFEICOES[r] ?? ['Refeição', 0];
    const c = await lerDoBanco('cardapio');
    const texto = c && mesmoDia(new Date(c.lidoEm), agora) ? (c.textos?.[r] ?? '') : '';
    const itens = texto && !/não informado|indisponível/i.test(texto) ? texto.replace(/\.$/, '') : '';
    return {
      titulo: `${nome} no RU às ${hora(ini)}`,
      corpo: itens || 'O cardápio ainda não saiu no eTICKET. Toque para conferir.',
      url: `/#/ru/${r}`,
      tag: `refeicao-${r}`,
    };
  }
  if (t === 'classroom') {
    const limite = new Date(agora.getFullYear(), agora.getMonth(), agora.getDate() + 2);
    const lista = ((await lerDoBanco('classroom'))?.atividades ?? []).filter(
      (a) => a.situacao !== 'entregue' && a.prazo && new Date(a.prazo) > agora && new Date(a.prazo) < limite,
    );
    return {
      titulo: lista.length === 1 ? '1 atividade para entregar' : lista.length ? `${lista.length} atividades para entregar` : 'Classroom',
      corpo: lista.length ? lista.map((a) => a.titulo).join(' · ') : 'Confira as atividades da semana.',
      url: '/#/inicio',
      tag: 'classroom',
      selo: lista.length,
    };
  }
  return { titulo: 'UFAC+', corpo: 'Toque para abrir.', url: '/#/inicio', tag: 'ufacplus' };
}

self.addEventListener('push', (e) => {
  e.waitUntil(
    (async () => {
      let dados = {};
      try {
        dados = e.data?.json() ?? {};
      } catch {
        /* push sem conteúdo */
      }
      const a = await aviso(dados.t, String(dados.r ?? ''));
      if (a.selo && self.navigator.setAppBadge) self.navigator.setAppBadge(a.selo).catch(() => {});
      // O iPhone exige mostrar uma notificação para cada push recebido.
      await self.registration.showNotification(a.titulo, { body: a.corpo, tag: a.tag, icon: '/icones/icone-192.png', data: { url: a.url } });
    })(),
  );
});

self.addEventListener('notificationclick', (e) => {
  e.notification.close();
  const url = e.notification.data?.url ?? '/#/inicio';
  e.waitUntil(
    (async () => {
      const janelas = await self.clients.matchAll({ type: 'window', includeUncontrolled: true });
      for (const j of janelas) {
        if ('focus' in j) {
          await j.navigate(url).catch(() => {});
          return j.focus();
        }
      }
      return self.clients.openWindow(url);
    })(),
  );
});
