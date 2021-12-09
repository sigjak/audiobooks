import 'dart:io';

import 'dart:typed_data';

class Book {
  String? bookTitle;
  Uint8List? bookImage;
  Directory? bookDirectory;
  String? bookAuthor;
  int? lastPosition;

  Book(
      {this.bookTitle,
      this.bookImage,
      this.bookDirectory,
      this.bookAuthor,
      this.lastPosition});

  Map<String, dynamic> toJson() =>
      {'bookTitle': bookTitle, 'lastPosition': const Duration().inMilliseconds};
  static Book fromJson(Map<String, dynamic> json) => Book(
      bookTitle: json['bookTitle'] as String,
      lastPosition: Duration(milliseconds: json['lastPosition']) as int);
}
