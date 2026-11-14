// Formatos brasileiros: R$ 12,50; Quarta, 4 de novembro; 10h20.

const _dias = ['Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado', 'Domingo'];
const _meses = [
  'janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho',
  'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro',
];

String formatarMoeda(double valor) {
  final partes = valor.toStringAsFixed(2).split('.');
  final inteiro = partes[0].replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]}.');
  return 'R\$ $inteiro,${partes[1]}';
}

String formatarData(DateTime d) => '${_dias[d.weekday - 1]}, ${d.day} de ${_meses[d.month - 1]}';

String formatarHora(int h, int m) => m == 0 ? '${h}h' : '${h}h${m.toString().padLeft(2, '0')}';

String formatarHoraMin(int minutos) => formatarHora(minutos ~/ 60, minutos % 60);

/// Mostra só os 4 últimos dígitos.
String mascararNumero(String numero) {
  if (numero.length <= 4) return numero;
  return '${'•' * (numero.length - 4)}${numero.substring(numero.length - 4)}';
}

/// "4/11 às 10h20"
String formatarDiaHora(DateTime d) => '${d.day}/${d.month} às ${formatarHora(d.hour, d.minute)}';

/// "hoje 23h59", "amanhã 10h", "sex 18h".
String formatarPrazoCurto(DateTime prazo, DateTime agora) {
  final dia = DateTime(prazo.year, prazo.month, prazo.day);
  final hoje = DateTime(agora.year, agora.month, agora.day);
  final diferenca = dia.difference(hoje).inDays;
  final hora = formatarHora(prazo.hour, prazo.minute);
  if (diferenca == 0) return 'hoje $hora';
  if (diferenca == 1) return 'amanhã $hora';
  return '${_dias[prazo.weekday - 1].substring(0, 3).toLowerCase()} $hora';
}
