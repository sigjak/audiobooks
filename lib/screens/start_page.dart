import 'dart:typed_data';
import 'package:audiobook_app/sql/sql_functions.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audiotagger/audiotagger.dart';
import 'package:provider/provider.dart';
import '../sql/sql_functions.dart';
import 'page_two.dart';
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
  List<Directory> dirList = []; // list of Directory paths of available books
  List<Book> bookList = [];
  bool isLoaded = false;

  @override
  void initState() {
    getBooksData().then((_) {
      setState(() {
        isLoaded = true;
      });
    });
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

  Future<void> getBooksData() async {
    dirList = [];
    bookList = [];
    listOfSections = [];
    String basePath = await getDirPath();
    Directory dir = Directory(basePath);

    List<Book> availableBooks = [];

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
    // print('mmmmmmmmmmmmmmmmmmmmmmmmmmm');
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
    bookList = [...availableBooks];
  }

  Future<void> deleteAlert(int index, String bookName) async {
    bool isDload = false;
    return showDialog(
        barrierDismissible: true,
        context: context,
        builder: (BuildContext context) {
          return StatefulBuilder(builder: (context, setState) {
            return AlertDialog(
              title: const Text(
                'Warning!',
                textAlign: TextAlign.center,
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  isDload
                      ? const Text(
                          'Deleting...',
                          style: TextStyle(
                              fontStyle: FontStyle.italic, fontSize: 18),
                        )
                      : const SizedBox(),
                  const Text(
                    'Delete this audiobook?',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              actions: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        child: const Text('Cancel')),
                    TextButton(
                      onPressed: () async {
                        // remove from database
                        setState(() {
                          isDload = true;
                        });
                        Future.delayed(const Duration(seconds: 2));
                        await context
                            .read<SqlFunctions>()
                            .deleteBookEntry(bookName);
                        // print('INdex nnnn    $index');
                        // print(bookName);
                        setState(() {
                          bookList.removeAt(index);
                        });
                        Directory dir = dirList[index];
                        dir.deleteSync(recursive: true);

                        setState(() {
                          isDload = false;
                          isLoaded = false;
                        });

                        await getBooksData().then((_) {
                          setState(() {
                            isLoaded = true;
                          });
                        });
                        //print(isLoaded);
                        Navigator.of(context).pop();
                      },
                      child: const Text(
                        'OK',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                )
              ],
            );
          });
        });
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
          width: double.infinity,
          decoration: const BoxDecoration(
            image: DecorationImage(
                image: AssetImage("assets/images/handr.png"),
                fit: BoxFit.cover,
                colorFilter:
                    ColorFilter.mode(Colors.blueGrey, BlendMode.modulate)),
          ),
          child: Column(
            children: [
              // const SizedBox(
              //   height: 40,
              // ),
              // isDload ? const CircularProgressIndicator() : const SizedBox(),
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text(
                  'Select audiobook',
                  style: TextStyle(fontSize: 32),
                ),
              ),
              (isLoaded && bookList.isEmpty)
                  ? const Text(
                      'No Books available!',
                      style: TextStyle(fontSize: 24),
                    )
                  : isLoaded
                      ? Flexible(
                          child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: bookList.length,
                              itemBuilder: (context, index) {
                                final bookData = bookList[index];
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
                                          image:
                                              MemoryImage(bookData.bookImage!),
                                        ),
                                      ),
                                      title: Text(bookData.bookTitle!),
                                      subtitle: Text(bookData.bookAuthor!),
                                      trailing: IconButton(
                                        onPressed: () async {
                                          await deleteAlert(
                                              index, bookData.bookTitle!);

                                          // setState(() {
                                          //   isLoaded = false;
                                          // });
                                          // // getBooksData().then((_) {
                                          // //   setState(() {
                                          // //     isLoaded = true;
                                          // //   });
                                          // // });

                                          // Directory dir = dirList[index];
                                          // dir.deleteSync(recursive: true);
                                          // // remove from database
                                          // await context
                                          //     .read<SqlFunctions>()
                                          //     .deleteBookEntry(bookData.bookTitle!);
                                          // setState(() {
                                          //   bookList.removeAt(index);
                                          // });
                                          // print('BACKIN     NNNNNNNNN');
                                          // setState(() {
                                          //   isLoaded = false;
                                          // });
                                          await getBooksData().then((_) {
                                            setState(() {
                                              isLoaded = true;
                                            });
                                          });
                                          //  print(isLoaded);
                                        },
                                        icon: const Icon(Icons.delete),
                                      ),
                                    ),
                                  ),
                                );
                              }),
                        )
                      : const CircularProgressIndicator(),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.small(
        child: const Icon(Icons.exit_to_app),
        onPressed: () {
          dispose();
          SystemChannels.platform.invokeMethod('SystemNavigator.pop');
        },
      ),
    );
  }
}
