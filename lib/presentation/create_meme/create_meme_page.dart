import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:memogenerator/presentation/create_meme/create_meme_bloc.dart';
import 'package:memogenerator/presentation/create_meme/font_settings_bottom_sheet.dart';
import 'package:memogenerator/presentation/create_meme/meme_text_on_canvas.dart';

import 'package:memogenerator/presentation/create_meme/models/meme_text.dart';
import 'package:memogenerator/presentation/create_meme/models/meme_text_with_offset.dart';
import 'package:memogenerator/presentation/create_meme/models/meme_text_with_selection.dart';
import 'package:memogenerator/presentation/main/main_bloc.dart';
import 'package:memogenerator/presentation/widgets/app_button.dart';
import 'package:memogenerator/resources/app_colors.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'package:screenshot/screenshot.dart';

class CreateMemePage extends StatefulWidget {
  final String? id;
  final String? selectedMemePath;

  const CreateMemePage({
    Key? key,
    this.id,
    this.selectedMemePath,
  }) : super(key: key);

  @override
  State<CreateMemePage> createState() => _CreateMemePageState();
}

class _CreateMemePageState extends State<CreateMemePage> {
  late CreateMemeBloc bloc;

  @override
  void initState() {
    super.initState();
    bloc = CreateMemeBloc(
      id: widget.id,
      selectedMemePath: widget.selectedMemePath,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Provider.value(
      value: bloc,
      child: WillPopScope(
        onWillPop: () async {
          final allSaved = await bloc.isAllSaved();
          if (allSaved) {
            return true;
          }
          final goBack = await showConfirmationExitDualog(context);
          // нажали вне нашего диалога
          return goBack ?? false;
        },
        child: Scaffold(
          resizeToAvoidBottomInset: false,
          appBar: AppBar(
            backgroundColor: AppColors.lemon,
            foregroundColor: AppColors.darkGrey,
            title: Text("Создаем мем"),
            bottom: EditTextBar(),
            actions: [
              AnimatedIconButton(
                onTap: () => bloc.shareMeme(),
                icon: Icons.share,
              ),
              AnimatedIconButton(
                onTap: () => bloc.saveMeme(),
                icon: Icons.save,
              ),
            ],
          ),
          backgroundColor: Colors.white,
          body: SafeArea(
            child: CreateMemePageContent(),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    bloc.dispose();
    super.dispose();
  }

  Future<bool?> showConfirmationExitDualog(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Хотите выйти?"),
          actionsPadding: EdgeInsets.symmetric(horizontal: 16),
          content: Text("Вы потеряете несохраненные изменения"),
          actions: [
            AppButton(
              onTap: () {
                Navigator.of(context).pop(false);
              },
              text: "Отмена",
              color: AppColors.darkGrey,
            ),
            AppButton(
              onTap: () {
                Navigator.of(context).pop(true);
              },
              text: "Выйти",
            ),
          ],
        );
      },
    );
  }
}

class SaveButton extends StatefulWidget {
  const SaveButton({
    Key? key,
  }) : super(key: key);

  @override
  State<SaveButton> createState() => _SaveButtonState();
}

class _SaveButtonState extends State<SaveButton> {
  double scale = 1.0; // для анимации

  @override
  Widget build(BuildContext context) {
    final bloc = Provider.of<CreateMemeBloc>(context, listen: false);
    return GestureDetector(
      onTap: () {
        setState(() => scale = 1.5);
        bloc.saveMeme();
      },
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: AnimatedScale(
          scale: scale,
          duration: Duration(milliseconds: 200),
          child: Icon(
            Icons.save,
            color: AppColors.darkGrey,
            // size: 24,
          ),
          onEnd: () => setState(() => scale = 1.0), // в изначальное состояние
        ),
      ),
    );
  }
}

class AnimatedIconButton extends StatefulWidget {
  final VoidCallback onTap;
  final IconData icon;

