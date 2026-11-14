// Pedaços usados por mais de uma tela.
import { ler, gravar } from '../lib/armazenamento.js';
import { SemConexao } from '../lib/api.js';
import { ErroLeitura } from '../lib/dados.js';
import { faixa, html } from '../ui/componentes.js';
import { formatarHora } from '../lib/dominio/formatos.js';

/** Frase humana para uma falha de leitura, com a hora dos dados que continuam na tela. */
export function fraseDeFalha(erro, nome, lidoEm) {
  const quando = lidoEm ? ` Mostrando dados das ${formatarHora(new Date(lidoEm).getHours(), new Date(lidoEm).getMinutes())}.` : '';
  if (erro instanceof SemConexao) return `Não consegui falar com ${nome} agora.${quando}`;
  if (erro instanceof ErroLeitura) return `${erro.message}${quando}`;
  return `Algo deu errado ao ler ${nome}.${quando}`;
}

export const faixaFalha = (texto) => faixa({ icone: 'semConexao', titulo: texto, tipo: '', acao: 'relatar', rotuloAcao: 'Relatar' });

// Lido por expirado() logo antes de cada faixaExpirada(): todas as telas chamam as duas juntas.
let pedeSenhaNova = false;

export const faixaExpirada = (sistema) =>
  sistema !== 'eticket' && pedeSenhaNova
    ? faixa({
        icone: 'cadeado',
        titulo: 'O Portal pede uma senha nova',
        texto: 'Troque no site da Ufac e depois entre de novo aqui com a senha nova.',
        acao: 'trocar-senha-portal',
        rotuloAcao: 'Abrir o site',
      })
    : faixa({
    icone: 'cadeado',
    titulo: sistema === 'eticket' ? 'Sua sessão do eTICKET terminou' : 'Sua sessão do Portal terminou',
    texto: 'Os dados salvos continuam aqui.',
    acao: `entrar-${sistema}`,
    rotuloAcao: 'Entrar de novo',
  });

export async function expirado(sistema) {
  if (sistema === 'eticket' && (await semEticket())) return false; // nunca entrou no eTICKET: o aviso é outro
  if (sistema !== 'eticket') pedeSenhaNova = (await ler('portalPedeSenha')) === true;
  return ((await ler('expirados')) ?? []).includes(sistema);
}

export const semEticket = async () => (await ler('semEticket')) === true;

/**
 * Aviso das abas para quem entrou só com o Portal. Discreto (uma faixa, do tamanho das outras), mas na cor
 * primária, para chamar a atenção. O toque leva ao login do eTICKET; ao conectar, o aviso some sozinho.
 */
export async function avisoSemEticket() {
  if (!(await semEticket())) return '';
  return faixa({
    icone: 'ru',
    titulo: 'Conecte o eTICKET do RU',
    texto: 'Para ver o saldo, o QR de entrada e o histórico do RU.',
    tipo: 'eticket',
    acao: 'conectar-eticket',
    rotuloAcao: 'Conectar',
  });
}

/** Foto de perfil: escolhida da galeria, recortada em quadrado e reduzida a 512 px. Fica só no iPhone. */
export function escolherFoto() {
  return new Promise((resolve) => {
    const entrada = document.createElement('input');
    entrada.type = 'file';
    entrada.accept = 'image/*';
    entrada.onchange = async () => {
      const arquivo = entrada.files?.[0];
      if (!arquivo) return resolve(false);
      const imagem = await createImageBitmap(arquivo);
      const lado = Math.min(imagem.width, imagem.height);
      const canvas = document.createElement('canvas');
      canvas.width = canvas.height = 512;
      canvas.getContext('2d').drawImage(imagem, (imagem.width - lado) / 2, (imagem.height - lado) / 2, lado, lado, 0, 0, 512, 512);
      const blob = await new Promise((ok) => canvas.toBlob(ok, 'image/jpeg', 0.86));
      await gravar('foto', blob);
      await gravar('fotoVersao', String(Date.now()));
      resolve(true);
    };
    entrada.click();
  });
}

// A mesma foto mantém o mesmo endereço: um endereço novo a cada desenho fazia a foto piscar.
let urlFoto;
let versaoFoto;
export async function fotoOuIniciais(iniciais) {
  const foto = await ler('foto');
  if (!foto) return html`${iniciais}`;
  const versao = (await ler('fotoVersao')) ?? `${foto.size}|${foto.type}`;
  if (!urlFoto || versao !== versaoFoto) {
    if (urlFoto) URL.revokeObjectURL(urlFoto);
    urlFoto = URL.createObjectURL(foto);
    versaoFoto = versao;
  }
  return html`<img src="${urlFoto}" alt="Sua foto">`;
}
