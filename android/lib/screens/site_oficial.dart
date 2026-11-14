import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../pdf/servico_pdf.dart';
import '../session/regras_sessao.dart';
import '../theme/app_cores.dart';
import '../theme/app_medidas.dart';
import '../theme/app_texto.dart';
import '../ui/componentes.dart';
import 'pdf.dart';

/// Página oficial da Ufac dentro do app, para o que o app não cobre. Se a sessão caiu, a própria página pede o login.
class TelaSiteOficial extends StatefulWidget {
  const TelaSiteOficial({super.key, required this.titulo, required this.endereco, this.jsAoCarregar, this.dica});

  final String titulo, endereco;

  /// Roda depois de cada carregamento. Só para abrir algo da própria página, nunca para ler dados.
  final String? jsAoCarregar;

  /// Instrução curta acima da página, para quem vai fazer algo nela (ex.: a chamada).
  final String? dica;

  @override
  State<TelaSiteOficial> createState() => _TelaSiteOficialState();
}

class _TelaSiteOficialState extends State<TelaSiteOficial> {
  bool _carregando = true;

  Future<NavigationActionPolicy> _aoNavegar(InAppWebViewController controle, NavigationAction acao) async {
    final destino = acao.request.url;
    if (destino == null) return NavigationActionPolicy.CANCEL;
    // Conteúdo embutido na página oficial, como o calendário, pode vir de fora da Ufac.
    if (!acao.isForMainFrame) {
      return destino.scheme == 'https' ? NavigationActionPolicy.ALLOW : NavigationActionPolicy.CANCEL;
    }
    final https = versaoHttps(destino);
    if (https != null) {
      await controle.loadUrl(urlRequest: URLRequest(url: WebUri.uri(https)));
      return NavigationActionPolicy.CANCEL;
    }
    return ehSiteDaUfac(destino) && destino.scheme == 'https'
        ? NavigationActionPolicy.ALLOW
        : NavigationActionPolicy.CANCEL;
  }

  Future<void> _aoBaixar(DownloadStartRequest pedido) async {
    final navegador = Navigator.of(context);
    final mensageiro = ScaffoldMessenger.of(context);
    if (!ehSiteDaUfac(pedido.url)) return;
    final resultado = await ServicoPdf.deEndereco(pedido.url, 'relatorio_portal.pdf');
    final arquivo = resultado.arquivo;
    if (arquivo == null) {
      mensageiro.showSnackBar(const SnackBar(content: Text('Não consegui abrir esse relatório no app.')));
      return;
    }
    navegador.push(MaterialPageRoute(builder: (_) => TelaPdf(arquivo: arquivo, titulo: 'Relatório do Portal')));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
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
                        Text(widget.titulo, style: AppTexto.tituloCartao),
                        Text('Página oficial da Ufac', style: AppTexto.rotulo.copyWith(color: c.secundario)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (widget.dica != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(AppMedidas.margem, 0, AppMedidas.margem, 10),
                child: FaixaAviso(icone: Icons.info_rounded, texto: widget.dica!),
              ),
            Expanded(
              child: Stack(
                children: [
                  InAppWebView(
                    initialUrlRequest: URLRequest(url: WebUri(widget.endereco)),
                    initialSettings: InAppWebViewSettings(
                      useShouldOverrideUrlLoading: true,
                      useOnDownloadStart: true,
                      supportZoom: true,
                      builtInZoomControls: true,
                      displayZoomControls: false,
                      useWideViewPort: true,
                      loadWithOverviewMode: true,
                      mixedContentMode: MixedContentMode.MIXED_CONTENT_NEVER_ALLOW,
                    ),
                    shouldOverrideUrlLoading: _aoNavegar,
                    onDownloadStarting: (_, pedido) {
                      _aoBaixar(pedido);
                      return DownloadStartResponse(handled: true);
                    },
                    onLoadStop: (controle, _) {
                      final js = widget.jsAoCarregar;
                      if (js != null) controle.evaluateJavascript(source: js);
                      if (mounted) setState(() => _carregando = false);
                    },
                  ),
                  if (_carregando)
                    Positioned.fill(
                      child: ColoredBox(
                        color: c.fundo,
                        child: const Padding(
                          padding: EdgeInsets.all(AppMedidas.margem),
                          child: Column(
                            children: [
                              Skeleton(altura: 48, raio: AppMedidas.raioBotao),
                              SizedBox(height: 16),
                              Skeleton(altura: 48, raio: AppMedidas.raioBotao),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
