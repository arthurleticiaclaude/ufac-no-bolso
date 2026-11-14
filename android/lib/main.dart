import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data/foto_perfil.dart';
import 'data/perfil.dart';
import 'data/preferencias.dart';
import 'data/repositorio_portal.dart';
import 'data/repositorio_professor.dart';
import 'data/repositorio_ru.dart';
import 'pdf/servico_pdf.dart';
import 'screens/boas_vindas.dart';
import 'screens/casca.dart';
import 'session/sessao.dart';
import 'theme/app_tema.dart';

// Só para tirar prints nos dois temas sem mexer no celular: --dart-define=TEMA=claro|escuro.
const _temaForcado = String.fromEnvironment('TEMA');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  final loginConcluido = await Sessao.instancia.loginConcluido();
  if (loginConcluido) {
    await ServicoPdf.limparTemporarios();
    await Preferencias.instancia.carregar();
    await Perfil.instancia.carregar();
    await FotoPerfil.instancia.carregar();
    await RepositorioRu.instancia.carregarSalvos();
    if (Perfil.instancia.ehProfessor) {
      await RepositorioProfessor.instancia.carregarSalvos();
    } else {
      await RepositorioPortal.instancia.carregarSalvos();
    }
  }
  runApp(UfacNoBolso(loginConcluido: loginConcluido));
}

class UfacNoBolso extends StatelessWidget {
  const UfacNoBolso({super.key, required this.loginConcluido});

  final bool loginConcluido;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([Preferencias.instancia, Perfil.instancia]),
      builder: (context, _) => MaterialApp(
        title: 'UFAC+',
        debugShowCheckedModeBanner: false,
        // Alunos em azul, professores em vermelho. O ícone é o mesmo para todos.
        theme: Perfil.instancia.ehProfessor ? AppTema.professorClaro : AppTema.claro,
        darkTheme: Perfil.instancia.ehProfessor ? AppTema.professorEscuro : AppTema.escuro,
        themeMode: switch (_temaForcado) {
          'claro' => ThemeMode.light,
          'escuro' => ThemeMode.dark,
          _ => Preferencias.instancia.tema,
        },
        home: loginConcluido ? const Casca() : const TelaBoasVindas(),
      ),
    );
  }
}
