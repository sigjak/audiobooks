import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/book.dart';

class BookDatabase {
  String bookTable = 'sqlBook';
  // String positionTable = 'savedPosition';
  // List<String> columnFields = ['bookTitle', 'lastPosition'];
  static final BookDatabase instance = BookDatabase._initialize();

  static Database? _database;
  BookDatabase._initialize();
  Future _createDB(Database db, int version) async {
    const textType = "TEXT NOT NULL";
    const numberType = "INTEGER";
    await db.execute('''CREATE TABLE $bookTable (
      bookTitle $textType,
      lastPosition $numberType,
      sectionIndex $numberType
    )''');
  }

  Future<Database> _initDB(String fileName) async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, fileName);
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future close() async {
    final db = await instance.database;
    db!.close();
  }

  Future<Database?> get database async {
    if (_database != null) {
      return _database;
    } else {
      _database = await _initDB('positions.db');
      return _database;
    }
  }

  Future<int> initPosition(Book book) async {
    final db = await instance.database;
    int saved = await db!.insert(bookTable, book.toJson());
    return saved;
  }

  Future<Book> getSavedPosition(String currentTitle) async {
    final db = await instance.database;
    final maps = await db!.query(bookTable,
        // columns: columnFields,
        where: 'bookTitle = ?',
        whereArgs: [currentTitle]);
    if (maps.isNotEmpty) {
      return Book.fromJson(maps.first);
    } else {
      return Book(
        bookTitle: 'Nothing saved',
      );
    }
  }

  Future<int> updatePosition(String bookName, Duration pos, int section) async {
    int position = pos.inMilliseconds;
    final db = await instance.database;
    int update = await db!.rawUpdate(''' 
    UPDATE $bookTable SET lastPosition = ?, sectionIndex =? WHERE bookTitle = ?
    ''', [position, section, bookName]);
    return update;
  }

  Future deleteBook(String bookName) async {
    final db = await instance.database;
    await db!.delete(bookTable, where: 'bookTitle = ?', whereArgs: [bookName]);
  }
}
