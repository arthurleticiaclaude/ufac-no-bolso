// Regras puras sobre endereços: onde o login acontece e como saber se deu certo.

enum Sistema {
  portal('Portal do Aluno', 'https://portal.ufac.br/aluno/index.action'),
  professor('Portal do Professor', 'https://portal.ufac.br/professor/index.action'),
  eticket('eTICKET do RU', 'https://sistemas.ufac.br/eticket/');

  const Sistema(this.nome, this.entrada);
  final String nome;
  final String entrada;
}

enum EstadoPagina { logado, naLogin, outra }

/// A WebView só navega dentro dos sites da Ufac.
bool ehSiteDaUfac(Uri uri) => uri.host == 'ufac.br' || uri.host.endsWith('.ufac.br');

/// O portal redireciona passando por http://. Trocamos para https:// antes de sair
/// do celular, para o cookie de sessão nunca viajar sem criptografia.
Uri? versaoHttps(Uri uri) => uri.scheme == 'http' && ehSiteDaUfac(uri) ? uri.replace(scheme: 'https') : null;

EstadoPagina classificar(Sistema sistema, Uri uri) {
  final caminho = uri.path.toLowerCase();
  switch (sistema) {
    case Sistema.portal:
      if (uri.host != 'portal.ufac.br' || !caminho.startsWith('/aluno')) return EstadoPagina.outra;
      if (caminho.contains('j_security_check') || caminho.contains('/publico')) return EstadoPagina.outra;
      if (caminho.contains('login') || caminho.contains('logout')) return EstadoPagina.naLogin;
      return EstadoPagina.logado;
    case Sistema.professor:
      if (uri.host != 'portal.ufac.br') return EstadoPagina.outra;
      if (caminho.contains('j_security_check') || caminho.contains('/publico')) return EstadoPagina.outra;
      // A página de login do professor ainda não foi vista: qualquer "login" no portal conta.
      if (caminho.contains('login') || caminho.contains('logout')) return EstadoPagina.naLogin;
      return caminho.startsWith('/professor') ? EstadoPagina.logado : EstadoPagina.outra;
    case Sistema.eticket:
      if (uri.host != 'sistemas.ufac.br' || !caminho.startsWith('/eticket')) return EstadoPagina.outra;
      if (caminho.startsWith('/eticket/menuexterno')) return EstadoPagina.outra;
      if (caminho.startsWith('/eticket/login') || caminho.startsWith('/eticket/logout')) {
        return EstadoPagina.naLogin;
      }
      return EstadoPagina.logado;
  }
}