  const AnimatedIconButton({
    Key? key,
    required this.onTap,
    required this.icon,
  }) : super(key: key);

  @override
  State<AnimatedIconButton> createState() => _AnimatedIconButtonState();
}

class _AnimatedIconButtonState extends State<AnimatedIconButton> {
  double scale = 1.0; // для анимации


  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        setState(() => scale = 1.5);
        widget.onTap();
      },
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: AnimatedScale(
          scale: scale,
          curve: Curves.bounceInOut,
          duration: Duration(milliseconds: 300),
          child: Icon(
            widget.icon,
            color: AppColors.darkGrey,
            // size: 24,
          ),
          onEnd: () => setState(() => scale = 1.0), // в изначальное состояние
        ),
      ),
    );
  }
}

class EditTextBar extends StatefulWidget implements PreferredSizeWidget {
  const EditTextBar({Key? key}) : super(key: key);

  @override
  State<EditTextBar> createState() => _EditTextBarState();

  @override
  // TODO: implement preferredSize
  Size get preferredSize => Size.fromHeight(68);
}

class _EditTextBarState extends State<EditTextBar> {
  final controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final bloc = Provider.of<CreateMemeBloc>(context, listen: false);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: StreamBuilder<MemeText?>(
          stream: bloc.observeSelectedMemeText(),
          builder: (context, snapshot) {
            final MemeText? selectedMemeText =
                snapshot.hasData ? snapshot.data : null;
            // занового обновление TextField
            if (selectedMemeText?.text != controller.text) {
              final newText = selectedMemeText?.text ?? "";
              controller.text = newText;
              controller.selection =
                  TextSelection.collapsed(offset: newText.length);
            }
            final haveSelected = selectedMemeText != null;
            return TextField(
              enabled: haveSelected,
              controller: controller,
              onChanged: (text) {
                if (haveSelected) {
                  bloc.changeMemeText(selectedMemeText.id, text);
                }
              },
              onEditingComplete: () => bloc.deselectMemeText(),
              cursorColor: AppColors.fuchsia,
              decoration: InputDecoration(
                filled: true,
                hintText: haveSelected ? "Ввести текст" : null,
                hintStyle: TextStyle(
                  fontSize: 16,
                  color: AppColors.darkGrey38,
                ),
                fillColor:
                    haveSelected ? AppColors.fuchsia16 : AppColors.darkGrey6,
                disabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.darkGrey38, width: 1),
                ),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.fuchsia38, width: 1),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.fuchsia, width: 2),
                ),
              ),
            );
          }),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}

class CreateMemePageContent extends StatefulWidget {
  @override
  State<CreateMemePageContent> createState() => _CreateMemePageContentState();
}

class _CreateMemePageContentState extends State<CreateMemePageContent> {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          Expanded(
            flex: 2,
            child: MemeCanvasWidget(),
          ),
          Container(
            height: 1,
            width: double.infinity,
            color: AppColors.darkGrey,
          ),
          Expanded(
            flex: 1,
            child: BottomList(),
          ),
        ],
      ),
    );
  }
}

class BottomList extends StatelessWidget {
  const BottomList({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bloc = Provider.of<CreateMemeBloc>(context, listen: false);
    return Container(
      color: Colors.white,
      child: StreamBuilder<List<MemeTextsWithSelection>>(
          stream: bloc.observeMemeTextsWithSelection(),
          initialData: const <MemeTextsWithSelection>[],
          builder: (context, snapshot) {
            final items = snapshot.hasData
                ? snapshot.data!
                : const <MemeTextsWithSelection>[];
            return ListView.separated(
              itemCount: items.length + 1,
              itemBuilder: (BuildContext context, int index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Center(
                      child: AppButton(
                        onTap: () => bloc.addNewText(),
                        text: "Добавить текст",
                        icon: Icons.add,
                      ),
                    ),
                  );
                }
                final item = items[index - 1];
                return BottomMemeText(item: item);
              },
              separatorBuilder: (BuildContext context, int index) {
                if (index == 0) {
                  return const SizedBox.shrink();
                }
                return BottomSeparator();
              },
            );
          }),
    );
  }
}

