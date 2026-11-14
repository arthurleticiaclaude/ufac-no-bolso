import 'package:flutter/material.dart';

import '../data/academico.dart';
import '../data/repositorio_portal.dart';
import '../data/repositorio_professor.dart';
import '../theme/app_cores.dart';
import '../theme/app_medidas.dart';
import '../theme/app_texto.dart';
import '../ui/componentes.dart';
import '../ui/formatos.dart';
import 'acoes_portal.dart';
import 'acoes_professor.dart';
import 'menu.dart';

class TelaHorarios extends StatefulWidget {
  const TelaHorarios({super.key, this.professor = false});

  /// Professor: horários de todas as turmas, do Portal do Professor.
  final bool professor;

  @override
  State<TelaHorarios> createState() => _TelaHorariosState();
}

class _TelaHorariosState extends State<TelaHorarios> {
  static const _dias = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];
  final _hoje = DateTime.now().weekday;
  late int _dia = _hoje;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.professor ? RepositorioProfessor.instancia : RepositorioPortal.instancia,
      builder: (context, _) => _construir(context),
    );
  }

  Widget _construir(BuildContext context) {
    final portal = RepositorioPortal.instancia, prof = RepositorioProfessor.instancia;
    final professor = widget.professor;
    final todas = professor ? prof.aulas : portal.aulas;
    final carregando = professor ? prof.carregando : portal.carregando;
    final c = context.cores;
    final hoje = DateTime.now();
    final aulas = (todas ?? const <Aula>[])
        .where((a) => a.diaSemana == _dia && a.valeNoDia(hoje))
        .toList()
      ..sort((a, b) => a.inicioMin.compareTo(b.inicioMin));
    final semestre = professor ? prof.semestre : portal.identificacao?.semestre;
    return ListaDaTela(
      aoAtualizar: () => professor ? atualizarProfessor(context) : atualizarPortal(context),
      children: [
        CabecalhoTela(
          titulo: 'Horários',
          subtitulo: semestre,
          acoes: [
            BotaoRedondo(icone: Icons.menu_rounded, descricao: 'Menu', aoTocar: () => abrirMenu(context)),
          ],
        ),
        Row(
          children: [
            for (var i = 0; i < 7; i++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: _ChipDia(
                    nome: _dias[i],
                    ativo: _dia == i + 1,
                    hoje: _hoje == i + 1,
                    aoTocar: () => setState(() => _dia = i + 1),
                  ),
                ),
              ),
          ],
        ),
        if (todas == null)
          carregando
              ? const Skeleton(altura: 76, raio: AppMedidas.raioCartao)
              : Cartao(
                  child: EstadoVazio(
                    icone: Icons.calendar_month_rounded,
                    titulo: 'Ainda não li seus horários',
                    acao: BotaoContorno(
                      texto: 'Entrar no Portal',
                      cor: c.navAtivo,
                      aoTocar: () => professor ? entrarNoPortalProfessor(context) : entrarNoPortal(context),
                    ),
                  ),
                )
        else if (aulas.isEmpty)
          const Cartao(child: EstadoVazio(icone: Icons.event_available_rounded, titulo: 'Sem aula neste dia'))
        else
          for (final a in aulas)
            Cartao(
              child: Row(
                children: [
                  IconeQuadrado(icone: Icons.schedule_rounded, cor: c.navAtivo, fundo: c.navAtivoFundo),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(a.disciplina, style: AppTexto.corpoForte),
                        Text(
                          '${formatarHoraMin(a.inicioMin)} às ${formatarHoraMin(a.fimMin)}',
                          style: AppTexto.apoio.copyWith(color: c.secundario),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}

class _ChipDia extends StatelessWidget {
  const _ChipDia({required this.nome, required this.ativo, required this.hoje, required this.aoTocar});

  final String nome;
  final bool ativo, hoje;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    return Material(
      color: ativo ? c.navAtivoFundo : c.superficie,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppMedidas.raioBotao),
        side: BorderSide(color: hoje ? c.navAtivo : c.borda),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: aoTocar,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppMedidas.toqueMinimo),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(nome, style: AppTexto.rotulo.copyWith(color: ativo ? c.navAtivo : c.secundario)),
            ),
          ),
        ),
      ),
    );
  }
}
