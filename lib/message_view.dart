import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

import 'pluralkit.dart';
import 'chat_db.dart';
import 'chat_thread_view.dart';
import 'new_chat_view.dart';
import 'system_notes_view.dart';

class ChatListScreen extends StatefulWidget {
  final SharedPreferences prefs;

  const ChatListScreen({
    Key? key,
    required this.prefs,
  }) : super(key: key);

  @override
  _ChatListScreenState createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  late Future<List<ChatSummary>> _chatsFuture;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    _chatsFuture = ChatDatabase.instance.getChats();
  }

  Future<void> _reload() async {
    setState(() {
      _refresh();
    });
  }

  Future<void> _openNewChat(bool isGroup) async {
    final token = widget.prefs.getString('token');
    if (token == null) {
      return;
    }

    final members = await getMembers(token);
    if (members == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not load members. Check your token.'),
        ),
      );
      return;
    }

    if (!mounted) return;

    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => NewChatScreen(
          members: members,
          isGroup: isGroup,
        ),
      ),
    );

    if (created == true) {
      await _reload();
    }
  }

  void _showNewChatOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.person),
                title: const Text('New chat'),
                subtitle: const Text('Start a conversation with one member'),
                onTap: () {
                  Navigator.of(context).pop();
                  _openNewChat(false);
                },
              ),
              ListTile(
                leading: const Icon(Icons.group),
                title: const Text('New group'),
                subtitle:
                    const Text('Start a conversation with multiple members'),
                onTap: () {
                  Navigator.of(context).pop();
                  _openNewChat(true);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAvatar(ChatSummary chat) {
    if (chat.participants.isEmpty) {
      return const CircleAvatar(child: Icon(Icons.person));
    }

    final first = chat.participants.first;
    final color = (first.memberColor != null)
        ? colorFromString(first.memberColor!)
        : Colors.grey;

    return CircleAvatar(
      backgroundColor: color,
      child: Text(
        first.memberName.isNotEmpty ? first.memberName[0].toUpperCase() : '?',
        style: const TextStyle(color: Colors.white),
      ),
    );
  }

  Widget _buildChatTile(ChatSummary chat) {
    final subtitle = chat.lastMessage ?? 'No messages yet';
    final time = chat.lastTimestamp != null
        ? DateFormat('HH:mm').format(chat.lastTimestamp!)
        : '';

    return ListTile(
      leading: _buildAvatar(chat),
      title: Text(chat.displayName),
      subtitle: Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(time),
      onTap: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ChatThreadScreen(
              prefs: widget.prefs,
              chat: chat,
            ),
          ),
        );

        await _reload();
      },
      onLongPress: () async {
        final delete = await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Delete chat'),
              content: Text(
                'Delete the chat with ${chat.displayName}? '
                'This cannot be undone.',
              ),
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

        if (delete == true) {
          await ChatDatabase.instance.deleteChat(chat.id);
          await _reload();
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sticky_note_2),
            tooltip: 'System notes',
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => SystemNotesScreen(
                    prefs: widget.prefs,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: FutureBuilder<List<ChatSummary>>(
          future: _chatsFuture,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final chats = snapshot.data!;

            if (chats.isEmpty) {
              return ListView(
                children: const [
                  Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'No chats yet. Tap the + button to start one.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              );
            }

            return ListView.builder(
              itemCount: chats.length,
              itemBuilder: (context, index) => _buildChatTile(chats[index]),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showNewChatOptions,
        tooltip: 'New chat',
        child: const Icon(Icons.chat),
      ),
    );
  }
}
