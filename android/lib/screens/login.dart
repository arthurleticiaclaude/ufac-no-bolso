import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../session/credenciais.dart';
import '../session/regras_sessao.dart';
import '../session/sessao.dart';
import '../theme/app_cores.dart';
import '../theme/app_medidas.dart';
import '../theme/app_texto.dart';
import '../ui/componentes.dart';

/// Tela do app com a página oficial de login embaixo. Quem digita é a pessoa, no site da Ufac.
class TelaLogin extends StatefulWidget {
  const TelaLogin({super.key, required this.etapas, required this.aoConcluir});

  final List<Sistema> etapas;
  final void Function(BuildContext contexto) aoConcluir;

  @override
  State<TelaLogin> createState() => _TelaLoginState();
}

class _TelaLoginState extends State<TelaLogin> {
  int _etapa = 0;
  bool _carregando = true;
  bool _falhou = false;
  int _tentativa = 0;

  /// "Entrar sozinho quando a sessão cair": guarda o CPF e a senha que a pessoa digitou
  /// na página oficial, cifrados no cofre do Android.
  bool _lembrar = true;
  (String, String)? _digitado;

  Sistema get _sistema => widget.etapas[_etapa];

  @override
  void initState() {
    super.initState();
    Credenciais.instancia.ligado().then((v) {
      if (mounted) setState(() => _lembrar = v);
    });
  }

  // O portal é uma página de computador, sem ajuste para celular. Aproxima a área do
  // formulário; só mexe no enquadramento, sem ler nem tocar nos campos.
  static const _aproximarFormulario = '''
    (function () {
      var f = document.forms[0];
      if (!f) return;
      var r = f.getBoundingClientRect();
      var meta = document.createElement('meta');
      meta.name = 'viewport';
      meta.content = 'width=' + Math.ceil(r.width + 32);
      document.head.appendChild(meta);
      window.scrollTo(r.left + window.scrollX - 16, r.top + window.scrollY - 16);
    })();
  ''';

  // O eTICKET mede o formulário pela altura da tela (vh). Quando o teclado abre, essa altura
  // cai e o formulário se espreme. Trava o tamanho que ele tinha com o teclado fechado.
  static const _travarTamanho = '''
    (function () {
      document.querySelectorAll('.login-container, .login-box').forEach(function (e) {
        var s = getComputedStyle(e);
        e.style.setProperty('width', s.width, 'important');
        e.style.setProperty('height', s.height, 'important');
      });
      document.documentElement.style.setProperty('overflow', 'auto', 'important');
      document.body.style.setProperty('overflow', 'auto', 'important');
    })();
  ''';

  Future<void> _aoTerminarDeCarregar(InAppWebViewController controle, WebUri? url) async {
    if (!mounted || url == null || url.scheme != 'https') return;
    final estado = classificar(_sistema, url);
    if (estado == EstadoPagina.naLogin) {
      await controle.evaluateJavascript(
        source: _sistema == Sistema.eticket ? _travarTamanho : _aproximarFormulario,
      );
      // Só avisa o app do que foi digitado; não lê nada antes de a pessoa apertar Entrar.
      await controle.evaluateJavascript(source: scriptCapturarLogin(eticket: _sistema == Sistema.eticket));
      if (!mounted) return;
    }
    setState(() => _carregando = false);
    if (estado != EstadoPagina.logado) return;
    final digitado = _digitado;
    _digitado = null;
    if (_lembrar && digitado != null) {
      await Credenciais.instancia.guardar(digitado.$1, digitado.$2);
    }
    if (!mounted) return;
    if (_etapa < widget.etapas.length - 1) {
      setState(() {
        _etapa++;
        _carregando = true;
      });
      return;
    }
    await Sessao.instancia.concluirLogin();
    if (mounted) widget.aoConcluir(context);
  }

