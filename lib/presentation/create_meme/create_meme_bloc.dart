import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:memogenerator/data/models/meme.dart';
import 'package:memogenerator/data/models/position.dart';
import 'package:memogenerator/data/models/text_with_position.dart';
import 'package:memogenerator/data/repositories/memes_repository.dart';
import 'package:memogenerator/domain/interactors/save_meme_interactor.dart';
import 'package:memogenerator/domain/interactors/screenshot_interactor.dart';

import 'package:memogenerator/presentation/create_meme/models/meme_text.dart';
import 'package:memogenerator/presentation/create_meme/models/meme_text_offset.dart';
import 'package:memogenerator/presentation/create_meme/models/meme_text_with_offset.dart';
import 'package:memogenerator/presentation/create_meme/models/meme_text_with_selection.dart';
import 'package:path_provider/path_provider.dart';
import 'package:rxdart/rxdart.dart';
import 'package:screenshot/screenshot.dart';
import 'package:uuid/uuid.dart';
import 'package:collection/collection.dart';

class CreateMemeBloc {
  // данные логического объекта, которые получаем в UI
  // отображение текста в верхней части приложения
  final memeTextSubject = BehaviorSubject<List<MemeText>>.seeded(<MemeText>[]);

  // выделенный в данный момент memeText
  final selectedMemeTextSubject = BehaviorSubject<MemeText?>.seeded(null);

  final memeTextOffsetsSubject =
      BehaviorSubject<List<MemeTextOffset>>.seeded(<MemeTextOffset>[]);

  // создание асихронного метода changeMemeTextOffset
  final newMemeTextOffsetSubject =
      BehaviorSubject<MemeTextOffset?>.seeded(null);

  // memePathSubject сохранеие и хранеие пути нашего файла
  final memePathSubject = BehaviorSubject<String?>.seeded(null);

  // screenshot
  final screenshotControllerSubject =
      BehaviorSubject<ScreenshotController>.seeded(ScreenshotController());

  StreamSubscription<MemeTextOffset?>? newMemeTextOffsetSubscription;
  StreamSubscription<bool>? saveMemeSubscription;
  StreamSubscription<Meme?>? existenMemeSubscription;
  StreamSubscription<void>? shareMemeSubscription;

  // конструктор слушатель
  // добавляем debounceTime для сохранения положения после того как мы
  // перестали передвигать текст
  final String id;

  CreateMemeBloc({
    final String? id,
    final String? selectedMemePath,
  }) : this.id = id ?? Uuid().v4() {
    memePathSubject.add(selectedMemePath);
    _subscribeToNewMemTextOffset();
    _subscribeToExistentMeme();
  }

  Future<bool> isAllSaved() async {
    // есть ли сохраненный мем
    final savedMeme = await MemesRepository.getInstance().getItemById(id);
    if (savedMeme == null) {
      return false;
    }
    final savedMemeTexts = savedMeme.texts.map((textWithPosition) {
      return MemeText.createFromTextWithPosition(textWithPosition);
    }).toList();
    final savedMemeTextOffset = savedMeme.texts.map((textWithPosition) {
      return MemeTextOffset(
        id: textWithPosition.id,
        offset: Offset(
          textWithPosition.position.left,
          textWithPosition.position.top,
        ),
      );
    }).toList();
    return DeepCollectionEquality.unordered()
            .equals(savedMemeTexts, memeTextSubject.value) &&
        DeepCollectionEquality.unordered()
            .equals(savedMemeTextOffset, memeTextOffsetsSubject.value);
  }

