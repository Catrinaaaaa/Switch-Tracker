import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

import 'pluralkit.dart';
import 'chat_db.dart';

class SystemNotesScreen extends StatefulWidget {
  final SharedPreferences prefs;

  const SystemNotesScreen({
    Key? key,
    required this.prefs,
  }) : super(key: key);

  @override
  _SystemNotesScreenState createState() => _SystemNotesScreenState();
}

class _SystemNotesScreenState extends State<SystemNotesScreen> {
  final _noteController = TextEditingController();
  final _scrollController = ScrollController();

  List<SystemNote> _notes = [];
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  @override
  void dispose() {
    _noteController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadNotes() async {
    final notes = await ChatDatabase.instance.getNotes();

    if (!mounted) return;

    setState(() {
      _notes = notes.reversed.toList();
      _loading = false;
    });

    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(
          _scrollController.position.maxScrollExtent,
        );
      }
    });
  }

  Future<void> _add() async {
    final text = _noteController.text.trim();
    if (text.isEmpty) {
      return;
    }

    setState(() {
      _sending = true;
    });

    try {
      final token = widget.prefs.getString('token');
      String? authorName;

      if (token != null) {
        final front = await getFronters(token);
        if (front != null && front.members.isNotEmpty) {
          final fronter = front.members.first;
          authorName = fronter.displayName ?? fronter.name;
        }
      }

      await ChatDatabase.instance.addNote(
        authorName: authorName,
        content: text,
      );

      _noteController.clear();
      await _loadNotes();
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
  }

  Future<void> _deleteNote(SystemNote note) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete note'),
          content: const Text('Delete this note? This cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      await ChatDatabase.instance.deleteNote(note.id);
      await _loadNotes();
    }
  }

  Widget _buildNote(SystemNote note) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: ListTile(
        title: Text(note.content),
        subtitle: Text(
          '${note.authorName ?? "System"} · '
          '${DateFormat('MMM d, HH:mm').format(note.timestamp)}',
        ),
        onLongPress: () => _deleteNote(note),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('System notes'),
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _notes.isEmpty
                    ? const Center(
                        child: Text('No notes yet. Add one below.'),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        itemCount: _notes.length,
                        itemBuilder: (context, index) =>
                            _buildNote(_notes[index]),
                      ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _noteController,
                    decoration: const InputDecoration(
                      hintText: 'Add a note for the whole system',
                      border: OutlineInputBorder(),
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _add(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _sending ? null : _add,
                  icon: _sending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
