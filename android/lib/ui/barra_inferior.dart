import 'package:flutter/material.dart';

import '../theme/app_cores.dart';

class BarraInferior extends StatelessWidget {
  const BarraInferior({super.key, required this.indice, required this.aoEscolher, this.professor = false});

  final int indice;
  final ValueChanged<int> aoEscolher;

  /// Professor: "Turmas" no lugar de "Notas".
  final bool professor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(border: Border(top: BorderSide(color: context.cores.borda))),
      child: NavigationBar(
        selectedIndex: indice,
        onDestinationSelected: aoEscolher,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          const NavigationDestination(icon: Icon(Icons.home_rounded), label: 'Início'),
          const NavigationDestination(icon: Icon(Icons.calendar_month_rounded), label: 'Horários'),
          professor
              ? const NavigationDestination(icon: Icon(Icons.groups_rounded), label: 'Turmas')
              : const NavigationDestination(icon: Icon(Icons.grading_rounded), label: 'Notas'),
          const NavigationDestination(icon: Icon(Icons.description_rounded), label: 'Relatórios'),
          const NavigationDestination(icon: Icon(Icons.restaurant_rounded), label: 'RU'),
        ],
      ),
    );
  }
}
