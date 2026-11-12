# UFAC+

**Portal do Aluno e RU da Ufac num app só:** seus dados, horários, notas, relatórios em PDF, saldo do RU, QR de entrada (funciona offline) e cardápio.

> App independente, feito por alunos. **Não é um aplicativo oficial da Ufac.**

## Baixar

| | Android | iPhone |
|---|---|---|
| **Como instalar** | Baixe o `.apk` da release **[Latest](https://github.com/arthurleticiaclaude/ufac-no-bolso/releases/latest)** e permita "instalar apps desta fonte". | Abra **[ufac-plus-ios.pages.dev/instalar](https://ufac-plus-ios.pages.dev/instalar/)** no Safari e toque em **Compartilhar › Adicionar à Tela de Início**. |
| **Atualizações** | Pela faixa "Nova versão disponível" na tela Início. | Sozinho, ao abrir o app. |
| **Notas das versões** | Release **[Latest](https://github.com/arthurleticiaclaude/ufac-no-bolso/releases/latest)**, seção Android | Release **[Latest](https://github.com/arthurleticiaclaude/ufac-no-bolso/releases/latest)**, seção iPhone |

As duas versões fazem a mesma coisa, mas são apps diferentes por dentro: no Android, um app instalado pelo `.apk`; no iPhone, um app da web que se instala pelo Safari (sem App Store). Por isso a release do iPhone não tem arquivo para baixar.

## Código-fonte

O código é aberto para quem quiser conferir o que o app faz com os seus dados.

| Pasta | O quê |
|---|---|
| [`iphone/`](iphone/) | App do iPhone (app da web em JavaScript, com Vite) e o servidor de repasse (Cloudflare Worker). Como rodar e testar: [`iphone/README.md`](iphone/README.md). |
| *(em breve)* | App do Android (Flutter), numa pasta própria. |

Cada versão fica separada na sua pasta: uma não mexe na outra. Os testes usam só páginas de exemplo com dados fictícios (`iphone/fixtures/`). Senhas, chaves e dados reais nunca entram no repositório.

## Privacidade

As senhas vão direto para a Ufac e o app não as guarda. Os dados lidos ficam só no celular de quem usa. Nada de anúncios ou rastreamento.
