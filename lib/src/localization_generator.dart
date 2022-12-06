import 'dart:async';
import 'dart:io';

import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import 'package:source_gen/source_gen.dart';

import 'csv_parser.dart';
import 'sheet_localization.dart';

class LocalizationGenerator extends GeneratorForAnnotation<SheetLocalization> {
  @override
  FutureOr<String> generateForAnnotatedElement(
      Element element, ConstantReader annotation, BuildStep buildStep) {
    final docId = annotation.read('docId');
    if (docId.isNull) {
      return _generateSourceFromLocalData(element, annotation);
    } else {
      return _generateSourceFromGS(element, annotation);
    }
  }

  Future<String> _generateSourceFromGS(
    Element element,
    ConstantReader annotation,
  ) async {
    final headers = {
      'Content-Type': 'text/csv; charset=utf-8',
      'Accept': '*/*'
    };
    final response = await http.get(
        Uri.parse(
            'https://docs.google.com/spreadsheets/export?format=csv&id=${annotation.read('docId').stringValue}'),
        headers: headers);
    final classBuilder = StringBuffer();
    classBuilder.writeln(
        '// Generated at: ${_formatDateWithOffset(DateTime.now().toLocal())}');
    classBuilder.writeln('class ${element.displayName.substring(1)}{');
    if (response.statusCode == 200) {
      final outputDir = annotation.read('outDir').stringValue;
      final outputFileName = annotation.read('outName').stringValue;
      final preservedKeywords = annotation
          .read('preservedKeywords')
          .listValue
          .map((e) => e.toStringValue())
          .toList();
      final current = Directory.current;
      final output = Directory.fromUri(Uri.parse(outputDir));
      final outputPath =
          Directory(path.join(current.path, output.path, outputFileName));

      final generatedFile = File(outputPath.path);
      if (!generatedFile.existsSync()) {
        generatedFile.createSync(recursive: true);
      }
      generatedFile.writeAsBytesSync(response.bodyBytes);
      final csvParser = CSVParser(response.body);
      classBuilder.writeln(csvParser.getSupportedLocales());
      classBuilder
          .writeln(csvParser.generateTranslationUsages(preservedKeywords));
    } else {
      throw Exception('http reasonPhrase: ${response.reasonPhrase}');
    }
    classBuilder.writeln('}');
    return classBuilder.toString();
  }

  Future<String> _generateSourceFromLocalData(
      Element element, ConstantReader annotation) async {
    final classBuilder = StringBuffer();
    classBuilder.writeln(
        '// Generated at: ${_formatDateWithOffset(DateTime.now().toLocal())}');
    classBuilder.writeln('class ${element.displayName.substring(1)}{');

    final dirFile = annotation.read('outDir').stringValue;
    final fileName = annotation.read('outName').stringValue;
    final preservedKeywords = annotation
        .read('preservedKeywords')
        .listValue
        .map((e) => e.toStringValue())
        .toList();

    final current = Directory.current;
    final output = Directory.fromUri(Uri.parse(dirFile));
    final fullPathFile =
        Directory(path.join(current.path, output.path, fileName));

    final localFile = File(fullPathFile.path);
    if (localFile.existsSync()) {
      final data = await localFile.readAsString();
      final csvParser = CSVParser(data);

      classBuilder.writeln(csvParser.getSupportedLocales());
      classBuilder
          .writeln(csvParser.generateTranslationUsages(preservedKeywords));
      classBuilder.writeln('}');
      return classBuilder.toString();
    } else {
      throw Exception('File missing, path: ${fullPathFile.path}');
    }
  }

  String _formatDateWithOffset(DateTime date,
      {String format = 'EEE, dd MMM yyyy HH:mm:ss'}) {
    String twoDigits(int n) => n >= 10 ? "$n" : "0$n";

    final hours = twoDigits(date.timeZoneOffset.inHours.abs());
    final minutes = twoDigits(date.timeZoneOffset.inMinutes.remainder(60));
    final sign = date.timeZoneOffset.inHours > 0 ? "+" : "-";
    final formattedDate = DateFormat(format).format(date);

    return "$formattedDate $sign$hours:$minutes";
  }
}
