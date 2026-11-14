import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Cache local em SQLite. Nunca guardar aqui a matrícula nem o número do QR (regra 6).
class Banco {
  static Database? _db;

  static Future<Database> _abrir() async => _db ??= await openDatabase(
        join(await getDatabasesPath(), 'ufac_no_bolso.db'),
        version: 1,
        onCreate: (db, _) => db.execute('CREATE TABLE cache (chave TEXT PRIMARY KEY, valor TEXT NOT NULL)'),
      );

  static Future<String?> ler(String chave) async {
    final linhas = await (await _abrir()).query('cache', where: 'chave = ?', whereArgs: [chave]);
    return linhas.isEmpty ? null : linhas.first['valor'] as String;
  }

  static Future<void> gravar(String chave, String valor) async => (await _abrir()).insert(
        'cache',
        {'chave': chave, 'valor': valor},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  static Future<void> apagarTudo() async => (await _abrir()).delete('cache');
}
