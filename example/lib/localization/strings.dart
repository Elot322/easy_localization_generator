import 'dart:ui';

import 'package:easy_localization/easy_localization.dart';
import 'package:easy_localization_generator/easy_localization_generator.dart';

part 'strings.g.dart';

@SheetLocalization(
  version: 1,
  outDir: 'assets/langs',
  outName: 'langs.csv',
  preservedKeywords: [
    'few',
    'many',
    'one',
    'other',
    'two',
    'zero',
    'male',
    'female',
  ],
)
class _Strings {}
