import 'package:flutter/material.dart';

import '../config.dart';
import '../data/biblioteca.dart';
import '../data/repositorio_biblioteca.dart';
import '../theme/app_cores.dart';
import '../theme/app_medidas.dart';
import '../theme/app_texto.dart';
import '../ui/componentes.dart';
import '../ui/formatos.dart';
import 'acoes_portal.dart';
import 'menu.dart';
import 'site_oficial.dart';

// Aba Biblioteca do aluno: busca no acervo, histórico de empréstimos e atalhos para
// Renovação e Reservas na página oficial (quem renova ou reserva é a pessoa, no site).

String _dia(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

class TelaBiblioteca extends StatefulWidget {
  const TelaBiblioteca({super.key});

  @override
  State<TelaBiblioteca> createState() => _TelaBibliotecaState();
}

class _TelaBibliotecaState extends State<TelaBiblioteca> {
  final _busca = TextEditingController();
  ResultadoBiblioteca? _ultimo;

  // A leitura ao abrir a aba é chamada pela Casca, só quando a pessoa toca em Biblioteca.

  @override
  void dispose() {
    _busca.dispose();
    super.dispose();
  }

  Future<void> _lerHistorico() async {
    final r = await RepositorioBiblioteca.instancia.atualizarHistorico();
    if (mounted) setState(() => _ultimo = r);
  }

  void _pesquisar() {
    final termo = _busca.text.trim();
    if (termo.length < 2) return;
    FocusScope.of(context).unfocus();
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => _TelaResultado(termo: termo)));
  }

  Future<void> _abrirOficial(String titulo, String endereco, String dica) async {
    final navegador = Navigator.of(context);
    await RepositorioBiblioteca.instancia.prepararPaginaOficial();
    navegador.push(
      MaterialPageRoute(
        builder: (_) => TelaSiteOficial(titulo: titulo, endereco: endereco, dica: dica),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    return ListenableBuilder(
      listenable: RepositorioBiblioteca.instancia,
      builder: (context, _) {
        final repo = RepositorioBiblioteca.instancia;
        final historico = repo.historico;
        final comVoce = historico?.where((e) => e.devolucao == null).toList() ?? const <EmprestimoHistorico>[];
        return ListaDaTela(
          aoAtualizar: () => _lerHistorico(),
          children: [
            CabecalhoTela(
              titulo: 'Biblioteca',
              subtitulo: 'Acervo e empréstimos · Ufac',
              acoes: [BotaoRedondo(icone: Icons.menu_rounded, descricao: 'Menu', aoTocar: () => abrirMenu(context))],
            ),
            Cartao(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Pesquisar no acervo', style: AppTexto.tituloCartao),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _busca,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _pesquisar(),
                    decoration: InputDecoration(
                      hintText: 'Título, autor ou assunto',
                      prefixIcon: const Icon(Icons.search_rounded),
                      filled: true,
                      fillColor: c.fundo,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppMedidas.raioBotao),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  BotaoDestaque(texto: 'Pesquisar', icone: Icons.search_rounded, aoTocar: _pesquisar),
                ],
              ),
            ),
            if (comVoce.isNotEmpty)
              Cartao(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconeQuadrado(icone: Icons.menu_book_rounded, cor: c.chipTexto, fundo: c.chipFundo),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            comVoce.length == 1 ? '1 livro com você' : '${comVoce.length} livros com você',
                            style: AppTexto.tituloCartao,
                          ),
                        ),
                      ],
                    ),
                    for (final e in comVoce) ...[
                      const SizedBox(height: 10),
                      Text(e.titulo, style: AppTexto.corpoForte, maxLines: 2, overflow: TextOverflow.ellipsis),
                      Text('Retirado em ${_dia(e.retirada)}', style: AppTexto.apoio.copyWith(color: c.secundario)),
                    ],
                    const SizedBox(height: 12),
                    BotaoContorno(
                      texto: 'Renovar na página oficial',
                      icone: Icons.autorenew_rounded,
                      cor: c.navAtivo,
                      aoTocar: () => _abrirOficial(
                        'Renovação',
                        urlBibliotecaRenovacao,
                        'Marque o livro e toque em Renovar. Quem confirma a renovação é você, nesta página.',
                      ),
                    ),
                  ],
                ),
              ),
            if (comVoce.isEmpty)
              ItemLista(
                icone: Icons.autorenew_rounded,
                corIcone: c.navAtivo,
                fundoIcone: c.navAtivoFundo,
                titulo: 'Renovar empréstimos',
                subtitulo: 'Página oficial da Biblioteca',
                aoTocar: () => _abrirOficial(
                  'Renovação',
                  urlBibliotecaRenovacao,
                  'Seus empréstimos aparecem aqui. Sem livro emprestado, a página volta para o Meu Espaço.',
                ),
              ),
            ItemLista(
              icone: Icons.bookmark_rounded,
              corIcone: c.navAtivo,
              fundoIcone: c.navAtivoFundo,
              titulo: 'Minhas reservas',
              subtitulo: 'Página oficial da Biblioteca',
              aoTocar: () => _abrirOficial(
                'Reservas',
                urlBibliotecaReservas,
                'Suas reservas aparecem aqui. Sem reserva, a página volta para o Meu Espaço.',
              ),
            ),
            _CartaoHistorico(
              historico: historico,
              carregando: repo.carregandoHistorico,
              ultimo: _ultimo,
              aoEntrar: () => entrarNoPortal(context, aoEntrar: () => _lerHistorico()),
              aoTentar: () => _lerHistorico(),
            ),
            if (repo.historicoLidoEm != null)
              Text(
                'Histórico atualizado em ${formatarDiaHora(repo.historicoLidoEm!)}',
                style: AppTexto.rotulo.copyWith(color: c.secundario),
                textAlign: TextAlign.center,
              ),
          ],
        );
      },
    );
  }
}