class BottomSeparator extends StatelessWidget {
  const BottomSeparator({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(left: 16),
      height: 1,
      color: AppColors.darkGrey,
    );
  }
}

class BottomMemeText extends StatelessWidget {
  const BottomMemeText({
    Key? key,
    required this.item,
  }) : super(key: key);

  final MemeTextsWithSelection item;

  @override
  Widget build(BuildContext context) {
    final bloc = Provider.of<CreateMemeBloc>(context, listen: false);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => bloc.selectMemeText(item.memeText.id),
      child: Container(
        height: 48,
        alignment: Alignment.centerLeft,
        color: item.selected ? AppColors.darkGrey16 : null,
        child: Row(
          children: [
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                item.memeText.text,
                style: TextStyle(
                  color: AppColors.darkGrey,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(width: 4),
            BottomMemeTextAction(
              icon: Icons.font_download_outlined,
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  builder: (context) {
                    return Provider.value(
                      value: bloc,
                      child: FontSettingBottomSheet(memeText: item.memeText),
                    );
                  },
                );
              },
            ),
            const SizedBox(width: 4),
            BottomMemeTextAction(
              icon: Icons.delete_forever_outlined,
              onTap: () {
                bloc.deleteMemeText(item.memeText.id);
              },
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}

class BottomMemeTextAction extends StatelessWidget {
  const BottomMemeTextAction({
    Key? key,
    required this.onTap,
    required this.icon,
  }) : super(key: key);

  final VoidCallback onTap;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final bloc = Provider.of<CreateMemeBloc>(context, listen: false);
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.all(8),
        child: Icon(icon),
      ),
    );
  }
}

class MemeCanvasWidget extends StatelessWidget {
  const MemeCanvasWidget({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bloc = Provider.of<CreateMemeBloc>(context, listen: false);
    return Container(
      color: AppColors.darkGrey38,
      padding: const EdgeInsets.all(8),
      alignment: Alignment.topCenter,
      child: AspectRatio(
        aspectRatio: 1,
        child: GestureDetector(
          // при нажатии на свободное поле, сбрасывается выделенеие текста в поле ввода
          // с помощью bloc.deselectMemeText()
          onTap: () => bloc.deselectMemeText(),
          child: StreamBuilder<ScreenshotController>(
            stream: bloc.observeScreenshotController(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const SizedBox.shrink();
              }
              return Screenshot(
                controller: snapshot.requireData,
                child: Stack(
                  children: [
                    BackgroundImage(),
                    MemeTexts(),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class MemeTexts extends StatelessWidget {
  const MemeTexts({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bloc = Provider.of<CreateMemeBloc>(context, listen: false);
    return StreamBuilder<List<MemeTextsWithOffset>>(
      initialData: const <MemeTextsWithOffset>[],
      stream: bloc.observeMemeTextWithOffsets(),
      builder: (context, snapshot) {
        final memeTextWithOffsets =
            snapshot.hasData ? snapshot.data! : const <MemeTextsWithOffset>[];
        return LayoutBuilder(builder: (context, constraints) {
          return Stack(
            children: memeTextWithOffsets.map((memeTextWithOffsets) {
              return DraggableMemeText(
                key: ValueKey(memeTextWithOffsets.memeText.id),
                memeTextWithOffset: memeTextWithOffsets,
                parentConstraints: constraints,
              );
            }).toList(),
          );
        });
      },
    );
  }
}

class BackgroundImage extends StatelessWidget {
  const BackgroundImage({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bloc = Provider.of<CreateMemeBloc>(context, listen: false);
    return StreamBuilder<String?>(
        stream: bloc.observeMemePath(),
        builder: (context, snapshot) {
          final path = snapshot.hasData ? snapshot.data : null;
          if (path == null) {
            return Container(
              color: Colors.white,
            );
          }
          return Image.file(File(path));
        });
  }
}

class DraggableMemeText extends StatefulWidget {
  final MemeTextsWithOffset memeTextWithOffset;
  final BoxConstraints parentConstraints;

  const DraggableMemeText({
    Key? key,
    required this.memeTextWithOffset,
    required this.parentConstraints,
  }) : super(key: key);

  @override
  State<DraggableMemeText> createState() => _DraggableMemeTextState();
}

class _DraggableMemeTextState extends State<DraggableMemeText> {
  // для изменения позиции виджета
  late double top;
  late double left;
  final double padding = 8;

  @override
  void initState() {
    super.initState();

    top = widget.memeTextWithOffset.offset?.dy ??
        widget.parentConstraints.maxHeight / 2;
    left = widget.memeTextWithOffset.offset?.dx ??
        widget.parentConstraints.maxWidth / 3;
    // сохранение текста, если вышли в другое меню там,
    // где мы начали его добавлять при вводе текста,
    if (widget.memeTextWithOffset.offset == null) {
      WidgetsBinding.instance?.addPostFrameCallback((timeStamp) {
        final bloc = Provider.of<CreateMemeBloc>(context, listen: false);
        bloc.changeMemeTextOffset(
          widget.memeTextWithOffset.memeText.id,
          Offset(left, top),
        );
      });
    }
    //
  }

  @override
  Widget build(BuildContext context) {
    final bloc = Provider.of<CreateMemeBloc>(context, listen: false);

    return Positioned(
      top: top,
      left: left,
      child: GestureDetector(
        // behavior для изменения перетаскивания
        behavior: HitTestBehavior.opaque,
        onTap: () => bloc.selectMemeText(widget.memeTextWithOffset.memeText.id),
        // для перетаскивание widget переопределяем onPanUpdate
        onPanUpdate: (details) {
          bloc.selectMemeText(widget.memeTextWithOffset.memeText.id);
          setState(() {
            left = calculateLeft(details);
            top = calculateTop(details);
            bloc.changeMemeTextOffset(
                widget.memeTextWithOffset.memeText.id, Offset(left, top));
          });
        },
        // получение инфы о выделенным текстом
        child: StreamBuilder<MemeText?>(
            stream: bloc.observeSelectedMemeText(),
            builder: (context, snapshot) {
              // selected для выделения текста
              final selectItem = snapshot.hasData ? snapshot.data : null;
              final selected =
                  widget.memeTextWithOffset.memeText.id == selectItem?.id;
              return MemeTextOnCanvas(
                padding: padding,
                selected: selected,
                parentConstraints: widget.parentConstraints,
                text: widget.memeTextWithOffset.memeText.text,
                fontSize: widget.memeTextWithOffset.memeText.fontSize,
                color: widget.memeTextWithOffset.memeText.color,
                fontWeight: widget.memeTextWithOffset.memeText.fontWeight,
              );
            }),
      ),
    );
  }

  // метод ограничения передвижения виджета веерх и вниз до границ экрана
  double calculateTop(DragUpdateDetails details) {
    final rawTop = top + details.delta.dy;
    if (rawTop < 0) {
      return 0;
    }
    if (rawTop > widget.parentConstraints.maxHeight - padding * 2 - 24) {
      return widget.parentConstraints.maxHeight - padding * 2 - 24;
    }
    return rawTop;
  }

// метод ограничения передвижения виджета влево и вправо до границ экрана
  double calculateLeft(DragUpdateDetails details) {
    final rawLeft = left + details.delta.dx;
    if (rawLeft < 0) {
      return 0;
    }
    if (rawLeft > widget.parentConstraints.maxWidth - padding * 2 - 10) {
      return widget.parentConstraints.maxWidth - padding * 2 - 10;
    }
    return rawLeft;
  }
}
