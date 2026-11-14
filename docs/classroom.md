# Google Classroom no UFAC+: passo a passo

**Objetivo:** mostrar na Início as atividades do Classroom que vencem na semana.
**Como:** pela API oficial do Google. Os dados vão do Google direto para o celular, sem servidor no meio (regra 3).

O primeiro teste responde a pergunta principal: **a Ufac deixa um app de fora ler o Classroom das contas da Ufac?** Se não deixar, paramos no passo 6, sem ter escrito código.

---

## Antes de começar
- Use **uma conta Google pessoal** (por exemplo, o seu Gmail) para criar o projeto. Não use o e-mail da Ufac: a Ufac pode bloquear criação de projetos nas contas dela.
- Tudo é **gratuito**. O Google pode pedir um cartão só em alguns casos; se pedir, pare e me avise (não precisa de cartão para isto).

## 1. Criar o projeto
1. Abra **console.cloud.google.com** com a conta pessoal.
2. No topo, clique no seletor de projeto → **Novo projeto**.
3. Nome: `UFAC+`. Organização: **Sem organização**. Clique em **Criar**.
4. Confira no topo se o projeto selecionado é o `UFAC+`.

## 2. Ativar a API do Classroom
1. No menu ☰ → **APIs e serviços** → **Biblioteca**.
2. Procure **Google Classroom API** e clique em **Ativar**.

## 3. Tela de consentimento (o que aparece quando a pessoa entra com o Google)
1. Menu ☰ → **APIs e serviços** → **Tela de permissão OAuth** (pode aparecer como **Google Auth Platform**). Clique em **Começar**.
2. **Informações do app**
   - Nome do app: `UFAC+`
   - E-mail de suporte: o seu Gmail pessoal
3. **Público:** escolha **Externo**. (A opção "Interno" só existe para contas da própria Ufac.)
4. **Dados de contato:** o seu Gmail pessoal.
5. Aceite a política de dados do Google e clique em **Criar**.

## 4. Escopos (o que o app pode ler)
1. Em **Acesso a dados** (ou **Escopos**), clique em **Adicionar ou remover escopos**.
2. Marque só estes dois (somente leitura):
   - `https://www.googleapis.com/auth/classroom.courses.readonly` (ver as turmas)
   - `https://www.googleapis.com/auth/classroom.coursework.me.readonly` (ver as suas atividades e prazos)
3. Salve. **Não** adicione nenhum outro.

## 5. Usuários de teste
1. Em **Público** → **Usuários de teste** → **Adicionar usuários**.
2. Coloque o **seu e-mail da Ufac**, o que você usa no Classroom.
3. Depois você pode acrescentar os e-mails da Ufac dos seus amigos (limite de 100).

## 6. Credencial do app Android
1. Em **Clientes** (ou **Credenciais** → **Criar credenciais** → **ID do cliente OAuth**).
2. Tipo de aplicativo: **Android**.
3. Nome: `UFAC+ Android`.
4. Nome do pacote:
   ```
   io.github.ufacnobolso.ufac_no_bolso
   ```
5. Impressão digital SHA-1:
   ```
   7D:85:A3:3B:3D:30:45:02:4A:20:CD:0A:81:53:EC:F1:CD:60:8E:BA
   ```
   É a impressão pública da chave fixa do app. Não é segredo e não dá acesso a nada.
6. Clique em **Criar**.

## 7. Me avise
Me mande **só** o **ID do cliente** que aparece no fim (termina em `.apps.googleusercontent.com`). Ele não é segredo.
**Nunca** mande "chave secreta", "client secret", arquivo JSON de conta de serviço, senha ou código de verificação.

---

## O que acontece depois
1. Eu faço uma versão de teste que só tenta entrar com o Google e listar suas turmas.
2. No celular, ao tocar em "Conectar Classroom", aparece a tela do Google:
   - **"O Google não verificou este app"** → é normal num app pessoal. Toque em **Avançado** → **Acessar UFAC+ (não seguro)**. O aviso existe porque o app não passou pela revisão do Google, não porque faz algo errado.
   - **"Acesso bloqueado"** ou **"Seu administrador bloqueou"** citando a Ufac → a Ufac não libera apps de fora. Aí não tem como fazer pelo caminho oficial, e paramos.
3. Se funcionar, eu faço o cartão "Atividades da semana" na Início.

## Limites que você precisa saber
- **Modo de teste:** só entra quem estiver na lista de usuários de teste. O Google também pode pedir para a pessoa autorizar de novo depois de alguns dias.
- **Para não precisar autorizar de novo:** dá para mudar o app para "Em produção" sem passar pela verificação. O aviso de "não verificado" continua, e o limite de 100 pessoas também. Decidimos isso depois do teste.
- **Privacidade:** o app pede só leitura das turmas e das suas atividades. Não lê e-mail, Drive nem notas do Classroom.
