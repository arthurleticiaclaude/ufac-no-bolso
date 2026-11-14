import 'dart:io';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:path/path.dart' as caminho;
import 'package:path_provider/path_provider.dart';

import '../config.dart';
import '../data/repositorio_portal.dart';
import 'baixar_pdf.dart';

enum StatusPdf { pronto, sessaoExpirada, semConexao }

class ResultadoPdf {
  const ResultadoPdf(this.status, [this.arquivo]);
  final StatusPdf status;
  final File? arquivo;
}

/// Baixa para a pasta temporária do app. Quem pede apaga depois de usar.
class ServicoPdf {
  static Future<Directory> _pasta() async {
    final pasta = Directory(caminho.join((await getTemporaryDirectory()).path, 'pdfs'));
    return pasta.create(recursive: true);
  }

  static Future<ResultadoPdf> deEndereco(Uri endereco, String nomeArquivo) async {
    try {
      final cookies = await CookieManager.instance().getCookies(url: WebUri.uri(endereco));
      final cabecalho = cookies.map((c) => '${c.name}=${c.value}').join('; ');
      final bytes = await baixarPdf(endereco, cabecalho);
      if (bytes == null) return const ResultadoPdf(StatusPdf.sessaoExpirada);
      final arquivo = File(caminho.join((await _pasta()).path, nomeArquivo));
      await arquivo.writeAsBytes(bytes, flush: true);
      return ResultadoPdf(StatusPdf.pronto, arquivo);
    } on IOException {
      return const ResultadoPdf(StatusPdf.semConexao);
    }
  }

  static Future<ResultadoPdf> deRelatorio(RelatorioPortal relatorio) async {
    final id = await RepositorioPortal.instancia.garantirIdInterno();
    if (id == null) return const ResultadoPdf(StatusPdf.sessaoExpirada);
    return deEndereco(Uri.parse(relatorio.url(id)), relatorio.arquivo);
  }

  /// Sobra de uma sessão anterior (app fechado à força com um PDF aberto).
  static Future<void> limparTemporarios() async {
    final pasta = await _pasta();
    await pasta.delete(recursive: true);
  }
}
