import 'package:flutter/material.dart';

import 'pluralkit.dart';
import 'chat_db.dart';

class NewChatScreen extends StatefulWidget {
  final List<Member> members;
  final bool isGroup;

  const NewChatScreen({
    Key? key,
    required this.members,
    required this.isGroup,
  }) : super(key: key);

  @override
  _NewChatScreenState createState() => _NewChatScreenState();
}

class _NewChatScreenState extends State<NewChatScreen> {
  final _selected = <Member>{};
  final _groupNameController = TextEditingController();

  @override
  void dispose() {
    _groupNameController.dispose();
    super.dispose();
  }

  void _toggle(Member member) {
    setState(() {
      if (widget.isGroup) {
        if (_selected.contains(member)) {
          _selected.remove(member);
        } else {
          _selected.add(member);
        }
      } else {
        _selected.clear();
        _selected.add(member);
      }
    });
  }

  Future<void> _create() async {
    if (_selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one member.')),
      );
      return;
    }

    final participants = _selected
        .map((m) => ChatParticipant(
              memberId: m.id,
              memberName: m.displayName ?? m.name,
              memberColor: m.color,
            ))
        .toList();

    final name = widget.isGroup && _groupNameController.text.trim().isNotEmpty
        ? _groupNameController.text.trim()
        : null;

    await ChatDatabase.instance.createChat(
      name: name,
      isGroup: widget.isGroup,
      participants: participants,
    );

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final sortedMembers = [...widget.members]
      ..sort((a, b) => a.name.compareTo(b.name));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isGroup ? 'New group' : 'New chat'),
      ),
      body: Column(
        children: [
          if (widget.isGroup)
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _groupNameController,
                decoration: const InputDecoration(
                  labelText: 'Group name (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          Expanded(
            child: ListView.builder(
              itemCount: sortedMembers.length,
              itemBuilder: (context, index) {
                final member = sortedMembers[index];
                final selected = _selected.contains(member);

                final color = member.color != null
                    ? colorFromString(member.color!)
                    : Colors.grey;

                return CheckboxListTile(
                  value: selected,
                  onChanged: (_) => _toggle(member),
                  secondary: CircleAvatar(
                    backgroundColor: color,
                    child: Text(
                      member.name.isNotEmpty
                          ? member.name[0].toUpperCase()
                          : '?',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Text(member.displayName ?? member.name),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _create,
        tooltip: 'Create',
        child: const Icon(Icons.check),
      ),
    );
  }
}
