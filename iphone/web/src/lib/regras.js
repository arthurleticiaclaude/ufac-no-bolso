// Regras puras sobre endereços: o que é página de login. Porte de lib/session/regras_sessao.dart.

export function classificar(sistema, endereco) {
  let uri;
  try {
    uri = new URL(endereco);
  } catch {
    return 'outra';
  }
  const caminho = uri.pathname.toLowerCase();
  if (sistema === 'portal' || sistema === 'professor') {
    const raiz = sistema === 'portal' ? '/aluno' : '/professor';
    if (uri.hostname !== 'portal.ufac.br') return 'outra';
    if (caminho.includes('j_security_check') || caminho.includes('/publico')) return 'outra';
    // Senha vencida ou provisória: o Portal leva toda página para "Alterar Senha" do Portal do Usuário.
    if (caminho.startsWith('/usuario/usuario/')) return 'trocarSenha';
    if (caminho.includes('login') || caminho.includes('logout')) return 'naLogin';
    return caminho.startsWith(raiz) ? 'logado' : 'outra';
  }
  if (uri.hostname !== 'sistemas.ufac.br' || !caminho.startsWith('/eticket')) return 'outra';
  if (caminho.startsWith('/eticket/menuexterno')) return 'outra';
  if (caminho.startsWith('/eticket/login') || caminho.startsWith('/eticket/logout')) return 'naLogin';
  return 'logado';
}

/** "12345678901" vira "123.456.789-01", como o formulário do eTICKET faz. */
export function cpfFormatado(cpf) {
  const d = cpf.replace(/\D/g, '');
  return d.length === 11 ? `${d.slice(0, 3)}.${d.slice(3, 6)}.${d.slice(6, 9)}-${d.slice(9)}` : d;
}