  void _subscribeToExistentMeme() {
    existenMemeSubscription =
        MemesRepository.getInstance().getItemById(this.id).asStream().listen(
      (meme) {
        if (meme == null) {
          return;
        }
        final memeTexts = meme.texts.map((textWithPosition) {
          return MemeText.createFromTextWithPosition(textWithPosition);
        }).toList();
        final memeTextOffset = meme.texts.map((textWithPosition) {
          return MemeTextOffset(
            id: textWithPosition.id,
            offset: Offset(
              textWithPosition.position.left,
              textWithPosition.position.top,
            ),
          );
        }).toList();
        memeTextSubject.add(memeTexts);
        memeTextOffsetsSubject.add(memeTextOffset);
        if (meme.memePath != null) {
          // абсолютный путь
          getApplicationDocumentsDirectory().then((docsDirectory) {
            // полный путь
            final onlyImageName =
                meme.memePath!.split(Platform.pathSeparator).last;
            // получение полного пути
            final fullImagePath =
                "${docsDirectory.absolute.path}${Platform.pathSeparator}${SaveMemeInteractor.memesPathName}${Platform.pathSeparator}$onlyImageName";
            memePathSubject.add(fullImagePath);
          });
        }
      },
      onError: (error, stackTrace) =>
          print("Error in existenMemeSubscription: $error, $stackTrace"),
    );
  }

  void shareMeme() {
    // получаем список с байтами
    shareMemeSubscription?.cancel();
    shareMemeSubscription = ScreenshotInteractor.getInstance()
        .shareScreenshot(screenshotControllerSubject.value)
        .asStream()
        .listen(
          (event) {},
          onError: (error, stackTrace) =>
              print("Error in shareMemeSubscription: $error, $stackTrace"),
        );
  }

  void changeFontSettings(
    final String textId,
    final Color color,
    final double fontSize,
    final FontWeight fontWeight,
  ) {
    final copiedList = [...memeTextSubject.value];
    final oldMemeText =
        copiedList.firstWhereOrNull((memeText) => memeText.id == textId);
    if (oldMemeText == null) {
      return;
    }
    copiedList.remove(oldMemeText);
    copiedList.add(
      oldMemeText.copyWithChangedFontSettings(color, fontSize, fontWeight),
    );
    memeTextSubject.add(copiedList);
  }

  // delete text
  void deleteMemeText(final String textId) {
    final updatedMemeTexts = [...memeTextSubject.value];
    updatedMemeTexts.removeWhere((memeText) => memeText.id == textId);
    memeTextSubject.add(updatedMemeTexts);
  }

  // сохранеие текста позиции в shared_pref
  void saveMeme() {
    final memeTexts = memeTextSubject.value;
    final memTextsOffsets = memeTextOffsetsSubject.value;
    final textsWithPositions = memeTexts.map((memeText) {
      final memeTextPosition =
          memTextsOffsets.firstWhereOrNull((memTextsOffset) {
        return memTextsOffset.id == memeText.id;
      });
      final position = Position(
        top: memeTextPosition?.offset.dy ?? 0,
        left: memeTextPosition?.offset.dx ?? 0,
      );
      return TextWithPosition(
        id: memeText.id,
        text: memeText.text,
        position: position,
        fontSize: memeText.fontSize,
        color: memeText.color,
        fontWeight: memeText.fontWeight,
      );
    }).toList();

    saveMemeSubscription = SaveMemeInteractor.getInstance()
        .saveMeme(
          id: id,
          textWithPositions: textsWithPositions,
          screenshotController: screenshotControllerSubject.value,
          imagePath: memePathSubject.value,
        )
        .asStream()
        .listen(
      (saved) {
        print("Meme saved: $saved");
      },
      onError: (error, stackTrace) =>
          print("Error in saveMemeSubscription: $error, $stackTrace"),
    );
  }

  void _subscribeToNewMemTextOffset() {
    newMemeTextOffsetSubscription = newMemeTextOffsetSubject
        .debounceTime(Duration(milliseconds: 300))
        .listen(
      (newMemeTextOffset) {
        if (newMemeTextOffset != null) {
          _changeMemeTextOffsetInternal(newMemeTextOffset);
        }
      },
      onError: (error, stackTrace) =>
          print("Error in newMemeTextOffsetSubscription: $error, $stackTrace"),
    );
  }

  void changeMemeTextOffset(final String id, final Offset offset) {
    newMemeTextOffsetSubject.add(MemeTextOffset(id: id, offset: offset));
  }

