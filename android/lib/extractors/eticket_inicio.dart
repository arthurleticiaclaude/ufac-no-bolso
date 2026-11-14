import 'package:html/parser.dart' as html;

class DadosEticketInicio {
  const DadosEticketInicio({required this.saldo, required this.numeroQr});
  final double saldo;
  final String numeroQr;
}

/// Lê saldo e número do QR da página inicial logada do eTICKET.
/// Devolve null se a página não tiver o formato esperado (nunca um dado errado).
DadosEticketInicio? lerEticketInicio(String pagina) {
  final doc = html.parse(pagina);
  final titulo = doc.querySelectorAll('h2').where((e) => e.text.contains('Saldo')).firstOrNull;
  final valor = titulo == null ? null : RegExp(r'R\$\s*([\d.,]+)').firstMatch(titulo.text)?.group(1);
  final saldo = valor == null ? null : double.tryParse(valor.replaceAll('.', '').replaceAll(',', '.'));
  final numero = doc.querySelector('img[alt="QR Code"]')?.parent?.querySelector('p')?.text.trim();
  if (saldo == null || numero == null || !RegExp(r'^\d{6,}$').hasMatch(numero)) return null;
  return DadosEticketInicio(saldo: saldo, numeroQr: numero);
}