class _CartaoHistorico extends StatelessWidget {
  const _CartaoHistorico({
    required this.historico,
    required this.carregando,
    required this.ultimo,
    required this.aoEntrar,
    required this.aoTentar,
  });

  final List<EmprestimoHistorico>? historico;
  final bool carregando;
  final ResultadoBiblioteca? ultimo;
  final VoidCallback aoEntrar, aoTentar;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final lista = historico;
    final Widget corpo;
    if (lista == null && carregando) {
      corpo = const Column(
        children: [
          Skeleton(altura: 44, raio: AppMedidas.raioBotao),
          SizedBox(height: 10),
          Skeleton(altura: 44, raio: AppMedidas.raioBotao),
        ],
      );
    } else if (lista == null) {
      final expirou = ultimo == ResultadoBiblioteca.sessaoExpirada || ultimo == null;
      corpo = EstadoVazio(
        icone: Icons.history_rounded,
        titulo: expirou ? 'Ainda não li seu histórico' : 'Não consegui falar com a Biblioteca agora',
        texto: expirou
            ? 'Entre no Portal do Aluno para ver os livros que você já pegou.'
            : 'Tente de novo daqui a pouco.',
        acao: BotaoContorno(
          texto: expirou ? 'Entrar no Portal' : 'Tentar de novo',
          cor: c.navAtivo,
          aoTocar: expirou ? aoEntrar : aoTentar,
        ),
      );
    } else if (lista.isEmpty) {
      corpo = const EstadoVazio(icone: Icons.menu_book_rounded, titulo: 'Você ainda não pegou livros emprestados');
    } else {
      corpo = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < lista.length; i++) ...[
            if (i > 0) Divider(height: 1, color: c.borda),
            _LinhaEmprestimo(emprestimo: lista[i]),
          ],
        ],
      );
    }
    return Cartao(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconeQuadrado(icone: Icons.history_rounded, cor: c.navAtivo, fundo: c.navAtivoFundo),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Histórico de empréstimos', style: AppTexto.tituloCartao),
                    if (lista != null && lista.isNotEmpty)
                      Text(
                        lista.length == 1 ? '1 empréstimo' : '${lista.length} empréstimos',
                        style: AppTexto.apoio.copyWith(color: c.secundario),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          corpo,
        ],
      ),
    );
  }
}

class _LinhaEmprestimo extends StatelessWidget {
  const _LinhaEmprestimo({required this.emprestimo});

