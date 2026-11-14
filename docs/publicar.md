# Como publicar uma nova versão

## A chave de assinatura
- Fica fora do repositório (caminho no `CLAUDE.local.md` de quem publica): o arquivo `ufac_no_bolso.jks` e o `key.properties`, que tem a senha.
- O Android só atualiza por cima se o APK novo tiver a **mesma chave**. Se ela se perder, todo mundo precisa desinstalar o app e instalar de novo, perdendo o login e os dados salvos.

### Backup (faça agora)
1. Copie a pasta `ufac_no_bolso` inteira para **dois** lugares fora deste PC, como um pendrive e um armazenamento na nuvem protegido.
2. Quem tem esses dois arquivos pode assinar um app que se passa pelo seu. Nunca envie por chat ou e-mail, e nunca coloque em repositório.
3. Em PC novo: copie a pasta, ajuste o caminho de `storeFile` no `key.properties` e copie esse arquivo para `android/key.properties`.

## Configuração do build
O arquivo `.env.json`, na raiz do projeto, fica fora do git:

```json
{
  "CONTATO_EMAIL": "opcional: e-mail de contato",
  "ATUALIZACOES_REPO": "dono/nome-do-repositorio"
}
```

**Atenção:** esses valores vão dentro do APK, e o APK fica público nas Releases. Qualquer pessoa pode baixá-lo e extrair o e-mail.

## Passo a passo de cada versão
1. Em `pubspec.yaml`, aumente `version`. Exemplo: de `0.1.0+1` para `0.2.0+2`. O número depois do `+` tem que subir sempre.
2. Rode os testes:
   ```bash
   C:\dev\flutter_sdk\bin\flutter test
   ```
3. Gere o APK:
   ```bash
   C:\dev\flutter_sdk\bin\flutter build apk --release --dart-define-from-file=.env.json
   ```
4. O arquivo sai em `build/app/outputs/flutter-apk/app-release.apk`.
5. No GitHub, crie uma Release com a etiqueta `v0.2.0` e anexe o APK. Publique só o APK e as notas da versão.
6. **Não marque "Pre-release"**: o app só enxerga a versão marcada como "latest". O APK tem 52 MB, então quem anexa é você (a extensão do Chrome envia no máximo 10 MB).

O app confere as novas versões ao abrir (no máximo uma vez por dia) e no botão "Verificar atualizações".
