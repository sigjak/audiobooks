import 'package:flutter/cupertino.dart';
import '../models/book.dart';
import './book_dbase.dart';

class SqlFunctions with ChangeNotifier {
  Future getSavedPosition(String currentTitle) async {
    Book positionData = Book(
        bookTitle: currentTitle,
        lastPosition: const Duration(milliseconds: 0),
        sectionIndex: 1);
    try {
      positionData = await BookDatabase.instance.getSavedPosition(currentTitle);
    } catch (e) {}
    return positionData;
  }
}
