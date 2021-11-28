import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audiotagger/audiotagger.dart';
import './page_two.dart';
import '../models/book.dart';

import 'dart:io';

class StartPage extends StatefulWidget {
  const StartPage({Key? key}) : super(key: key);

  @override
  _StartPageState createState() => _StartPageState();
}

class _StartPageState extends State<StartPage> {
  final tagger = Audiotagger();
  List<List<String>> listOfSections = [];

  @override
  void initState() {
    // getBooks();
    super.initState();
  }

  Future<String> getDirPath() async {
    String path = '';
    final status = await Permission.manageExternalStorage.request();
    if (status.isGranted) {
      List<Directory>? externalStorage = await getExternalStorageDirectories();
      List<String> splitList = [];
      // Choose sd card if available
      if (externalStorage!.length > 1) {
        splitList = externalStorage[1].path.split('/');
      } else {
        splitList = externalStorage[0].path.split('/');
      }
      for (int i = 1; i < splitList.length; i++) {
        if (splitList[i] == 'Android') break;
        path += '/${splitList[i]}';
      }

      return path + '/Audiobooks';
    } else {
      return 'ACCESS DENIED';
    }
  }

  Future<List<Book>> getBooksData() async {
    String basePath = await getDirPath();
    Directory dir = Directory(basePath);

    List<Book> availableBooks = [];
    List<Directory> dirList = []; //is a list of Directory of available books
    if (dir.existsSync()) {
      for (FileSystemEntity f in dir.listSync()) {
        dirList.add(Directory(f.path));
      }
    }

    // make a sections for each book which includes
    // paths to all sections of the book
    // and save to a list of sectionss

    for (int i = 0; i < dirList.length; i++) {
      List<String> sections = [];
      for (FileSystemEntity f in dirList[i].listSync()) {
        sections.add(f.path);
      }
      listOfSections.add(sections);
    }

    for (int i = 0; i < listOfSections.length; i++) {
      Uint8List? tempImage =
          await tagger.readArtwork(path: listOfSections[i][0]);
      var tempTitle = await tagger.readTags(path: listOfSections[i][0]);

      Book tempBook = Book(
          bookTitle: tempTitle!.album,
          bookDirectory: dirList[i],
          bookImage: tempImage,
          bookAuthor: tempTitle.artist);

      availableBooks.add(tempBook);
    }

    return availableBooks;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Audiobooks'),
        centerTitle: true,
      ),
      body: Center(
        child: Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
                image: AssetImage("assets/images/handr.png"),
                fit: BoxFit.cover,
                colorFilter:
                    ColorFilter.mode(Colors.blueGrey, BlendMode.modulate)),
          ),
          child: Column(
            children: [
              const SizedBox(
                height: 40,
              ),
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text(
                  'Select audiobook',
                  style: TextStyle(fontSize: 32),
                ),
              ),
              FutureBuilder<List<Book>>(
                  future: getBooksData(),
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      final data = snapshot.data as List<Book>;
                      return Flexible(
                        child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: data.length,
                            itemBuilder: (context, index) {
                              final bookData = data[index];
                              return GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) => PageTwo(
                                              sections: listOfSections[index],
                                              selectedBook: bookData)));
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20.0),
                                  child: ListTile(
                                    leading: ClipRRect(
                                      child: Image(
                                        image: MemoryImage(bookData.bookImage!),
                                      ),
                                    ),
                                    title: Text(bookData.bookTitle!),
                                    subtitle: Text(bookData.bookAuthor!),
                                  ),
                                ),
                              );
                            }),
                      );
                    } else {
                      return const CircularProgressIndicator();
                    }
                  }),
            ],
          ),
        ),
      ),
    );
  }
}
