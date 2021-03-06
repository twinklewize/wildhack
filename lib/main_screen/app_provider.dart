import 'dart:convert';
import 'dart:io' as io;
import 'dart:math';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart';
import 'package:wildhack/models/file.dart';

enum AppState {
  empty, // когда файлы не загружены в систему
  waiting, // когда они загружены
  loading, // когда файлы анализируются бэком
  loaded, // файлы загружены
}

class AppProvider with ChangeNotifier {
// сначала все файлы попадают сюда
  final List<File> _filesWithoutAnimal = [];

// но если животное на фото будет, то он попадет сюда
  final List<File> _filesWithAnimal = [];

  AppState _appState = AppState.empty;

  AppState get appState {
    return _appState;
  }

  List<File> get filesWithoutAnimal {
    return [..._filesWithoutAnimal];
  }

  List<File> get filesWithAnimal {
    return [..._filesWithAnimal];
  }

  List<File> get allLoadedFiles {
    List<File> loaded = [];
    for (var file in filesWithAnimal) {
      if (file.status == Status.loaded) {
        loaded.add(file);
      }
    }
    for (var file in filesWithoutAnimal) {
      if (file.status == Status.loaded) {
        loaded.add(file);
      }
    }
    return loaded;
  }

  List<File> get allLoadedButEmpty {
    List<File> result = [];
    for (var file in allLoadedFiles) {
      if (file.isAnimal == false) {
        result.add(file);
      }
    }
    return result;
  }

  // выбор файлов при нажатии кнопки "Загрузить"
  Future<void> pickFiles() async {
    notifyListeners();
    List<PlatformFile> _chosenPlatformFiles = [];
    try {
      if (filesWithoutAnimal.isNotEmpty) {
        _chosenPlatformFiles.addAll(
          (await FilePicker.platform.pickFiles(
                type: FileType.image,
                allowMultiple: true,
                onFileLoading: (FilePickerStatus status) => print(status),
              ))
                  ?.files ??
              [],
        );
      } else {
        _chosenPlatformFiles = (await FilePicker.platform.pickFiles(
              type: FileType.image,
              allowMultiple: true,
              onFileLoading: (FilePickerStatus status) => print(status),
            ))
                ?.files ??
            [];
      }
      for (var everyPlatformFile in _chosenPlatformFiles) {
        _filesWithoutAnimal.add(
          File(
            path: everyPlatformFile.path!,
            sizeInBytes: everyPlatformFile.size.toDouble(),
            name: everyPlatformFile.name,
          ),
        );
      }

// // удаление повторяющихся файлов
// _filesWithoutAnimal = filesWithoutAnimal.toSet().toList();
    } on PlatformException catch (e) {
      print(e.toString());
    } catch (e) {
      print(e.toString());
    }
    if (filesWithoutAnimal.isNotEmpty) _appState = AppState.waiting;
    notifyListeners();
  }

// принятие файлов драг-н-дроп зоной
  Future<void> pickFilesWithDragNDrop(List<File> files) async {
// добавление файлов в общий список
    _filesWithoutAnimal.addAll(files);
// // удаление повторяющихся файлов
// _filesWithoutAnimal = filesWithoutAnimal.toSet().toList();
    _appState = AppState.waiting;
    notifyListeners();
  }

// очистить рабочую зону
  Future<void> clearCachedFiles() async {
    notifyListeners();
    try {
      _filesWithoutAnimal.clear();
      _filesWithAnimal.clear();
      _appState = AppState.empty;
    } on PlatformException catch (e) {
      print("PlatformException " + e.toString());
    } catch (e) {
      print(e.toString());
    } finally {}
    notifyListeners();
  }

// отправить загруженные файлы на бэк
  Future<void> sendFilePathsToBackend() async {
    // отправляем список файлов на бэк
    _appState = AppState.loading;
    notifyListeners();
    final url = Uri.parse('http://192.168.50.65:1488/api/parser');
    List<String> filePaths = [];
    for (var chosenFile in filesWithoutAnimal) {
      filePaths.add(chosenFile.path);
    }
    final response = await http.post(
      url,
      headers: {io.HttpHeaders.contentTypeHeader: "application/json"},
      body: json.encode(filePaths),
    );

    // присваиваем всем файлам режим "в обработке"
    for (var chosenFile in _filesWithoutAnimal) {
      chosenFile.status = Status.loading;
    }
    notifyListeners();

    // смотрим, сколько файлов нам нужно получить с бэка
    int howManyFilesShouldWeRecieve = [..._filesWithoutAnimal].length;

    // получаем файлы с бэка, пока не получим все, что нужно
    // отправляем запрос раз в секунду, чтобы не убить сервер
    do {
      await Future.delayed(const Duration(seconds: 1));
      await _getResultFromBackend();
    } while (allLoadedFiles.length < howManyFilesShouldWeRecieve);

    // окончание процесса обработки
    _appState = AppState.loaded;
    notifyListeners();
  }

