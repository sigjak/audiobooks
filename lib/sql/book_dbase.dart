import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/book.dart';

class BookDatabase {
  String bookTable = 'sqlBook';
  // String positionTable = 'savedPosition';
  List<String> columnFields = ['bookTitle', 'lastPosition'];
  static final BookDatabase instance = BookDatabase._initialize();

  static Database? _database;
  BookDatabase._initialize();
  Future _createDB(Database db, int version) async {
    const textType = "TEXT NOT NULL";
    const numberType = "INTEGER";
    await db.execute('''CREATE TABLE $bookTable (
      'bookTitle $textType,
      'lastPosition' $numberType
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
    }
  }

  Future<int> createPosition(Book book) async {
    final db = await instance.database;
    int saved = await db!.insert(bookTable, book.toJson());
    return saved;
  }

  Future<Book> getBook(String currentTitle) async {
    final db = await instance.database;
    final maps = await db!.query(bookTable,
        // columns: columnFields,
        where: 'bookTitle = ?',
        whereArgs: [currentTitle]);
    if (maps.isNotEmpty) {
      return Book.fromJson(maps.first);
    } else {
      throw Exception('$currentTitle not found');
    }
  }
}
