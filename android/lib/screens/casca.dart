import 'package:flutter/material.dart';

import '../data/atualizacoes.dart';
import '../data/classroom.dart';
import '../data/perfil.dart';
import '../data/repositorio_portal.dart';
import '../data/repositorio_professor.dart';
import '../data/repositorio_ru.dart';
import '../theme/app_medidas.dart';
import '../ui/barra_inferior.dart';
import '../ui/tela_atual.dart';
import 'horarios.dart';
import 'inicio.dart';
import 'notas.dart';
import 'professor.dart';
import 'relatorios.dart';
import 'ru.dart';

/// Estrutura principal: as 5 abas e a barra inferior.
class Casca extends StatefulWidget {
  const Casca({super.key});

  @override
  State<Casca> createState() => _CascaState();
}

const _nomesDasAbas = ['Início', 'Horários', 'Notas', 'Relatórios', 'RU'];
const _nomesDasAbasProfessor = ['Início', 'Horários', 'Turmas', 'Relatórios', 'RU'];

class _CascaState extends State<Casca> with WidgetsBindingObserver {
  int _indice = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    RepositorioRu.instancia.aoAbrirApp();
    final professor = Perfil.instancia.ehProfessor;
    if (professor) {
      RepositorioProfessor.instancia.aoAbrirApp();
    } else {
      RepositorioPortal.instancia.aoAbrirApp();
      // O Classroom do app lê como aluno; para professor ainda não serve.
      AtividadesDaSemana.instancia.aoAbrirApp();
    }
    Atualizacoes.instancia.aoAbrirApp();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState estado) {
    if (estado == AppLifecycleState.resumed) {
      RepositorioRu.instancia.aoVoltarParaOApp();
      if (!Perfil.instancia.ehProfessor) AtividadesDaSemana.instancia.aoVoltarParaOApp();
    }
  }

  @override
  Widget build(BuildContext context) {
    final professor = Perfil.instancia.ehProfessor;
    final abas = professor
        ? [
            TelaInicioProfessor(abrirRu: () => setState(() => _indice = 4)),
            const TelaHorarios(professor: true),
            const TelaTurmasProfessor(),
            const TelaRelatoriosProfessor(),
            const TelaRu(),
          ]
        : [
            TelaInicio(abrirRu: () => setState(() => _indice = 4)),
            const TelaHorarios(),
            const TelaNotas(),
            const TelaRelatorios(),
            const TelaRu(),
          ];
    return Scaffold(
      body: IndexedStack(
        index: _indice,
        children: [
          for (var i = 0; i < abas.length; i++)
            AnimatedOpacity(
              opacity: i == _indice ? 1 : 0,
              duration: AppMedidas.transicao,
              child: abas[i],
            ),
        ],
      ),
      bottomNavigationBar: BarraInferior(
        indice: _indice,
        professor: professor,
        aoEscolher: (i) {
          telaAtual = (professor ? _nomesDasAbasProfessor : _nomesDasAbas)[i];
          setState(() => _indice = i);
        },
      ),
    );
  }
}
