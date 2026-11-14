import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:pdfx/pdfx.dart';
import 'package:share_plus/share_plus.dart';

import '../theme/app_medidas.dart';
import '../theme/app_texto.dart';
import '../ui/componentes.dart';

/// Abre a tela "salvar como" do Android. Devolve true se a pessoa salvou.
Future<bool> salvarPdf(File arquivo) async {
  final destino = await FlutterFileDialog.saveFile(params: SaveFileDialogParams(sourceFilePath: arquivo.path));
  return destino != null;
}

/// Visualizador dentro do app. O arquivo temporário é apagado ao fechar.
class TelaPdf extends StatefulWidget {
  const TelaPdf({super.key, required this.arquivo, required this.titulo});

  final File arquivo;
  final String titulo;

  @override
  State<TelaPdf> createState() => _TelaPdfState();
}

class _TelaPdfState extends State<TelaPdf> {
  late final _controle = PdfControllerPinch(document: PdfDocument.openFile(widget.arquivo.path));

  @override
  void dispose() {
    _controle.dispose();
    widget.arquivo.delete().ignore();
    super.dispose();
  }

  Future<void> _salvar() async {
    final mensageiro = ScaffoldMessenger.of(context);
    if (await salvarPdf(widget.arquivo)) {
      mensageiro.showSnackBar(const SnackBar(content: Text('PDF salvo.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              child: Row(
                children: [
                  BotaoRedondo(
                    icone: Icons.close_rounded,
                    descricao: 'Fechar',
                    aoTocar: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(widget.titulo, style: AppTexto.corpoForte, maxLines: 2)),
                  const SizedBox(width: 8),
                  BotaoRedondo(
                    icone: Icons.share_rounded,
                    descricao: 'Compartilhar',
                    aoTocar: () => SharePlus.instance.share(ShareParams(files: [XFile(widget.arquivo.path)])),
                  ),
                  const SizedBox(width: AppMedidas.entreCartoes / 2),
                  BotaoRedondo(icone: Icons.download_rounded, descricao: 'Salvar', aoTocar: _salvar),
                ],
              ),
            ),
            Expanded(child: PdfViewPinch(controller: _controle)),
          ],
        ),
      ),
    );
  }
}