  Future<NavigationActionPolicy> _aoNavegar(InAppWebViewController controle, NavigationAction acao) async {
    final destino = acao.request.url;
    if (destino == null) return NavigationActionPolicy.CANCEL;
    final https = versaoHttps(destino);
    if (https != null) {
      await controle.loadUrl(urlRequest: URLRequest(url: WebUri.uri(https)));
      return NavigationActionPolicy.CANCEL;
    }
    return ehSiteDaUfac(destino) && destino.scheme == 'https'
        ? NavigationActionPolicy.ALLOW
        : NavigationActionPolicy.CANCEL;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final etapa = widget.etapas.length > 1
        ? 'Etapa ${_etapa + 1} de ${widget.etapas.length} · ${_sistema.nome}'
        : _sistema.nome;
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, AppMedidas.margem, 10),
              child: Row(
                children: [
                  BotaoRedondo(
                    icone: Icons.arrow_back_rounded,
                    descricao: 'Voltar',
                    aoTocar: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Entrar com ID Ufac', style: AppTexto.tituloCartao),
                        Text(etapa, style: AppTexto.rotulo.copyWith(color: c.secundario)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppMedidas.margem),
              child: Text(
                'Entre com seu ID Ufac. Sua senha fica só no site da Ufac.',
                style: AppTexto.apoio.copyWith(color: c.secundario),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppMedidas.margem, 8, AppMedidas.margem, 10),
              child: Selo(
                texto: _lembrar
                    ? 'Página oficial da Ufac · a senha fica cifrada só neste celular'
                    : 'Página oficial da Ufac · sua senha não passa pelo app',
                cor: c.verde,
                fundo: c.verdeFundo,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppMedidas.margem, 0, 12, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Entrar sozinho quando a sessão cair', style: AppTexto.corpoForte),
                        Text(
                          'Guarda seu CPF e senha cifrados neste celular. Eles só vão para o site da Ufac.',
                          style: AppTexto.rotulo.copyWith(color: c.secundario),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _lembrar,
                    onChanged: (v) {
                      setState(() => _lembrar = v);
                      Credenciais.instancia.definirLigado(v);
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: _falhou
                  ? EstadoVazio(
                      icone: Icons.wifi_off_rounded,
                      titulo: 'Não consegui abrir a página da Ufac agora',
                      texto: 'Confira sua internet e tente de novo.',
                      acao: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppMedidas.margem),
                        child: BotaoContorno(
                          texto: 'Tentar de novo',
                          cor: c.navAtivo,
                          aoTocar: () => setState(() {
                            _falhou = false;
                            _carregando = true;
                            _tentativa++;
                          }),
                        ),
                      ),
                    )
                  : Stack(
                      children: [
                        InAppWebView(
                          key: ValueKey('${_sistema.name}-$_tentativa'),
                          initialUrlRequest: URLRequest(url: WebUri(_sistema.entrada)),
                          initialSettings: InAppWebViewSettings(
                            useShouldOverrideUrlLoading: true,
                            supportZoom: true,
                            builtInZoomControls: true,
                            displayZoomControls: false,
                            // O eTICKET já é feito para celular; só o portal precisa disso.
                            useWideViewPort: _sistema != Sistema.eticket,
                            loadWithOverviewMode: _sistema != Sistema.eticket,
                            mixedContentMode: MixedContentMode.MIXED_CONTENT_NEVER_ALLOW,
                          ),
                          shouldOverrideUrlLoading: _aoNavegar,
                          onWebViewCreated: (controle) => controle.addJavaScriptHandler(
                            handlerName: 'loginDigitado',
                            callback: (args) {
                              // Só fica na memória até o login dar certo; nunca vai para log.
                              if (_lembrar && args.length == 2 && args[0] is String && args[1] is String) {
                                _digitado = (args[0] as String, args[1] as String);
                              }
                              return null;
                            },
                          ),
                          onLoadStop: _aoTerminarDeCarregar,
                          onReceivedError: (_, pedido, erro) {
                            if (pedido.isForMainFrame == true && erro.type != WebResourceErrorType.CANCELLED && mounted) {
                              setState(() => _falhou = true);
                            }
                          },
                        ),
                        if (_carregando) const Positioned.fill(child: _CarregandoPagina()),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CarregandoPagina extends StatelessWidget {
  const _CarregandoPagina();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.cores.fundo,
      child: const Padding(
        padding: EdgeInsets.all(AppMedidas.margem),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Skeleton(largura: 180, altura: 20),
            SizedBox(height: 16),
            Skeleton(altura: 48, raio: AppMedidas.raioBotao),
            SizedBox(height: 12),
            Skeleton(altura: 48, raio: AppMedidas.raioBotao),
            SizedBox(height: 20),
            Skeleton(largura: 140, altura: 44, raio: AppMedidas.raioBotao),
          ],
        ),
      ),
    );
  }
}
