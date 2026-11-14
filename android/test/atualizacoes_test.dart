import 'package:flutter_test/flutter_test.dart';
import 'package:ufac_no_bolso/data/atualizacoes.dart';

void main() {
  group('versaoEhMaior', () {
    test('compara numero por numero, nao como texto', () {
      expect(versaoEhMaior('0.10.0', '0.9.0'), isTrue);
      expect(versaoEhMaior('1.0.0', '0.9.9'), isTrue);
      expect(versaoEhMaior('0.1.1', '0.1.0'), isTrue);
    });
    test('igual ou menor nao oferece atualizacao', () {
      expect(versaoEhMaior('0.1.0', '0.1.0'), isFalse);
      expect(versaoEhMaior('0.1.0', '0.2.0'), isFalse);
    });
    test('aceita v na etiqueta e partes faltando', () {
      expect(versaoEhMaior('v0.2.0', '0.1.0'), isTrue);
      expect(versaoEhMaior('0.2', '0.2.0'), isFalse);
    });
  });

  group('lerVersaoPublicada', () {
    Map<String, dynamic> release(String nome, String url) => {
          'tag_name': 'v0.2.0',
          'assets': [
            {'name': 'notas.txt', 'browser_download_url': 'https://github.com/x/y/notas.txt'},
            {'name': nome, 'browser_download_url': url},
          ],
        };
    test('acha o APK', () {
      final v = lerVersaoPublicada(release('app-release.apk', 'https://github.com/x/y/app.apk'))!;
      expect(v.versao, '0.2.0');
      expect(v.urlApk, endsWith('app.apk'));
    });
    test('recusa APK fora do GitHub ou sem https', () {
      expect(lerVersaoPublicada(release('app.apk', 'https://exemplo.com/app.apk')), isNull);
      expect(lerVersaoPublicada(release('app.apk', 'http://github.com/x/app.apk')), isNull);
    });
    test('resposta estranha nao quebra', () {
      expect(lerVersaoPublicada({'message': 'Not Found'}), isNull);
      expect(lerVersaoPublicada({'tag_name': 'v1', 'assets': []}), isNull);
    });
  });
}
