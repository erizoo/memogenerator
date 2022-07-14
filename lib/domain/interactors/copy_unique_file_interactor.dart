import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:collection/collection.dart';

class CopyUniqueFileInteractor {
  static CopyUniqueFileInteractor? _instance;

  factory CopyUniqueFileInteractor.getInstance() =>
      _instance ??= CopyUniqueFileInteractor._internal();

  CopyUniqueFileInteractor._internal();

  Future<String> copyUniqueFile({
    required final String directoryWithFiles,
    required final String filePath,
  }) async {
    // docsPath получение доступа где хранятся картинки
    final docsPath = await getApplicationDocumentsDirectory();
    // папка с мемами создаем ее
    final memePath =
        "${docsPath.absolute.path}${Platform.pathSeparator}$directoryWithFiles";
    final memesDirectory = Directory(memePath);
    await memesDirectory.create(recursive: true);

    // получение текущего списка с файлами
    final currentFiles = memesDirectory.listSync();

    // imageName получение названия файлика
    final imageName = _getFileNameByPath(filePath);
    // есть ли файл сейчас с таким же названием
    final oldFileWithTheSameName = currentFiles.firstWhereOrNull(
      (element) {
        return _getFileNameByPath(element.path) == imageName && element is File;
      },
    );
    // fullImagePath новый путь
    final newImagePath = "$memePath${Platform.pathSeparator}$imageName";
    // создаем новый файл
    final tempFile = File(filePath);
    if (oldFileWithTheSameName == null) {
      // файлов с таким названием нет. Сохраняем файл в документы
      await tempFile.copy(newImagePath);
      return imageName;
    }
    // запрашиваем размер файла
    final oldFileLength = await (oldFileWithTheSameName as File).length();
    // сколько занимает места файл, который хотим скопировать
    final newFileLength = await tempFile.length();
    if (oldFileLength == newFileLength) {
      // такой файл уже есть. не сохраняем заново
      return imageName;
    }
    //последняя точка до расширения файла
    final indexOfLastDot = imageName.lastIndexOf(".");
    // избавляемся от расширения файла
    if (indexOfLastDot == -1) {
      // у файла нет расширения. сохраняем в документы
      await tempFile.copy(newImagePath);
      return imageName;
    }
    final extension = imageName.substring(indexOfLastDot);
    final imageNameWithoutExtension = imageName.substring(0, indexOfLastDot);
    final indexOfLastUnderscore = imageNameWithoutExtension.lastIndexOf("_");
    if (indexOfLastUnderscore == -1) {
      // файл с таки названием есть, но с другим размером есть
      // сохраняем файл в документы и добавляем суффикс '_1'
      final newImageName = "${imageNameWithoutExtension}_1$extension";
      final correctedNewImagePath =
          "$memePath${Platform.pathSeparator}$newImageName";
      await tempFile.copy(correctedNewImagePath);
      return newImageName;
    }
    final suffixNumberString =
        imageNameWithoutExtension.substring(indexOfLastUnderscore + 1);
    final suffixNumber = int.tryParse(suffixNumberString);
    if (suffixNumber == null) {
      // файл с таки названием есть, но с другим размером есть
      // суффикс не является числом
      // сохраняем файл в документы и добавляем суффикс '_1'
      final newImageName = "${imageNameWithoutExtension}_1$extension";
      final correctedNewImagePath =
          "$memePath${Platform.pathSeparator}$newImageName";
      await tempFile.copy(correctedNewImagePath);
      return newImageName;
    }
    // файл с таки названием есть, но с другим размером есть
    // увеличиваем число в суффиксе и сохраняем файл в документы
    final imageNameWithoutSuffix =
        imageNameWithoutExtension.substring(0, indexOfLastUnderscore);
    final newImageName =
        "${imageNameWithoutSuffix}_${suffixNumber + 1}$extension";
    final correctedNewImagePath =
        "$memePath${Platform.pathSeparator}$newImageName";
    await tempFile.copy(correctedNewImagePath);
    return newImageName;
  }

  String _getFileNameByPath(String imagePath) =>
      imagePath.split(Platform.pathSeparator).last;
}
