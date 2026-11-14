import 'dart:io';
import 'dart:typed_data';

import '../session/regras_sessao.dart';

const _maxRedirecionamentos = 5;

bool ehPdf(List<int> bytes) =>
    bytes.length > 4 && bytes[0] == 0x25 && bytes[1] == 0x50 && bytes[2] == 0x44 && bytes[3] == 0x46;

/// Baixa um PDF com os cookies da sessão, sem passar por nenhum servidor além do da Ufac.
/// Devolve null se a resposta não for PDF, que é o que acontece quando a sessão caiu.
/// O cookie só vai para o mesmo endereço do pedido e nunca para log.
Future<Uint8List?> baixarPdf(Uri endereco, String cookies, {HttpClient? cliente}) async {
  final http = cliente ?? HttpClient();
  try {
    var atual = versaoHttps(endereco) ?? endereco;
    for (var i = 0; i < _maxRedirecionamentos; i++) {
      final pedido = await http.getUrl(atual);
      pedido.followRedirects = false;
      if (atual.host == endereco.host) pedido.headers.set(HttpHeaders.cookieHeader, cookies);
      final resposta = await pedido.close();
      if (resposta.isRedirect) {
        await resposta.drain<void>();
        final destino = resposta.headers.value(HttpHeaders.locationHeader);
        if (destino == null) return null;
        final proximo = atual.resolve(destino);
        atual = versaoHttps(proximo) ?? proximo;
        continue;
      }
      if (resposta.statusCode != HttpStatus.ok) {
        await resposta.drain<void>();
        return null;
      }
      final dados = BytesBuilder(copy: false);
      await resposta.forEach(dados.add);
      final bytes = dados.takeBytes();
      return ehPdf(bytes) ? bytes : null;
    }
    return null;
  } finally {
    if (cliente == null) http.close();
  }
}
