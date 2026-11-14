import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_cores.dart';
import '../theme/app_medidas.dart';
import '../theme/app_texto.dart';

/// Cartão padrão: superfície com borda fina.
class Cartao extends StatelessWidget {
  const Cartao({super.key, required this.child, this.cor, this.aoTocar, this.preenchimento});

  final Widget child;
  final Color? cor;
  final VoidCallback? aoTocar;
  final EdgeInsets? preenchimento;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final raio = BorderRadius.circular(AppMedidas.raioCartao);
    return Material(
      color: cor ?? c.superficie,
      shape: RoundedRectangleBorder(
        borderRadius: raio,
        side: cor == null ? BorderSide(color: c.borda) : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: aoTocar,
        child: Padding(
          padding: preenchimento ?? const EdgeInsets.all(AppMedidas.interno),
          child: child,
        ),
      ),
    );
  }
}

/// Botão largo. Variantes: destaque (âmbar) e contorno (sobre o azul).
class BotaoDestaque extends StatelessWidget {
  const BotaoDestaque({super.key, required this.texto, required this.icone, required this.aoTocar});

  final String texto;
  final IconData icone;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    return FilledButton.icon(
      onPressed: aoTocar,
      icon: Icon(icone, size: 20),
      label: Text(texto, textAlign: TextAlign.center),
      style: FilledButton.styleFrom(
        backgroundColor: c.destaque,
        foregroundColor: c.sobreDestaque,
        minimumSize: const Size.fromHeight(48),
        textStyle: AppTexto.corpoForte,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppMedidas.raioBotao)),
      ),
    );
  }
}

class BotaoContorno extends StatelessWidget {
  const BotaoContorno({super.key, required this.texto, this.icone, required this.aoTocar, this.cor});

  final String texto;
  final IconData? icone;
  final VoidCallback aoTocar;
  final Color? cor;

  @override
  Widget build(BuildContext context) {
    final corFinal = cor ?? context.cores.sobrePrimaria;
    return OutlinedButton.icon(
      onPressed: aoTocar,
      icon: icone == null ? null : Icon(icone, size: 20),
      label: Text(texto, textAlign: TextAlign.center),
      style: OutlinedButton.styleFrom(
        foregroundColor: corFinal,
        side: BorderSide(color: corFinal),
        minimumSize: const Size.fromHeight(48),
        textStyle: AppTexto.corpoForte,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppMedidas.raioBotao)),
      ),
    );
  }
}

/// Botão redondo do topo (notificações, menu).
class BotaoRedondo extends StatelessWidget {
  const BotaoRedondo({super.key, required this.icone, required this.descricao, required this.aoTocar});

  final IconData icone;
  final String descricao;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    return IconButton(
      onPressed: aoTocar,
      tooltip: descricao,
      icon: Icon(icone, size: 22, color: c.texto),
      style: IconButton.styleFrom(
        backgroundColor: c.chrome,
        minimumSize: const Size(AppMedidas.toqueMinimo, AppMedidas.toqueMinimo),
      ),
    );
  }
}

/// Ícone dentro de um quadrado arredondado colorido.
class IconeQuadrado extends StatelessWidget {
  const IconeQuadrado({super.key, required this.icone, required this.cor, required this.fundo, this.lado = 44});

  final IconData icone;
  final Color cor, fundo;
  final double lado;

  @override
  Widget build(BuildContext context) => Container(
        width: lado,
        height: lado,
        decoration: BoxDecoration(color: fundo, borderRadius: BorderRadius.circular(AppMedidas.raioIcone)),
        child: Icon(icone, color: cor, size: lado * 0.55),
      );
}

/// Etiqueta em pílula ("começa em 20 min").
class Selo extends StatelessWidget {
  const Selo({super.key, required this.texto, required this.cor, required this.fundo});

  final String texto;
  final Color cor, fundo;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: fundo, borderRadius: BorderRadius.circular(99)),
        child: Text(texto, style: AppTexto.rotulo.copyWith(color: cor)),
      );
}

/// Seletor de abas em pílula (Café · Almoço · Jantar).
class SeletorAbas extends StatelessWidget {
  const SeletorAbas({super.key, required this.rotulos, required this.atual, required this.aoEscolher});

