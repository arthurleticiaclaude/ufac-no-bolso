import 'package:flutter/material.dart';

import '../data/repositorio_portal.dart';
import '../session/regras_sessao.dart';
import 'login.dart';

/// Abre o login só do portal e, ao concluir, lê os dados de novo e continua o que a pessoa pediu.
void entrarNoPortal(BuildContext context, {VoidCallback? aoEntrar}) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => TelaLogin(
        etapas: const [Sistema.portal],
        aoConcluir: (rota) {
          Navigator.of(rota).pop();
          RepositorioPortal.instancia.atualizar().then((_) => aoEntrar?.call());
        },
      ),
    ),
  );
}

/// Puxar para atualizar. A sessão do portal é curta: se caiu, oferece entrar, sem interromper.
Future<void> atualizarPortal(BuildContext context) async {
  final mensageiro = ScaffoldMessenger.of(context);
  final resultado = await RepositorioPortal.instancia.atualizar();
  if (!context.mounted || resultado == ResultadoPortal.atualizado) return;
  final expirou = resultado == ResultadoPortal.sessaoExpirada;
  mensageiro
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          expirou
              ? 'Para atualizar os dados do Portal, entre de novo.'
              : 'Não consegui ler o Portal agora. Mostrando os dados salvos.',
        ),
        action: expirou ? SnackBarAction(label: 'Entrar', onPressed: () => entrarNoPortal(context)) : null,
      ),
    );
}
