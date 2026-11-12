// Cache local em IndexedDB (só neste iPhone). O service worker lê o mesmo banco para montar as notificações.
const NOME = 'ufacplus';
let conexao;

function abrir() {
  conexao ??= new Promise((ok, erro) => {
    const r = indexedDB.open(NOME, 1);
    r.onupgradeneeded = () => r.result.createObjectStore('kv');
    r.onsuccess = () => {
      // O iOS fecha a conexão quando o app fica em segundo plano: a próxima operação abre outra.
      r.result.onclose = () => (conexao = null);
      ok(r.result);
    };
    r.onerror = () => {
      conexao = null;
      erro(r.error);
    };
  });
  return conexao;
}

function transacao(db, modo, fn) {
  return new Promise((ok, erro) => {
    const tx = db.transaction('kv', modo); // lança se a conexão já morreu
    const pedido = fn(tx.objectStore('kv'));
    tx.oncomplete = () => ok(pedido?.result);
    tx.onerror = () => erro(tx.error);
    // Sem isto, uma transação abortada (comum no iOS ao voltar do segundo plano) deixava a promessa pendurada.
    tx.onabort = () => erro(tx.error ?? new DOMException('Transação abortada', 'AbortError'));
  });
}

async function operar(modo, fn) {
  try {
    return await transacao(await abrir(), modo, fn);
  } catch {
    // Conexão perdida: abre de novo e tenta uma vez.
    conexao = null;
    return transacao(await abrir(), modo, fn);
  }
}

export const ler = (chave) => operar('readonly', (s) => s.get(chave));
export const gravar = (chave, valor) => operar('readwrite', (s) => s.put(valor, chave));
export const apagar = (chave) => operar('readwrite', (s) => s.delete(chave));
export const apagarTudo = () => operar('readwrite', (s) => s.clear());