  // добавляем мем и сетим его в offset
  void _changeMemeTextOffsetInternal(final MemeTextOffset newMemeTextOffset) {
    final copiedMemeTextOffset = [...memeTextOffsetsSubject.value];
    final currentMemeTextOffset = copiedMemeTextOffset.firstWhereOrNull(
        (memeTextOffset) => memeTextOffset.id == newMemeTextOffset.id);
    if (currentMemeTextOffset != null) {
      copiedMemeTextOffset.remove(currentMemeTextOffset);
    }
    // добовляем новый элемент
    copiedMemeTextOffset.add(newMemeTextOffset);
    memeTextOffsetsSubject.add(copiedMemeTextOffset);
  }

  // при нажатии добавить текст, будет создаваться текст на холсте
  void addNewText() {
    final newMemeText = MemeText.create();
    memeTextSubject.add([...memeTextSubject.value, newMemeText]);
    selectedMemeTextSubject.add(newMemeText);
  }

// получить список с текущими memeText и найти нужный и заменить его id
  void changeMemeText(final String id, final String text) {
    final copiedList = [...memeTextSubject.value];
    final index = copiedList.indexWhere((memeText) => memeText.id == id);
    if (index == -1) {
      return;
    }
    final oldMemeText = copiedList[index];
    copiedList.removeAt(index);
    copiedList.insert(
      index,
      oldMemeText.copyWithChangedText(text),
    );
    memeTextSubject.add(copiedList);
  }

// при нажатии на текст в поле, метод выделяет текст в поле ввода и дает редактировать его
  void selectMemeText(final String id) {
    final foundMemeText =
        memeTextSubject.value.firstWhereOrNull((memeText) => memeText.id == id);
    selectedMemeTextSubject.add(foundMemeText);
  }

  void deselectMemeText() {
    selectedMemeTextSubject.add(null);
  }

  // выдает инфу содерж в этом subject
  Stream<List<MemeText>> observeMemeTexts() => memeTextSubject
      .distinct((prev, next) => ListEquality().equals(prev, next));

  Stream<String?> observeMemePath() => memePathSubject.distinct();

  Stream<List<MemeTextsWithOffset>> observeMemeTextWithOffsets() {
    return Rx.combineLatest2<List<MemeText>, List<MemeTextOffset>,
            List<MemeTextsWithOffset>>(
        observeMemeTexts(), memeTextOffsetsSubject.distinct(),
        (memeTexts, memeTextOffsets) {
      return memeTexts.map((memeText) {
        final memeTextOffset = memeTextOffsets.firstWhereOrNull((element) {
          return element.id == memeText.id;
        });
        return MemeTextsWithOffset(
          memeText: memeText,
          offset: memeTextOffset?.offset,
        );
      }).toList();
    }).distinct((prev, next) => ListEquality().equals(prev, next));
  }

  Stream<MemeText?> observeSelectedMemeText() =>
      selectedMemeTextSubject.distinct();

  // метод возвращающий observeScreenshotController
  Stream<ScreenshotController> observeScreenshotController() =>
      screenshotControllerSubject.distinct();

  // Stream возвращающий MemeTextWithSelection
  Stream<List<MemeTextsWithSelection>> observeMemeTextsWithSelection() {
    return Rx.combineLatest2<List<MemeText>, MemeText?,
        List<MemeTextsWithSelection>>(
      observeMemeTexts(),
      observeSelectedMemeText(),
      (memeTexts, selectedMemeText) {
        return memeTexts.map((memeText) {
          return MemeTextsWithSelection(
            memeText: memeText,
            selected: memeText.id == selectedMemeText?.id,
          );
        }).toList();
      },
    );
  }

  void dispose() {
    memeTextSubject.close();
    selectedMemeTextSubject.close();
    memeTextOffsetsSubject.close();
    newMemeTextOffsetSubject.close();
    memePathSubject.close();
    screenshotControllerSubject.close();

    newMemeTextOffsetSubscription?.cancel();
    saveMemeSubscription?.cancel();
    existenMemeSubscription?.cancel();
    shareMemeSubscription?.cancel();
  }
}
