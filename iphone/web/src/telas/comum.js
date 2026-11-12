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

export const faixaFalha = (texto) => faixa({ icone: 'semConexao', titulo: texto, tipo: '' });

export const faixaExpirada = (sistema) =>
  faixa({
    icone: 'cadeado',
    titulo: sistema === 'eticket' ? 'Sua sessão do eTICKET terminou' : 'Sua sessão do Portal terminou',
    texto: 'Os dados salvos continuam aqui.',
    acao: `entrar-${sistema}`,
    rotuloAcao: 'Entrar de novo',
  });

export async function expirado(sistema) {
  return ((await ler('expirados')) ?? []).includes(sistema);
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
