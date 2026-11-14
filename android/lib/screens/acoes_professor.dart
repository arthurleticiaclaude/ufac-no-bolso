import 'package:flutter/material.dart';

import '../data/repositorio_portal.dart' show ResultadoPortal;
import '../data/repositorio_professor.dart';
import '../session/regras_sessao.dart';
import 'login.dart';

/// Abre o login só do Portal do Professor e, ao concluir, lê os dados de novo.
/// [aoEntrar] continua o que a pessoa estava fazendo (por exemplo, recarregar a chamada).
void entrarNoPortalProfessor(BuildContext context, {VoidCallback? aoEntrar}) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => TelaLogin(
        etapas: const [Sistema.professor],
        aoConcluir: (rota) {
          Navigator.of(rota).pop();
          aoEntrar?.call();
          RepositorioProfessor.instancia.atualizar();
        },
      ),
    ),
  );
}

/// Puxar para atualizar. Se a sessão caiu, oferece entrar, sem interromper.
Future<void> atualizarProfessor(BuildContext context) async {
  final mensageiro = ScaffoldMessenger.of(context);
  final resultado = await RepositorioProfessor.instancia.atualizar();
  if (!context.mounted || resultado == ResultadoPortal.atualizado) return;
  final expirou = resultado == ResultadoPortal.sessaoExpirada;
  mensageiro
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          expirou
              ? 'Para atualizar os dados do Portal do Professor, entre de novo.'
              : 'Não consegui ler o Portal do Professor agora. Mostrando os dados salvos.',
        ),
        action: expirou
            ? SnackBarAction(label: 'Entrar', onPressed: () => entrarNoPortalProfessor(context))
            : null,
      ),
    );
}