  final List<String> rotulos;
  final int atual;
  final ValueChanged<int> aoEscolher;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: c.chrome, borderRadius: BorderRadius.circular(AppMedidas.raioBotao)),
      child: Row(
        children: [
          for (var i = 0; i < rotulos.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => aoEscolher(i),
                child: AnimatedContainer(
                  duration: AppMedidas.transicao,
                  constraints: const BoxConstraints(minHeight: AppMedidas.toqueMinimo),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == atual ? c.superficie : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppMedidas.raioBotao - 4),
                  ),
                  child: Text(
                    rotulos[i],
                    style: AppTexto.corpoForte.copyWith(color: i == atual ? c.navAtivo : c.secundario),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Faixa âmbar discreta, com ação opcional à direita.
class FaixaAviso extends StatelessWidget {
  const FaixaAviso({super.key, required this.icone, required this.texto, this.acao, this.aoTocar});

  final IconData icone;
  final String texto;
  final String? acao;
  final VoidCallback? aoTocar;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    return Cartao(
      cor: c.chipFundo,
      aoTocar: aoTocar,
      preenchimento: const EdgeInsets.symmetric(horizontal: AppMedidas.interno, vertical: 12),
      child: Row(
        children: [
          Icon(icone, color: c.chipTexto, size: 22),
          const SizedBox(width: 10),
          Expanded(child: Text(texto, style: AppTexto.apoio.copyWith(color: c.chipTexto))),
          if (acao != null) ...[
            const SizedBox(width: 10),
            Text(acao!, style: AppTexto.corpoForte.copyWith(color: c.chipTexto)),
          ],
        ],
      ),
    );
  }
}

/// Item de lista tocável, com ícone à esquerda e seta à direita.
class ItemLista extends StatelessWidget {
  const ItemLista({
    super.key,
    required this.icone,
    required this.corIcone,
    required this.fundoIcone,
    required this.titulo,
    this.subtitulo,
    required this.aoTocar,
  });

  final IconData icone;
  final Color corIcone, fundoIcone;
  final String titulo;
  final String? subtitulo;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    return Cartao(
      aoTocar: aoTocar,
      child: Row(
        children: [
          IconeQuadrado(icone: icone, cor: corIcone, fundo: fundoIcone),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (subtitulo != null) Text(subtitulo!, style: AppTexto.rotulo.copyWith(color: c.secundario)),
                Text(titulo, style: AppTexto.corpoForte),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: c.secundario),
        ],
      ),
    );
  }
}

/// Título da tela com subtítulo e botões à direita.
class CabecalhoTela extends StatelessWidget {
  const CabecalhoTela({super.key, required this.titulo, this.sobretitulo, this.subtitulo, this.acoes = const []});

  final String titulo;
  final String? sobretitulo, subtitulo;
  final List<Widget> acoes;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (sobretitulo != null)
                Text(sobretitulo!, style: AppTexto.apoio.copyWith(color: context.cores.secundario)),
              Text(titulo, style: AppTexto.tituloTela),
              if (subtitulo != null) ...[
                const SizedBox(height: 2),
                Text(subtitulo!, style: AppTexto.apoio.copyWith(color: context.cores.secundario)),
              ],
            ],
          ),
        ),
        for (final a in acoes) Padding(padding: const EdgeInsets.only(left: 8), child: a),
      ],
    );
  }
}

/// Estado vazio ou de erro, sempre em linguagem humana.
class EstadoVazio extends StatelessWidget {
  const EstadoVazio({super.key, required this.icone, required this.titulo, this.texto, this.acao});

  final IconData icone;
  final String titulo;
  final String? texto;
  final Widget? acao;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
      child: Column(
        children: [
          IconeQuadrado(icone: icone, cor: c.secundario, fundo: c.chrome, lado: 52),
          const SizedBox(height: 12),
          Text(titulo, style: AppTexto.corpoForte, textAlign: TextAlign.center),
          if (texto != null) ...[
            const SizedBox(height: 4),
            Text(texto!, style: AppTexto.apoio.copyWith(color: c.secundario), textAlign: TextAlign.center),
          ],
          if (acao != null) ...[const SizedBox(height: 14), acao!],
        ],
      ),
    );
  }
}

/// Bloco de carregamento animado.
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, this.largura, this.altura = 16, this.raio = 8});

  final double? largura;
  final double altura, raio;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    return FadeTransition(
      opacity: Tween(begin: 0.45, end: 1.0).animate(_anim),
      child: Container(
        width: widget.largura,
        height: widget.altura,
        decoration: BoxDecoration(color: c.chrome, borderRadius: BorderRadius.circular(widget.raio)),
      ),
    );
  }
}

/// Lista rolável com as margens padrão, usada em todas as abas.
class ListaDaTela extends StatelessWidget {
  const ListaDaTela({super.key, required this.children, this.aoAtualizar});

  final List<Widget> children;

  /// Quando existe, a tela ganha "puxar para atualizar".
  final Future<void> Function()? aoAtualizar;

  @override
  Widget build(BuildContext context) {
    final lista = ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(AppMedidas.margem, 12, AppMedidas.margem, 24),
      itemCount: children.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppMedidas.entreCartoes),
      itemBuilder: (_, i) => children[i],
    );
    final atualizar = aoAtualizar;
    return SafeArea(
      bottom: false,
      child: atualizar == null
          ? lista
          : RefreshIndicator(
              onRefresh: () {
                vibrarLeve();
                return atualizar();
              },
              child: lista,
            ),
    );
  }
}

/// Vibração leve, usada ao abrir o QR e ao puxar para atualizar.
void vibrarLeve() => HapticFeedback.lightImpact();

/// Ações que ainda não existem nesta etapa.
void avisarEmBreve(BuildContext context) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(const SnackBar(content: Text('Isso chega numa próxima etapa.')));
}
