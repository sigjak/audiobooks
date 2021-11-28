import 'dart:io';

import 'dart:typed_data';

class Book {
  String? bookTitle;
  Uint8List? bookImage;
  Directory? bookDirectory;
  String? bookAuthor;

  Book({this.bookTitle, this.bookImage, this.bookDirectory, this.bookAuthor});
}
