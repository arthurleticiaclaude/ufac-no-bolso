import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../config.dart';
import '../data/repositorio_ru.dart';
import '../session/regras_sessao.dart';
import '../theme/app_cores.dart';
import '../theme/app_medidas.dart';
import '../theme/app_texto.dart';
import '../ui/componentes.dart';

/// Fluxo oficial de recarga do eTICKET, dentro do app. Quem conclui o pagamento é a pessoa (regra 4).
class TelaRecarga extends StatefulWidget {
  const TelaRecarga({super.key});

  @override
  State<TelaRecarga> createState() => _TelaRecargaState();
}

class _TelaRecargaState extends State<TelaRecarga> {
  bool _carregando = true;
  bool _falhou = false;
  int _tentativa = 0;

  @override
  void dispose() {
    RepositorioRu.instancia.atualizar();
    super.dispose();
  }

  // O pagamento pode passar por outro site seguro; só http e endereços estranhos ficam de fora.
  Future<NavigationActionPolicy> _aoNavegar(InAppWebViewController controle, NavigationAction acao) async {
    final destino = acao.request.url;
    if (destino == null) return NavigationActionPolicy.CANCEL;
    final https = versaoHttps(destino);
    if (https != null) {
      await controle.loadUrl(urlRequest: URLRequest(url: WebUri.uri(https)));
      return NavigationActionPolicy.CANCEL;
    }
    return destino.scheme == 'https' ? NavigationActionPolicy.ALLOW : NavigationActionPolicy.CANCEL;
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
                        Text('Recarregar créditos', style: AppTexto.tituloCartao),
                        Text('Fluxo oficial do eTICKET', style: AppTexto.rotulo.copyWith(color: c.secundario)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _falhou
                  ? EstadoVazio(
                      icone: Icons.wifi_off_rounded,
                      titulo: 'Não consegui abrir o eTICKET agora',
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
                          key: ValueKey(_tentativa),
                          initialUrlRequest: URLRequest(url: WebUri(urlRecarga)),
                          initialSettings: InAppWebViewSettings(
                            useShouldOverrideUrlLoading: true,
                            mixedContentMode: MixedContentMode.MIXED_CONTENT_NEVER_ALLOW,
                          ),
                          shouldOverrideUrlLoading: _aoNavegar,
                          onLoadStop: (_, _) {
                            if (mounted) setState(() => _carregando = false);
                          },
                          onReceivedError: (_, pedido, erro) {
                            if (pedido.isForMainFrame == true && erro.type != WebResourceErrorType.CANCELLED && mounted) {
                              setState(() => _falhou = true);
                            }
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