  // получать результаты с бэка
  Future<void> _getResultFromBackend() async {
    // отправляем запрос на получение списка из нескольких проверенных файлов
    final url = Uri.parse('http://192.168.50.65:1488/api/get');
    final response = await http.post(
      url,
      headers: {io.HttpHeaders.contentTypeHeader: "application/json"},
      body: json.encode({}),
    );
    print(response.body);
    final decodedResponse = jsonDecode(response.body);

    // добавляем каждый пришедший файл в список с животными
    // и удаляем из списка без животных
    for (var responseFile in decodedResponse) {
      if (responseFile != null) {
        if (responseFile['hasAnimal'] == true) {
          // добавление в список с животными
          _filesWithAnimal.add(
            File(
              path: responseFile['path'],
              name: basename(responseFile['path']),
              sizeInBytes:
                  io.File(responseFile['path']).statSync().size.toDouble(),
              isAnimal: responseFile['hasAnimal'],
              status: Status.loaded,
            ),
          );
          // удаление из списка без животных
          _filesWithoutAnimal
              .removeWhere((element) => element.path == responseFile['path']);
        } else {
          // оставляем в папке без животных
          _filesWithoutAnimal
              .firstWhere((file) => file.path == responseFile['path'])
              .status = Status.loaded;
        }
      }
      notifyListeners();
    }
    notifyListeners();
  }

  // отправить загруженные файлы на бэк
  Future<void> sendFilePathsToFakeBackend() async {
    // отправляем список файлов на бэк
    _appState = AppState.loading;
    notifyListeners();

    // присваиваем всем файлам режим "в обработке"
    for (var chosenFile in _filesWithoutAnimal) {
      chosenFile.status = Status.loading;
    }
    notifyListeners();

    // смотрим, сколько файлов нам нужно получить с бэка
    int howManyFilesShouldWeRecieve = [..._filesWithoutAnimal].length;

    // получаем файлы с бэка, пока не получим все, что нужно
    // отправляем запрос раз в секунду, чтобы не убить сервер
    do {
      await Future.delayed(const Duration(seconds: 3));
      _getResultFromFakeBackend();
    } while (allLoadedFiles.length < howManyFilesShouldWeRecieve);

    // окончание процесса обработки
    _appState = AppState.loaded;
    notifyListeners();
  }

  // получать результаты с бэка
  void _getResultFromFakeBackend() async {
    // добавляем каждый пришедший файл в список с животными
    // и удаляем из списка без животных
    for (var file in _filesWithoutAnimal) {
      Random random = Random();
      if (random.nextInt(2) == 0) {
        _filesWithAnimal.add(file);
        _filesWithoutAnimal.remove(file);
        file.isAnimal = true;
        file.status = Status.loaded;
      } else {
        // оставляем в папке без животных
        file.isAnimal = false;
        file.status = Status.loaded;
      }
      notifyListeners();
    }
  }
}
