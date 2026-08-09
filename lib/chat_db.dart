import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:path/path.dart';

class ChatParticipant {
  final String memberId;
  final String memberName;
  final String? memberColor;

  ChatParticipant({
    required this.memberId,
    required this.memberName,
    this.memberColor,
  });
}

class ChatSummary {
  final int id;
  final String? name;
  final bool isGroup;
  final List<ChatParticipant> participants;
  final String? lastMessage;
  final DateTime? lastTimestamp;

  ChatSummary({
    required this.id,
    required this.name,
    required this.isGroup,
    required this.participants,
    this.lastMessage,
    this.lastTimestamp,
  });

  String get displayName {
    if (name != null && name!.isNotEmpty) {
      return name!;
    }
    return participants.map((p) => p.memberName).join(', ');
  }
}

class ChatMessage {
  final int id;
  final int chatId;
  final String? senderMemberId;
  final String senderName;
  final String? senderColor;
  final String content;
  final DateTime timestamp;

  ChatMessage({
    required this.id,
    required this.chatId,
    required this.senderMemberId,
    required this.senderName,
    required this.senderColor,
    required this.content,
    required this.timestamp,
  });
}

class SystemNote {
  final int id;
  final String? authorName;
  final String content;
  final DateTime timestamp;

  SystemNote({
    required this.id,
    required this.authorName,
    required this.content,
    required this.timestamp,
  });
}

class ChatDatabase {
  static final ChatDatabase instance = ChatDatabase._internal();
  static sqflite.Database? _db;

  ChatDatabase._internal();

  Future<sqflite.Database> get _database async {
    if (_db != null) {
      return _db!;
    }

    _db = await _open();
    return _db!;
  }

  Future<sqflite.Database> _open() async {
    final dbPath = await sqflite.getDatabasesPath();
    final fullPath = join(dbPath, 'switch_tracker_chats.db');

    return sqflite.openDatabase(
      fullPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE chats (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT,
            is_group INTEGER NOT NULL,
            created_at TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE chat_participants (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            chat_id INTEGER NOT NULL,
            member_id TEXT NOT NULL,
            member_name TEXT NOT NULL,
            member_color TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE messages (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            chat_id INTEGER NOT NULL,
            sender_member_id TEXT,
            sender_name TEXT NOT NULL,
            sender_color TEXT,
            content TEXT NOT NULL,
            timestamp TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE system_notes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            author_name TEXT,
            content TEXT NOT NULL,
            timestamp TEXT NOT NULL
          )
        ''');
      },
    );
  }

  Future<int> createChat({
    String? name,
    required bool isGroup,
    required List<ChatParticipant> participants,
  }) async {
    final db = await _database;

    final chatId = await db.insert('chats', {
      'name': name,
      'is_group': isGroup ? 1 : 0,
      'created_at': DateTime.now().toIso8601String(),
    });

    for (final participant in participants) {
      await db.insert('chat_participants', {
        'chat_id': chatId,
        'member_id': participant.memberId,
        'member_name': participant.memberName,
        'member_color': participant.memberColor,
      });
    }

    return chatId;
  }

  Future<List<ChatSummary>> getChats() async {
    final db = await _database;

    final chatRows = await db.query('chats', orderBy: 'id DESC');
    final summaries = <ChatSummary>[];

    for (final row in chatRows) {
      final chatId = row['id'] as int;

      final participantRows = await db.query(
        'chat_participants',
        where: 'chat_id = ?',
        whereArgs: [chatId],
      );

      final participants = participantRows
          .map((p) => ChatParticipant(
                memberId: p['member_id'] as String,
                memberName: p['member_name'] as String,
                memberColor: p['member_color'] as String?,
              ))
          .toList();

      final lastMessageRows = await db.query(
        'messages',
        where: 'chat_id = ?',
        whereArgs: [chatId],
        orderBy: 'id DESC',
        limit: 1,
      );

      String? lastMessage;
      DateTime? lastTimestamp;

      if (lastMessageRows.isNotEmpty) {
        lastMessage = lastMessageRows.first['content'] as String;
        lastTimestamp =
            DateTime.parse(lastMessageRows.first['timestamp'] as String);
      }

      summaries.add(ChatSummary(
        id: chatId,
        name: row['name'] as String?,
        isGroup: (row['is_group'] as int) == 1,
        participants: participants,
        lastMessage: lastMessage,
        lastTimestamp: lastTimestamp,
      ));
    }

    summaries.sort((a, b) {
      if (a.lastTimestamp == null && b.lastTimestamp == null) return 0;
      if (a.lastTimestamp == null) return 1;
      if (b.lastTimestamp == null) return -1;
      return b.lastTimestamp!.compareTo(a.lastTimestamp!);
    });

    return summaries;
  }

  Future<List<ChatMessage>> getMessages(int chatId) async {
    final db = await _database;

    final rows = await db.query(
      'messages',
      where: 'chat_id = ?',
      whereArgs: [chatId],
      orderBy: 'id ASC',
    );

    return rows
        .map((row) => ChatMessage(
              id: row['id'] as int,
              chatId: row['chat_id'] as int,
              senderMemberId: row['sender_member_id'] as String?,
              senderName: row['sender_name'] as String,
              senderColor: row['sender_color'] as String?,
              content: row['content'] as String,
              timestamp: DateTime.parse(row['timestamp'] as String),
            ))
        .toList();
  }

  Future<int> sendMessage({
    required int chatId,
    required String? senderMemberId,
    required String senderName,
    required String? senderColor,
    required String content,
  }) async {
    final db = await _database;

    return db.insert('messages', {
      'chat_id': chatId,
      'sender_member_id': senderMemberId,
      'sender_name': senderName,
      'sender_color': senderColor,
      'content': content,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  Future<void> deleteChat(int chatId) async {
    final db = await _database;

    await db.delete('messages', where: 'chat_id = ?', whereArgs: [chatId]);
    await db
        .delete('chat_participants', where: 'chat_id = ?', whereArgs: [chatId]);
    await db.delete('chats', where: 'id = ?', whereArgs: [chatId]);
  }

  Future<List<SystemNote>> getNotes() async {
    final db = await _database;

    final rows = await db.query('system_notes', orderBy: 'id DESC');

    return rows
        .map((row) => SystemNote(
              id: row['id'] as int,
              authorName: row['author_name'] as String?,
              content: row['content'] as String,
              timestamp: DateTime.parse(row['timestamp'] as String),
            ))
        .toList();
  }

  Future<int> addNote({
    required String? authorName,
    required String content,
  }) async {
    final db = await _database;

    return db.insert('system_notes', {
      'author_name': authorName,
      'content': content,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  Future<void> deleteNote(int id) async {
    final db = await _database;
    await db.delete('system_notes', where: 'id = ?', whereArgs: [id]);
  }
}
