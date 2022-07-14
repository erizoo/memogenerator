// информация нетолько о выделенном тексте но и выделен ли он
import 'package:equatable/equatable.dart';
import 'package:memogenerator/presentation/create_meme/models/meme_text.dart';

class MemeTextsWithSelection extends Equatable {
  final MemeText memeText;
  final bool selected;

  MemeTextsWithSelection({
    required this.memeText,
    required this.selected,
  });

  @override
  List<Object?> get props => [memeText, selected];


}