# Funcionalidades futuras (ainda não implementadas)

Ideias combinadas entre Matheus e Arthur. Valem para o PWA do iPhone e, se der certo, para o app Android.
Nada aqui está pronto; cada item diz o que já se sabe e o que falta descobrir.

## 1. Pesquisa no acervo da Biblioteca

**O que é:** buscar livros no acervo da Ufac por título, autor ou assunto e ver em qual biblioteca está e
quantos exemplares existem.

**O que já se sabe (conferido em 12/11/2026):**
- A pesquisa é **pública**: não precisa de login. É um formulário GET:
  `https://portal.ufac.br/biblioteca/pesquisa/resultado.action?keyword=<termo>`.
- O Worker já aceita esse endereço (`/portal/biblioteca/...`, host `portal.ufac.br`), então não há nada novo do lado
  do servidor.
- A resposta é uma tabela HTML com as colunas `#`, Autor, Título, Ano e Biblioteca (ex.: "Biblioteca Central").
- A página é pesada: uma busca por "direito civil" devolveu ~600 KB e levou ~3 s. O texto vem sem acento em parte
  dos registros antigos ("Informacao Obrigatoria", "arbritagem").
- Sistema ASTEN (o mesmo do Portal). Mapa completo em `docs/reconhecimento.md`, seção "Biblioteca".

**Como seria no app:**
- Item "Biblioteca" no Menu (☰) abre uma tela com campo de busca e a lista de resultados (autor, título, ano, biblioteca).
- Um extrator novo em `web/src/lib/extratores/biblioteca.js`, com fixture anonimizada (a busca é pública, não tem
  dado pessoal) e teste, como os outros.
- Respeito à Ufac: buscar só quando a pessoa toca em "Buscar" (nada de busca a cada letra); guardar as últimas
  buscas no cache por algumas horas; mostrar só os primeiros resultados e "Ver mais" se a página trouxer muitos.
- Cuidado: o Worker devolve a página inteira (600 KB). Se pesar no 4G, o Worker pode recortar só a tabela antes
  de devolver.

**O que falta descobrir:**
- Se há paginação ou se a página sempre traz tudo.
- Se dá para filtrar por campo (autor, título) e por biblioteca (o formulário de `pesquisar.action` tem mais campos?).
- Se existe página de detalhe do título com exemplares disponíveis/emprestados e número de chamada (localização na
  estante). Isso é o mais útil para quem vai buscar o livro.

**Depois (precisa de login):** Meu Espaço, Renovação, Reservas e Histórico. Em 10/11 essas páginas davam erro 500;
em 11/11 abriram na conta do Arthur. Renovar livro é ação que muda dado: só com confirmação livro a livro.

## 2. Horário dos ônibus no campus

**O que é:** mostrar quando passa o próximo ônibus no campus da Ufac (linhas 501, 502 e 902, com a 902-1 agrupada).

**O que já se sabe:**
- Não há dado público de posição em tempo real nem API de horários em Rio Branco (`docs/decisoes.md`, 10/11/2026).
- Então a única forma viável é uma **tabela fixa** de horários, digitada a partir da tabela oficial.

**Como seria no app:**
- Um arquivo de horários fácil de editar (ex.: `web/src/lib/dominio/onibus.js`), com dias úteis, sábado e domingo
  separados e a data da tabela ("horários de [data]").
- Cartão "Próximo ônibus" (opcional) na Início, e uma tela com a tabela completa por linha.
- Sempre avisar que é a tabela oficial e pode haver atraso; nunca dizer "o ônibus está chegando".
- Feriados: usar a lista de feriados que o app já tem para mostrar a tabela de domingo/feriado.

**O que falta:**
- Conseguir a tabela oficial (RBTrans / Prefeitura de Rio Branco ou as empresas das linhas) e a data dela.
- Saber qual parada fica dentro do campus e se os horários são de saída do terminal ou de passagem no campus.
- Definir quem atualiza a tabela quando ela mudar (a cada mudança, nova versão do app).
