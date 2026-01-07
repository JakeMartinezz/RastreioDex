import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/package.dart';
import '../models/tracking_event.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('rastreiodex.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path, 
      version: 2, 
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE packages (
        trackingCode TEXT PRIMARY KEY,
        customName TEXT,
        type TEXT,
        currentStatus TEXT,
        events TEXT,
        lastUpdate INTEGER,
        estimatedDelivery INTEGER,
        isDelivered INTEGER NOT NULL DEFAULT 0,
        isArchived INTEGER NOT NULL DEFAULT 0,
        orderIndex INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute("ALTER TABLE packages ADD COLUMN isArchived INTEGER NOT NULL DEFAULT 0");
      await db.execute("ALTER TABLE packages ADD COLUMN orderIndex INTEGER NOT NULL DEFAULT 0");
    }
  }

  Future<void> createOrUpdatePackage(Package pkg) async {
    final db = await instance.database;

    // Check if package exists to decide if it's a new one for ordering
    final existing = await db.query('packages', where: 'trackingCode = ?', whereArgs: [pkg.trackingCode]);

    int orderIndex = pkg.orderIndex;
    if (existing.isEmpty) {
      // It's a new package, get the highest orderIndex and add 1
      final maxResult = await db.rawQuery("SELECT MAX(orderIndex) as maxIndex FROM packages");
      final maxIndex = maxResult.first['maxIndex'] as int? ?? 0;
      orderIndex = maxIndex + 1;
    }
    
    final data = {
      'trackingCode': pkg.trackingCode,
      'customName': pkg.customName,
      'type': pkg.type,
      'currentStatus': pkg.currentStatus,
      'events': jsonEncode(pkg.events.map((e) => e.toMap()).toList()),
      'lastUpdate': pkg.lastUpdate?.millisecondsSinceEpoch,
      'estimatedDelivery': pkg.estimatedDelivery?.millisecondsSinceEpoch,
      'isDelivered': pkg.isDelivered ? 1 : 0,
      'isArchived': pkg.isArchived ? 1 : 0,
      'orderIndex': orderIndex,
    };

    await db.insert('packages', data, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Package>> getAllPackages() async {
    final db = await instance.database;
    // Order by the user-defined order
    final result = await db.query('packages', orderBy: 'orderIndex ASC');

    return result.map((json) {
      return Package(
        trackingCode: json['trackingCode'] as String,
        customName: json['customName'] as String?,
        type: json['type'] as String,
        currentStatus: json['currentStatus'] as String,
        events: (jsonDecode(json['events'] as String) as List)
            .map((e) => TrackingEvent.fromMap(e))
            .toList(),
        lastUpdate: json['lastUpdate'] != null 
            ? DateTime.fromMillisecondsSinceEpoch(json['lastUpdate'] as int) 
            : null,
        estimatedDelivery: json['estimatedDelivery'] != null 
            ? DateTime.fromMillisecondsSinceEpoch(json['estimatedDelivery'] as int) 
            : null,
        isDelivered: (json['isDelivered'] as int) == 1,
        isArchived: (json['isArchived'] as int) == 1,
        orderIndex: json['orderIndex'] as int,
      );
    }).toList();
  }

  Future<void> deletePackage(String trackingCode) async {
    final db = await instance.database;
    await db.delete(
      'packages',
      where: 'trackingCode = ?',
      whereArgs: [trackingCode],
    );
  }

  Future<void> toggleArchive(String trackingCode, bool isArchived) async {
    final db = await instance.database;
    await db.update(
      'packages',
      {'isArchived': isArchived ? 1 : 0},
      where: 'trackingCode = ?',
      whereArgs: [trackingCode],
    );
  }

  Future<void> updatePackageOrder(List<Package> packages) async {
    final db = await instance.database;
    final batch = db.batch();
    for (int i = 0; i < packages.length; i++) {
      final pkg = packages[i];
      batch.update(
        'packages',
        {'orderIndex': i},
        where: 'trackingCode = ?',
        whereArgs: [pkg.trackingCode],
      );
    }
    await batch.commit(noResult: true);
  }
}