  final EmprestimoHistorico emprestimo;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final e = emprestimo;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.titulo, style: AppTexto.corpoForte, maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                  e.devolucao == null
                      ? 'Retirado em ${_dia(e.retirada)}'
                      : '${_dia(e.retirada)} a ${_dia(e.devolucao!)}',
                  style: AppTexto.apoio.copyWith(color: c.secundario),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          e.devolucao == null
              ? Selo(texto: 'Com você', cor: c.chipTexto, fundo: c.chipFundo)
              : Selo(texto: 'Devolvido', cor: c.verde, fundo: c.verdeFundo),
        ],
      ),
    );
  }
}

// ---------------- Resultado da pesquisa ----------------

class _TelaResultado extends StatefulWidget {
  const _TelaResultado({required this.termo});

  final String termo;

  @override
  State<_TelaResultado> createState() => _TelaResultadoState();
}

class _TelaResultadoState extends State<_TelaResultado> {
  late Future<(ResultadoBiblioteca, List<TituloAcervo>?)> _pedido;

  @override
  void initState() {
    super.initState();
    _pedido = RepositorioBiblioteca.instancia.pesquisar(widget.termo);
  }

  void _tentarDeNovo() => setState(() => _pedido = RepositorioBiblioteca.instancia.pesquisar(widget.termo));

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final topo = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BotaoRedondo(
          icone: Icons.arrow_back_rounded,
          descricao: 'Voltar',
          aoTocar: () => Navigator.of(context).maybePop(),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Acervo', style: AppTexto.tituloTela),
              Text('“${widget.termo}”', style: AppTexto.apoio.copyWith(color: c.secundario)),
            ],
          ),
        ),
      ],
    );
    return Scaffold(
      body: FutureBuilder(
        future: _pedido,
        builder: (context, snap) {
          if (!snap.hasData) {
            return ListaDaTela(
              children: [
                topo,
                for (var i = 0; i < 4; i++) const Skeleton(altura: 84, raio: AppMedidas.raioCartao),
              ],
            );
          }
          final (r, lista) = snap.data!;
          if (lista == null) {
            final expirou = r == ResultadoBiblioteca.sessaoExpirada;
            return ListaDaTela(
              children: [
                topo,
                Cartao(
                  child: EstadoVazio(
                    icone: expirou ? Icons.lock_clock_rounded : Icons.wifi_off_rounded,
                    titulo: expirou ? 'Sua sessão do Portal terminou' : 'Não consegui pesquisar na Biblioteca agora',
                    texto: expirou
                        ? 'Entre de novo para pesquisar no acervo.'
                        : 'Confira sua internet e tente de novo.',
                    acao: BotaoContorno(
                      texto: expirou ? 'Entrar no Portal' : 'Tentar de novo',
                      cor: c.navAtivo,
                      aoTocar: expirou ? () => entrarNoPortal(context, aoEntrar: _tentarDeNovo) : _tentarDeNovo,
                    ),
                  ),
                ),
              ],
            );
          }
          if (lista.isEmpty) {
            return ListaDaTela(
              children: [
                topo,
                const Cartao(
                  child: EstadoVazio(
                    icone: Icons.search_off_rounded,
                    titulo: 'Nada encontrado',
                    texto: 'Tente outra palavra, o sobrenome do autor ou um assunto mais geral.',
                  ),
                ),
              ],
            );
          }
          return SafeArea(
            bottom: false,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(AppMedidas.margem, 12, AppMedidas.margem, 24),
              itemCount: lista.length + 2,
              separatorBuilder: (_, _) => const SizedBox(height: AppMedidas.entreCartoes),
              itemBuilder: (context, i) {
                if (i == 0) return topo;
                if (i == 1) {
                  return Text(
                    lista.length == 1 ? '1 título' : '${lista.length} títulos',
                    style: AppTexto.rotulo.copyWith(color: c.secundario),
                  );
                }
                return _CartaoTitulo(titulo: lista[i - 2]);
              },
            ),
          );
        },
      ),
    );
  }
}

class _CartaoTitulo extends StatelessWidget {
  const _CartaoTitulo({required this.titulo});

