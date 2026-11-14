# UFAC+ para Android

Projeto Flutter do app Android. Regras e estado do projeto: [`../CLAUDE.md`](../CLAUDE.md). Decisões e reconhecimento dos sites da Ufac: [`../docs/`](../docs/).

```bash
cd android
flutter test --exclude-tags visual
flutter build apk --release --dart-define-from-file=.env.json
```

O `.env.json`, a chave de assinatura (`android/key.properties` + `.jks`) e `fixtures/raw/` ficam fora do git.
