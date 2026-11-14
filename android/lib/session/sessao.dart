import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'credenciais.dart';
import 'regras_sessao.dart';

enum ResultadoVerificacao { ativa, expirada, semResposta }

/// Página aberta em segundo plano. O HTML só existe com sessão ativa e nunca vai para log.
class PaginaLida {
  const PaginaLida(this.resultado, [this.html]);
  final ResultadoVerificacao resultado;
  final String? html;
}

typedef Leitor = Future<PaginaLida> Function(Sistema sistema, String url);

/// Estado do login. A senha nunca passa por aqui: só existem os cookies da WebView
/// e a marca de que a pessoa já entrou.
class Sessao extends ChangeNotifier {
  Sessao._();
  static final instancia = Sessao._();

  static const _chaveLogin = 'login_concluido';
  static const _cofre = FlutterSecureStorage();

  /// Substituído nos testes, onde não existe WebView.
  Leitor leitor = _lerComWebView;

  final Set<Sistema> _expirados = {};
  Set<Sistema> get expirados => _expirados;

  /// Sistemas que a pessoa escolheu não conectar (ex.: só usa o RU, ou não usa o RU).
  /// O app não lê nada deles e mostra um botão "Conectar" no lugar dos dados.
  static const _chavePulados = 'sistemas_pulados';
  final Set<Sistema> _pulados = {};

  bool conectado(Sistema sistema) => !_pulados.contains(sistema);

  Future<void> carregarPulados() async {
    final salvo = await _cofre.read(key: _chavePulados) ?? '';
    _pulados
      ..clear()
      ..addAll(Sistema.values.where((s) => salvo.split(',').contains(s.name)));
  }

  Future<void> _gravarPulados() => _cofre.write(key: _chavePulados, value: _pulados.map((s) => s.name).join(','));

  Future<void> pular(Sistema sistema) async {
    _pulados.add(sistema);
    _expirados.remove(sistema);
    await _gravarPulados();
    notifyListeners();
  }

  /// Chamado a cada login que deu certo naquele sistema.
  Future<void> conectar(Sistema sistema) async {
    if (!_pulados.remove(sistema)) return;
    await _gravarPulados();
    notifyListeners();
  }

  Future<bool> loginConcluido() async => await _cofre.read(key: _chaveLogin) == 'sim';

  Future<void> concluirLogin() async {
    await _cofre.write(key: _chaveLogin, value: 'sim');
    _expirados.clear();
    notifyListeners();
  }

  /// Lê uma página de um sistema e atualiza o aviso. Sem internet não é sessão expirada.
  Future<PaginaLida> lerEMarcar(Sistema sistema, {String? url}) async {
    final pagina = await leitor(sistema, url ?? sistema.entrada);
    if (pagina.resultado == ResultadoVerificacao.expirada) {
      _expirados.add(sistema);
    } else if (pagina.resultado == ResultadoVerificacao.ativa) {
      _expirados.remove(sistema);
    }
    notifyListeners();
    return pagina;
  }

  /// Roda ao abrir o app. Só o eTICKET: traz saldo e QR. A sessão do portal cai em menos
  /// de 1 hora, então ela só é conferida quando alguma tela precisa dele.
  Future<PaginaLida> verificar() async =>
      conectado(Sistema.eticket) ? lerEMarcar(Sistema.eticket) : const PaginaLida(ResultadoVerificacao.semResposta);

  /// Apaga sessão, número do QR e tudo que está no armazenamento seguro deste celular.
  Future<void> sair() async {
    await CookieManager.instance().deleteAllCookies();
    await _cofre.deleteAll(); // inclui CPF e senha do login automático
    Credenciais.instancia.limparMemoria();
    _expirados.clear();
    _pulados.clear();
    notifyListeners();
  }
}

Future<PaginaLida> _lerComWebView(Sistema sistema, String endereco) async {
  final fim = Completer<PaginaLida>();
  void concluir(PaginaLida p) {
    if (!fim.isCompleted) fim.complete(p);
  }

  // Login automático: no máximo uma tentativa por leitura, só com senha guardada pela pessoa.
  final login = await Credenciais.instancia.paraLoginAutomatico();
  var tentouLogin = false, recarregou = false;
  final webview = HeadlessInAppWebView(
    initialUrlRequest: URLRequest(url: WebUri(endereco)),
    initialSettings: InAppWebViewSettings(useShouldOverrideUrlLoading: true),
    shouldOverrideUrlLoading: (controle, acao) async {
      final destino = acao.request.url;
      final https = destino == null ? null : versaoHttps(destino);
      if (https == null) return NavigationActionPolicy.ALLOW;
      await controle.loadUrl(urlRequest: URLRequest(url: WebUri.uri(https)));
      return NavigationActionPolicy.CANCEL;
    },
    onLoadStop: (controle, url) async {
      if (url == null || url.scheme != 'https') return;
      switch (classificar(sistema, url)) {
        case EstadoPagina.logado:
          // Depois do login automático, o site pode cair na página inicial: volta para a pedida.
          if (tentouLogin && !recarregou) {
            recarregou = true;
            await controle.loadUrl(urlRequest: URLRequest(url: WebUri(endereco)));
            return;
          }
          concluir(PaginaLida(ResultadoVerificacao.ativa, await controle.getHtml()));
        case EstadoPagina.naLogin:
          if (login != null && !tentouLogin) {
            tentouLogin = true;
            final r = await controle.evaluateJavascript(
              source: scriptLoginAutomatico(eticket: sistema == Sistema.eticket, cpf: login.$1, senha: login.$2),
            );
            if (r == 'enviado') return; // espera a próxima página
            concluir(const PaginaLida(ResultadoVerificacao.expirada));
            return;
          }
          // Já tentou e voltou para o login: senha recusada (ou mudou). Para de tentar.
          if (tentouLogin) Credenciais.instancia.falhou = true;
          concluir(const PaginaLida(ResultadoVerificacao.expirada));
        case EstadoPagina.outra:
          concluir(const PaginaLida(ResultadoVerificacao.semResposta));
      }
    },
    onReceivedError: (_, pedido, erro) {
      if (pedido.isForMainFrame == true && erro.type != WebResourceErrorType.CANCELLED) {
        concluir(const PaginaLida(ResultadoVerificacao.semResposta));
      }
    },
  );
  try {
    await webview.run();
    return await fim.future.timeout(
      Duration(seconds: login == null ? 20 : 40),
      onTimeout: () => const PaginaLida(ResultadoVerificacao.semResposta),
    );
  } finally {
    await webview.dispose();
  }
}
