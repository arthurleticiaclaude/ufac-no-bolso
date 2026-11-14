import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as fusos;
import 'package:timezone/timezone.dart' as tz;

import '../config.dart';
import '../ui/formatos.dart';
import 'classroom.dart';
import 'preferencias.dart';

class AvisoPlanejado {
  const AvisoPlanejado({required this.id, required this.quando, required this.titulo, required this.texto});
  final int id;
  final DateTime quando;
  final String titulo, texto;
}

const _primeiroId = 7100; // faixa só destes avisos, para cancelar sem mexer em mais nada
const _dias = 7;

/// Um aviso por dia, às [horaAvisoClassroom], com o que falta entregar até o fim do dia seguinte.
/// Sem nada a entregar, não há aviso naquele dia.
List<AvisoPlanejado> planejarAvisos(List<Atividade> lista, DateTime agora) {
  final avisos = <AvisoPlanejado>[];
  for (var d = 0; d < _dias; d++) {
    final quando = DateTime(agora.year, agora.month, agora.day + d, horaAvisoClassroom);
    if (!quando.isAfter(agora)) continue;
    final limite = DateTime(quando.year, quando.month, quando.day + 2);
    final doDia = ordenarPorPrazo([
      for (final a in lista)
        if (a.situacao != SituacaoEntrega.entregue &&
            a.prazo != null &&
            a.prazo!.isAfter(quando) &&
            a.prazo!.isBefore(limite))
          a,
    ]);
    if (doDia.isEmpty) continue;
    final n = doDia.length;
    avisos.add(AvisoPlanejado(
      id: _primeiroId + d,
      quando: quando,
      titulo: n == 1 ? '1 atividade para entregar' : '$n atividades para entregar',
      texto: [
        for (final a in doDia)
          '${a.titulo} · ${formatarPrazoCurto(a.prazo!, quando)}${a.turma == null ? '' : ' · ${a.turma}'}',
      ].join('\n'),
    ));
  }
  return avisos;
}

/// Avisos locais. Agendados a partir da última leitura do Classroom; nada roda em segundo plano
/// e nada sai do celular. Toda leitura nova refaz a agenda.
class AvisosClassroom {
  AvisosClassroom._();
  static final instancia = AvisosClassroom._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _iniciado = false;

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  Future<void> _iniciar() async {
    if (_iniciado) return;
    fusos.initializeTimeZones();
    await _plugin.initialize(
      settings: const InitializationSettings(android: AndroidInitializationSettings('ic_notificacao')),
    );
    _iniciado = true;
  }

  /// Pede a permissão do Android 13+ (o próprio Android só pergunta uma vez).
  Future<bool> pedirPermissao() async {
    try {
      await _iniciar();
      return await _android?.requestNotificationsPermission() ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> reagendar(List<Atividade> lista) async {
    try {
      await _iniciar();
      await cancelar();
      if (!Preferencias.instancia.avisarClassroom) return;
      if (await _android?.areNotificationsEnabled() == false) return;
      for (final a in planejarAvisos(lista, DateTime.now())) {
        await _plugin.zonedSchedule(
          id: a.id,
          // Um instante absoluto: a hora local já foi calculada acima.
          scheduledDate: tz.TZDateTime.from(a.quando, tz.UTC),
          title: a.titulo,
          body: a.texto.split('\n').first,
          notificationDetails: NotificationDetails(
            android: AndroidNotificationDetails(
              'classroom',
              'Atividades do Classroom',
              channelDescription: 'Um aviso por dia com o que falta entregar',
              styleInformation: BigTextStyleInformation(a.texto),
              // Na tela bloqueada, o Android esconde o conteúdo se a pessoa pediu isso.
              visibility: NotificationVisibility.private,
            ),
          ),
          // Sem alarme exato: não precisa de permissão extra e economiza bateria.
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    } catch (e) {
      debugPrint('Avisos do Classroom: não consegui agendar (${e.runtimeType})');
    }
  }

  Future<void> cancelar() async {
    try {
      await _iniciar();
      for (var d = 0; d < _dias; d++) {
        await _plugin.cancel(id: _primeiroId + d);
      }
    } catch (_) {}
  }
}