  final TituloAcervo titulo;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final t = titulo;
    return Cartao(
      aoTocar: () => _mostrarExemplares(context, t),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconeQuadrado(icone: Icons.menu_book_rounded, cor: c.navAtivo, fundo: c.navAtivoFundo),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.tituloCompleto, style: AppTexto.corpoForte, maxLines: 3, overflow: TextOverflow.ellipsis),
                if (t.autor != null || t.ano != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    [?t.autor, ?t.ano].join(' · '),
                    style: AppTexto.apoio.copyWith(color: c.secundario),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (t.biblioteca != null) ...[
                  const SizedBox(height: 6),
                  Selo(texto: t.biblioteca!, cor: c.secundario, fundo: c.chrome),
                ],
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: c.secundario),
        ],
      ),
    );
  }
}

Future<void> _mostrarExemplares(BuildContext context, TituloAcervo titulo) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (folha) => SafeArea(
    child: ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(folha).height * 0.75),
      child: _Exemplares(titulo: titulo),
    ),
  ),
);

class _Exemplares extends StatefulWidget {
  const _Exemplares({required this.titulo});

  final TituloAcervo titulo;

  @override
  State<_Exemplares> createState() => _ExemplaresState();
}

class _ExemplaresState extends State<_Exemplares> {
  late final _pedido = RepositorioBiblioteca.instancia.exemplares(widget.titulo);

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    return FutureBuilder(
      future: _pedido,
      builder: (context, snap) {
        final itens = <Widget>[
          Text(widget.titulo.tituloCompleto, style: AppTexto.tituloCartao),
          if (widget.titulo.autor != null)
            Text(widget.titulo.autor!, style: AppTexto.apoio.copyWith(color: c.secundario)),
          const SizedBox(height: 12),
        ];
        if (!snap.hasData) {
          itens.addAll(const [
            Skeleton(altura: 56, raio: AppMedidas.raioBotao),
            SizedBox(height: 10),
            Skeleton(altura: 56, raio: AppMedidas.raioBotao),
          ]);
        } else if (snap.data!.$2 == null) {
          itens.add(const EstadoVazio(icone: Icons.wifi_off_rounded, titulo: 'Não consegui ver os exemplares agora'));
        } else {
          final lista = snap.data!.$2!;
          final livres = lista.where((e) => e.disponivel).length;
          itens.add(
            Selo(
              texto: lista.isEmpty
                  ? 'Nenhum exemplar cadastrado'
                  : livres == 0
                  ? 'Nenhum disponível agora · ${lista.length} no total'
                  : '$livres de ${lista.length} disponíveis',
              cor: livres > 0 ? c.verde : c.chipTexto,
              fundo: livres > 0 ? c.verdeFundo : c.chipFundo,
            ),
          );
          for (final e in lista) {
            itens.addAll([const SizedBox(height: 10), _LinhaExemplar(exemplar: e)]);
          }
          itens.addAll([
            const SizedBox(height: 14),
            Text(
              'Para pegar o livro, anote a localização e procure na estante, ou peça no balcão da biblioteca.',
              style: AppTexto.rotulo.copyWith(color: c.secundario),
            ),
          ]);
        }
        return ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(AppMedidas.margem, 0, AppMedidas.margem, AppMedidas.margem),
          children: [Column(crossAxisAlignment: CrossAxisAlignment.start, children: itens)],
        );
      },
    );
  }
}

class _LinhaExemplar extends StatelessWidget {
  const _LinhaExemplar({required this.exemplar});

  final Exemplar exemplar;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final e = exemplar;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: c.fundo, borderRadius: BorderRadius.circular(AppMedidas.raioBotao)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.localizacao, style: AppTexto.corpoForte),
                Text(
                  [
                    e.biblioteca,
                    if (e.colecao != null && e.colecao != e.biblioteca) e.colecao!,
                    ?e.regulamento,
                  ].where((s) => s.isNotEmpty).join(' · '),
                  style: AppTexto.rotulo.copyWith(color: c.secundario),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          e.disponivel
              ? Selo(texto: 'Disponível', cor: c.verde, fundo: c.verdeFundo)
              : Selo(texto: e.situacao, cor: c.chipTexto, fundo: c.chipFundo),
        ],
      ),
    );
  }
}
