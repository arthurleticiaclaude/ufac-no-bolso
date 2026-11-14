import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screen_brightness/screen_brightness.dart';

import '../data/repositorio_ru.dart';
import '../theme/app_cores.dart';
import '../theme/app_medidas.dart';
import '../theme/app_texto.dart';
import '../ui/componentes.dart';
import '../ui/formatos.dart';

class TelaQr extends StatefulWidget {
  const TelaQr({super.key});

  @override
  State<TelaQr> createState() => _TelaQrState();
}

class _TelaQrState extends State<TelaQr> {
  @override
  void initState() {
    super.initState();
    vibrarLeve();
    _brilho(() => ScreenBrightness.instance.setApplicationScreenBrightness(1));
  }

  @override
  void dispose() {
    _brilho(ScreenBrightness.instance.resetApplicationScreenBrightness);
    super.dispose();
  }

  // Falhar o brilho não pode impedir de mostrar o QR.
  Future<void> _brilho(Future<void> Function() acao) async {
    try {
      await acao();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final ru = RepositorioRu.instancia;
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: ru,
          builder: (context, _) {
            final numero = ru.numeroQr;
            return ListView(
              padding: const EdgeInsets.all(AppMedidas.margem),
              children: [
                Row(
                  children: [
                    BotaoRedondo(
                      icone: Icons.close_rounded,
                      descricao: 'Fechar',
                      aoTocar: () => Navigator.of(context).pop(),
                    ),
                    const Spacer(),
                    Selo(texto: 'Brilho no máximo', cor: c.chipTexto, fundo: c.chipFundo),
                  ],
                ),
                const SizedBox(height: 18),
                Text('QR do RU', style: AppTexto.tituloTela, textAlign: TextAlign.center),
                const SizedBox(height: 2),
                Text(
                  'Aponte para o leitor na entrada',
                  style: AppTexto.apoio.copyWith(color: c.secundario),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                if (numero == null)
                  Cartao(
                    child: ru.carregando
                        ? const Center(child: Skeleton(largura: 250, altura: 250, raio: AppMedidas.raioBotao))
                        : EstadoVazio(
                            icone: Icons.qr_code_2_rounded,
                            titulo: 'Ainda não consegui ler seu QR',
                            texto: 'Toque em Atualizar QR com internet e a sessão do eTICKET ativa.',
                          ),
                  )
                else
                  _CartaoQr(numero: numero),
                const SizedBox(height: 14),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (ru.saldo != null)
                      Selo(
                        texto: 'Saldo ${formatarMoeda(ru.saldo!)}',
                        cor: c.navAtivo,
                        fundo: c.navAtivoFundo,
                      ),
                    if (numero != null) Selo(texto: 'Funciona offline', cor: c.verde, fundo: c.verdeFundo),
                  ],
                ),
                if (ru.falhou) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Não consegui falar com o eTICKET agora.',
                    style: AppTexto.apoio.copyWith(color: c.secundario),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 18),
                BotaoContorno(
                  texto: ru.carregando ? 'Atualizando…' : 'Atualizar QR',
                  icone: Icons.refresh_rounded,
                  cor: c.navAtivo,
                  aoTocar: ru.atualizar,
                ),
                const SizedBox(height: 12),
                Text(
                  'Não compartilhe prints desta tela',
                  style: AppTexto.rotulo.copyWith(color: c.secundario),
                  textAlign: TextAlign.center,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CartaoQr extends StatelessWidget {
  const _CartaoQr({required this.numero});

  final String numero;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    return Cartao(
      cor: c.qrFundo,
      child: Column(
        children: [
          QrImageView(
            data: numero,
            size: 250,
            backgroundColor: c.qrFundo,
            eyeStyle: QrEyeStyle(eyeShape: QrEyeShape.square, color: c.qrTinta),
            dataModuleStyle: QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: c.qrTinta),
          ),
          const SizedBox(height: 10),
          Text(mascararNumero(numero), style: AppTexto.corpoForte.copyWith(color: c.qrTinta)),
        ],
      ),
    );
  }
}
