import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as caminho;
import 'package:path_provider/path_provider.dart';

import '../theme/app_cores.dart';

/// A foto fica só na pasta privada do app, reduzida, e nunca é enviada para lugar nenhum.
class FotoPerfil extends ChangeNotifier {
  FotoPerfil._();
  static final instancia = FotoPerfil._();

  static const _lado = 512;

  Uint8List? bytes;

  Future<File> _arquivo() async =>
      File(caminho.join((await getApplicationDocumentsDirectory()).path, 'foto_perfil.jpg'));

  Future<void> carregar() async {
    final arquivo = await _arquivo();
    bytes = await arquivo.exists() ? await arquivo.readAsBytes() : null;
    notifyListeners();
  }

  Future<void> escolher(BuildContext context) async {
    final c = context.cores;
    final escolhida = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (escolhida == null) return;
    final recorte = await ImageCropper().cropImage(
      sourcePath: escolhida.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      maxWidth: _lado,
      maxHeight: _lado,
      compressFormat: ImageCompressFormat.jpg,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Recortar foto',
          toolbarColor: c.primaria,
          toolbarWidgetColor: c.sobrePrimaria,
          lockAspectRatio: true,
        ),
      ],
    );
    File(escolhida.path).delete().ignore();
    if (recorte == null) return;
    final novos = await File(recorte.path).readAsBytes();
    File(recorte.path).delete().ignore();
    await (await _arquivo()).writeAsBytes(novos, flush: true);
    bytes = novos;
    notifyListeners();
  }

  Future<void> remover() async {
    final arquivo = await _arquivo();
    if (await arquivo.exists()) await arquivo.delete();
    bytes = null;
    notifyListeners();
  }
}
