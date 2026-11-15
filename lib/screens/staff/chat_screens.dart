import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../widgets/staff_ui.dart';

/// Customer support conversations.
class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key, this.initialStatus = 'open'});

  final String? initialStatus;

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  final list = PagedListController();
  late String? status = widget.initialStatus;

  @override
  Widget build(BuildContext context) {
    return PagedList(
      path: '/staff/chats',
      controller: list,
      query: {'status': status},
      searchHint: 'Name, email or phone',
      emptyText: 'No conversations.',
      emptyIcon: Icons.forum_outlined,
      bottomPadding: 24,
      header: FilterChips(options: const {'open': 'Open', 'closed': 'Closed'}, selected: status, onSelected: (v) => setState(() => status = v)),
      itemBuilder: (context, row) {
        final unread = int.tryParse('${row['unread_count']}') ?? 0;
        return RecordCard(
          leading: Badge(
            isLabelVisible: unread > 0,
            label: Text('$unread'),
            child: CircleAvatar(child: Text('${row['name']}'.isEmpty ? '?' : '${row['name']}'[0].toUpperCase())),
          ),
          title: '${row['name']}',
          subtitle: '${row['last_message'] ?? ''}',
          caption: formatDate(row['updated_at'], withTime: true),
          status: '${row['status']}',
          onTap: () async {
            await Navigator.push(context, MaterialPageRoute(builder: (_) => ChatThreadScreen(conversationId: row['id'] as int)));
            list.reload();
          },
        );
      },
    );
  }
}

class ChatThreadScreen extends StatefulWidget {
  const ChatThreadScreen({super.key, required this.conversationId});

  final int conversationId;

  @override
  State<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends State<ChatThreadScreen> {
  final message = TextEditingController();
  final scroll = ScrollController();
  Map<String, dynamic> chat = {};
  bool loading = true;
  bool sending = false;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    message.dispose();
    scroll.dispose();
    super.dispose();
  }

  void apply(Map data) {
    setState(() => chat = Map<String, dynamic>.from(data));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scroll.hasClients) scroll.jumpTo(scroll.position.maxScrollExtent);
    });
  }

  Future<void> load() async {
    final api = context.read<ApiClient>();
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final response = await api.get('/staff/chats/${widget.conversationId}');
      if (mounted) apply((response.data as Map)['data'] as Map);
    } catch (e) {
      if (mounted) setState(() => error = api.messageFromError(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> send() async {
    final text = message.text.trim();
    if (text.isEmpty) return;
    final result = await runApi(
      context,
      (api) => api.post('/staff/chats/${widget.conversationId}/reply', data: {'message': text}),
      busy: (b) => setState(() => sending = b),
    );
    if (result == null || !mounted) return;
    message.clear();
    apply((result.data as Map)['data'] as Map);
  }

  Future<void> close() async {
    if (!await confirmAction(context, title: 'Close conversation?', message: 'It reopens automatically if you reply again.', confirm: 'Close')) return;
    if (!mounted) return;
    final result = await runApi(context, (api) => api.post('/staff/chats/${widget.conversationId}/close'));
    if (result == null || !mounted) return;
    showSuccess(context, 'Conversation closed.');
    setState(() => chat['status'] = 'closed');
  }

  @override
  Widget build(BuildContext context) {
    final messages = (chat['messages'] as List?) ?? const [];
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${chat['name'] ?? 'Conversation'}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            if ((chat['phone'] ?? chat['email']) != null)
              Text('${chat['phone'] ?? chat['email']}', style: const TextStyle(fontSize: 12, color: kMuted)),
          ],
        ),
        actions: [
          if (chat['status'] == 'open') IconButton(tooltip: 'Close conversation', onPressed: close, icon: const Icon(Icons.check_circle_outline)),
          IconButton(tooltip: 'Refresh', onPressed: load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: AsyncBody(
        loading: loading && chat.isEmpty,
        error: error,
        onRetry: load,
        builder: (context) => Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: scroll,
                padding: const EdgeInsets.all(12),
                itemCount: messages.length,
                itemBuilder: (context, i) {
                  final m = Map<String, dynamic>.from(messages[i] as Map);
                  final staff = m['sender_type'] == 'staff';
                  return Align(
                    alignment: staff ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.fromLTRB(12, 9, 12, 7),
                      decoration: BoxDecoration(
                        color: staff ? scheme.primary : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: staff ? null : Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (staff && m['sender_name'] != null)
                            Text('${m['sender_name']}', style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w700)),
                          Text(
                            m['message']?.toString() ?? (m['has_attachment'] == true ? '[Attachment — open on the website]' : ''),
                            style: TextStyle(color: staff ? Colors.white : const Color(0xFF0F172A)),
                          ),
                          const SizedBox(height: 3),
                          Text(formatDate(m['created_at'], withTime: true), style: TextStyle(fontSize: 10.5, color: staff ? Colors.white70 : kFaint)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: message,
                        minLines: 1,
                        maxLines: 4,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(hintText: 'Type a reply', isDense: true),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton.filled(
                      onPressed: sending ? null : send,
                      icon: sending ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
