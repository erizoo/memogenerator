// информация нетолько о выделенном тексте но и выделен ли он
import 'dart:ui';

import 'package:equatable/equatable.dart';
import 'package:memogenerator/presentation/create_meme/models/meme_text.dart';

class MemeTextsWithOffset extends Equatable {
  final MemeText memeText;
  final Offset? offset;


  MemeTextsWithOffset({
    required this.memeText,
    required this.offset,
  });

  @override
  List<Object?> get props => [memeText, offset];


}