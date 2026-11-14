// Monta o texto do "Relatar um problema": aparelho, estado do app e o registro de eventos, sem dados da pessoa.
import { ler } from './armazenamento.js';
import { CONTATO_EMAIL, CONTATO_WHATSAPP, VERSAO } from './config.js';
import { lerRegistro } from './registro.js';

const LIMITE = 5500; // o link de e-mail/WhatsApp fica longo demais acima disso

const hora = (iso) => {
  const d = new Date(iso);
  const p = (n) => String(n).padStart(2, '0');
  return `${p(d.getDate())}/${p(d.getMonth() + 1)} ${p(d.getHours())}:${p(d.getMinutes())}`;
};

function linhaDoEvento({ em, tipo, ...resto }) {
  const detalhes = Object.entries(resto)
    .map(([k, v]) => `${k}=${typeof v === 'object' ? JSON.stringify(v) : v}`)
    .join(' ');
  return `${hora(em)} ${tipo} ${detalhes}`;
}

export async function textoTecnico(tela = '') {
  const ios = /OS (\d+[._]\d+)/.exec(navigator.userAgent)?.[1]?.replace('_', '.') ?? 'desconhecido';
  const [perfil, expirados, idInterno, registro, ...caches] = await Promise.all([
    ler('perfil'), ler('expirados'), ler('idInterno'), lerRegistro(),
    ...['identificacao', 'ru', 'cardapio', 'horarios', 'notas', 'historico'].map((k) => ler(k)),
  ]);
  const nomes = ['identificação', 'saldo', 'cardápio', 'horários', 'notas', 'histórico'];
  const salvos = nomes.map((n, i) => `${n} ${caches[i]?.lidoEm ? hora(caches[i].lidoEm) : 'não'}`).join(', ');
  const cabeca = [
    `UFAC+ ${VERSAO} (iPhone/PWA) · iOS ${ios} · ${navigator.standalone ? 'instalado' : 'no Safari'} · ${navigator.onLine ? 'online' : 'offline'}`,
    `Perfil: ${perfil ?? 'nenhum'} · Tela: ${tela || '-'} · Sessão vencida: ${(expirados ?? []).join(', ') || 'nenhuma'} · Número interno lido: ${idInterno ? 'sim' : 'não'}`,
    `Dados salvos: ${salvos}`,
    'Eventos (mais recentes no fim):',
  ].join('\n');
  // Corta os eventos mais antigos até caber no link.
  const linhas = registro.map(linhaDoEvento);
  while (linhas.length && cabeca.length + linhas.join('\n').length > LIMITE) linhas.shift();
  return `${cabeca}\n${linhas.join('\n') || '(nenhum evento registrado)'}`;
}

export const montarRelato = (descricao, tecnico) =>
  `O que aconteceu?\n${descricao.trim() || '(não descrito)'}\n\n--- Informações técnicas (sem nome, CPF, matrícula ou senha) ---\n${tecnico}\n`;

export const canais = () => ({ email: !!CONTATO_EMAIL, whatsapp: !!CONTATO_WHATSAPP, compartilhar: typeof navigator.share === 'function' });

export function abrirEmail(texto) {
  location.href = `mailto:${CONTATO_EMAIL}?subject=${encodeURIComponent(`UFAC+ iPhone ${VERSAO}: problema`)}&body=${encodeURIComponent(texto)}`;
}

export function abrirWhatsapp(texto) {
  location.href = `https://wa.me/${CONTATO_WHATSAPP.replace(/\D/g, '')}?text=${encodeURIComponent(texto)}`;
}

/** Folha de compartilhar do iPhone (WhatsApp, Mensagens, Telegram...). Devolve false se a pessoa cancelou. */
export async function compartilhar(texto) {
  try {
    await navigator.share({ title: 'UFAC+: problema', text: texto });
    return true;
  } catch {
    return false;
  }
}
