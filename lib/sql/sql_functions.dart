import 'package:flutter/cupertino.dart';
import '../models/book.dart';
import './book_dbase.dart';

class SqlFunctions with ChangeNotifier {
  Future savePosition(Book book) async {
    try {
      await BookDatabase.instance.initPosition(book);
    } catch (e) {}
  }

  Future<Book> getSavedPosition(String currentTitle) async {
    Book positionData = Book();
    try {
      positionData = await BookDatabase.instance.getSavedPosition(currentTitle);
    } catch (e) {}
    return positionData;
  }

  Future<int> updatePosition(
      String currentTitle, Duration position, int section) async {
    int uppd = 1000;
    try {
      uppd = await BookDatabase.instance
          .updatePosition(currentTitle, position, section);
      return uppd;
    } catch (e) {}
    return uppd;
  }
}
