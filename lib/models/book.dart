import 'dart:io';

import 'dart:typed_data';

class Book {
  String? bookTitle;
  Uint8List? bookImage;
  Directory? bookDirectory;
  String? bookAuthor;
  Duration? lastPosition;
  int? sectionIndex;

  Book(
      {this.bookTitle,
      this.bookImage,
      this.bookDirectory,
      this.bookAuthor,
      this.lastPosition,
      this.sectionIndex});

  Map<String, dynamic> toJson() => {
        'bookTitle': bookTitle,
        'lastPosition': lastPosition!.inMilliseconds,
        'sectionIndex': sectionIndex
      };

  static Book fromJson(Map<String, dynamic> json) => Book(
      bookTitle: json['bookTitle'] as String,
      lastPosition: Duration(milliseconds: json['lastPosition']),
      sectionIndex: json['sectionIndex']);
}
