import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as caminho;
import 'package:path_provider/path_provider.dart';

import '../config.dart';

class VersaoPublicada {
  const VersaoPublicada(this.versao, this.urlApk);
  final String versao, urlApk;
}

/// Compara "0.2.0" com "0.1.9". Aceita o "v" que costuma vir na etiqueta do GitHub.
bool versaoEhMaior(String nova, String atual) {
  List<int> partes(String v) => v
      .replaceFirst(RegExp(r'^v'), '')
      .split('+')
      .first
      .split('.')
      .map((p) => int.tryParse(p) ?? 0)
      .toList();
  final a = partes(nova), b = partes(atual);
  for (var i = 0; i < a.length || i < b.length; i++) {
    final x = i < a.length ? a[i] : 0, y = i < b.length ? b[i] : 0;
    if (x != y) return x > y;
  }
  return false;
}

/// Lê a resposta do GitHub. Só aceita APK baixado do próprio GitHub, por https.
VersaoPublicada? lerVersaoPublicada(Map<String, dynamic> dados) {
  final etiqueta = dados['tag_name'];
  final anexos = dados['assets'];
  if (etiqueta is! String || anexos is! List) return null;
  for (final anexo in anexos) {
    if (anexo is! Map) continue;
    final nome = anexo['name'], url = anexo['browser_download_url'];
    if (nome is String && url is String && nome.endsWith('.apk') && url.startsWith('https://github.com/')) {
      return VersaoPublicada(etiqueta.replaceFirst(RegExp(r'^v'), ''), url);
    }
  }
  return null;
}

enum ResultadoAtualizacao { atualizado, haNova, semConfiguracao, semResposta }

/// Pergunta só qual é a última versão publicada. Não envia nenhum dado da pessoa.
class Atualizacoes extends ChangeNotifier {
  Atualizacoes._();
  static final instancia = Atualizacoes._();

  static const _cofre = FlutterSecureStorage();
  static const _chaveUltima = 'atualizacao_verificada_em';

  VersaoPublicada? nova;
  bool baixando = false;

  Future<ResultadoAtualizacao> verificar() async {
    if (repositorioAtualizacoes.isEmpty) return ResultadoAtualizacao.semConfiguracao;
    final cliente = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    try {
      final pedido = await cliente.getUrl(
        Uri.https('api.github.com', '/repos/$repositorioAtualizacoes/releases/latest'),
      );
      pedido.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
      pedido.headers.set(HttpHeaders.userAgentHeader, 'ufac-no-bolso');
      final resposta = await pedido.close();
      if (resposta.statusCode != HttpStatus.ok) {
        await resposta.drain<void>();
        return ResultadoAtualizacao.semResposta;
      }
      final corpo = await resposta.transform(utf8.decoder).join();
      final publicada = lerVersaoPublicada(jsonDecode(corpo) as Map<String, dynamic>);
      if (publicada == null) return ResultadoAtualizacao.semResposta;
      final instalada = (await PackageInfo.fromPlatform()).version;
      await _cofre.write(key: _chaveUltima, value: DateTime.now().toIso8601String());
      nova = versaoEhMaior(publicada.versao, instalada) ? publicada : null;
      notifyListeners();
      return nova == null ? ResultadoAtualizacao.atualizado : ResultadoAtualizacao.haNova;
    } on IOException {
      return ResultadoAtualizacao.semResposta;
    } on FormatException {
      return ResultadoAtualizacao.semResposta;
    } finally {
      cliente.close();
    }
  }

  /// Ao abrir o app, no máximo uma vez por dia.
  Future<void> aoAbrirApp() async {
    if (repositorioAtualizacoes.isEmpty) return;
    final ultima = DateTime.tryParse(await _cofre.read(key: _chaveUltima) ?? '');
    if (ultima != null && DateTime.now().difference(ultima) < const Duration(days: 1)) return;
    await verificar();
  }

  /// Baixa e abre o instalador do Android. Quem confirma a instalação é a pessoa.
  Future<bool> baixarEInstalar() async {
    final versao = nova;
    if (versao == null || baixando) return false;
    baixando = true;
    notifyListeners();
    final cliente = HttpClient();
    try {
      final pasta = await Directory(caminho.join((await getTemporaryDirectory()).path, 'atualizacao')).create();
      final arquivo = File(caminho.join(pasta.path, 'ufac_no_bolso.apk'));
      final resposta = await (await cliente.getUrl(Uri.parse(versao.urlApk))).close();
      if (resposta.statusCode != HttpStatus.ok) return false;
      await resposta.pipe(arquivo.openWrite());
      final resultado = await OpenFilex.open(arquivo.path, type: 'application/vnd.android.package-archive');
      return resultado.type == ResultType.done;
    } on IOException {
      return false;
    } finally {
      cliente.close();
      baixando = false;
      notifyListeners();
    }
  }
}
