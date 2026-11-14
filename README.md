# UFAC+

**Portal do Aluno e RU da Ufac num app só:** seus dados, horários, notas, relatórios em PDF, saldo do RU, QR de entrada (funciona offline), cardápio e as atividades do Google Classroom. Tem também um perfil para professores.

> App independente, feito por alunos. **Não é um aplicativo oficial da Ufac.**

## Baixar

| | Android | iPhone |
|---|---|---|
| **Como instalar** | Baixe o `.apk` da release **[Latest](https://github.com/ufac-plus/ufac-plus/releases/latest)** e permita "instalar apps desta fonte". | Abra **[ufac-plus-ios.pages.dev/instalar](https://ufac-plus-ios.pages.dev/instalar/)** no Safari e toque em **Compartilhar › Adicionar à Tela de Início**. |
| **Atualizações** | Pela faixa "Nova versão disponível" na tela Início. | Sozinho, ao abrir o app. |
| **Notas das versões** | [Releases "UFAC+ Android"](https://github.com/ufac-plus/ufac-plus/releases) | [Releases "UFAC+ iPhone"](https://github.com/ufac-plus/ufac-plus/releases) |

Ou abra **[ufac-plus.github.io/ufac-plus](https://ufac-plus.github.io/ufac-plus/)** no celular: a página mostra a versão certa para ele.

## Privacidade

- O login é sempre no ID Ufac. Os dados lidos (notas, horários, saldo, QR) ficam só no celular de quem usa.
- Nada de anúncios, rastreamento ou servidor que guarde seus dados.
- **Android:** se você ligar "Entrar sozinho quando a sessão cair", o CPF e a senha ficam cifrados no cofre do próprio celular e só vão para o site da Ufac. Desligado, o app não guarda a senha.
- Detalhes: [política do Android](https://ufac-plus.github.io/ufac-plus/privacidade.html) · [política do iPhone](https://ufac-plus-ios.pages.dev/privacidade/).

## Achou um problema?

Abra uma [Issue](https://github.com/ufac-plus/ufac-plus/issues) dizendo o celular (Android ou iPhone), a versão do app e o que aconteceu. **Não ponha** CPF, matrícula, número do QR nem prints com seus dados: as Issues são públicas.

## Código-fonte

O código é aberto para quem quiser conferir o que o app faz com os seus dados.

| Pasta | O quê |
|---|---|
| [`android/`](android/) | App do Android (Flutter). Como rodar: [`android/README.md`](android/README.md). |
| [`iphone/`](iphone/) | App do iPhone (app da web em JavaScript, com Vite) e o servidor de repasse (Cloudflare Worker). Como rodar: [`iphone/README.md`](iphone/README.md). |
| [`docs/`](docs/) | Como os sites da Ufac funcionam, decisões do projeto e como publicar. |

Os testes usam só páginas de exemplo com dados fictícios. Senhas, chaves e dados reais nunca entram no repositório. Regras do projeto: [`CLAUDE.md`](CLAUDE.md).
