// ============================================================
// Messaging / Chat Screen
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../services/api_service.dart';
import '../../providers/auth_provider.dart';

// ── Providers ─────────────────────────────────────────────────
final chatProvider = FutureProvider.family.autoDispose<List<dynamic>, String>((ref, id) async {
  final resp = await ApiService().get('/messaging/$id/messages');
  return resp['data'] as List<dynamic>;
});

// ── Screen ────────────────────────────────────────────────────
class ChatScreen extends ConsumerStatefulWidget {
  final String conversationId;
  const ChatScreen({super.key, required this.conversationId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _sending = false;

  void _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;

    setState(() => _sending = true);
    try {
      await ApiService().post('/messaging/${widget.conversationId}/messages', body: {'message': text});
      _msgCtrl.clear();
      ref.invalidate(chatProvider(widget.conversationId));
      
      // Scroll to bottom
      Future.delayed(const Duration(milliseconds: 300), () {
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send: $e'), backgroundColor: AppTheme.error));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _updateStatus(String status) async {
    try {
      await ApiService().patch('/messaging/${widget.conversationId}/status', body: {'status': status});
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Marked as $status'), backgroundColor: AppTheme.statusGreen));
      ref.invalidate(chatProvider(widget.conversationId));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatAsync = ref.watch(chatProvider(widget.conversationId));
    final authState = ref.watch(authNotifierProvider);
    final isTeacher = authState.valueOrNull?.role != 'parent';

    return Scaffold(
      backgroundColor: AppTheme.grey50,
      appBar: AppBar(
        title: const Text('Thread'),
        actions: [
          if (isTeacher)
            PopupMenuButton<String>(
              onSelected: _updateStatus,
              itemBuilder: (ctx) => const [
                PopupMenuItem(value: 'resolved', child: Text('Mark as Resolved')),
                PopupMenuItem(value: 'closed', child: Text('Close Conversation')),
                PopupMenuItem(value: 'open', child: Text('Reopen')),
              ],
            )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: chatAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error: $err', style: const TextStyle(color: AppTheme.error))),
              data: (messages) {
                if (messages.isEmpty) return const Center(child: Text('No messages'));
                return ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (ctx, i) {
                     final msg = messages[i];
                     // If sender_id matches user id, or role logic:
                     // Simplistic layout: if sender_type == my current type, it's "Me" (right aligned).
                     final myRoleType = isTeacher ? 'employee' : 'parent';
                     final isMe = msg['sender_type'] == myRoleType;
                     
                     return _ChatBubble(msg: msg, isMe: isMe);
                  },
                );
              },
            ),
          ),
          
          // Compose Area
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), offset: const Offset(0, -2), blurRadius: 10)]
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _msgCtrl,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                        filled: true,
                        fillColor: AppTheme.grey100,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  CircleAvatar(
                    backgroundColor: AppTheme.primary,
                    child: _sending 
                     ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                     : IconButton(icon: const Icon(Icons.send, color: Colors.white, size: 18), onPressed: _sendMessage),
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final Map<String, dynamic> msg;
  final bool isMe;

  const _ChatBubble({required this.msg, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final dt = DateTime.parse(msg['created_at']).toLocal();
    final timeStr = DateFormat('h:mm a').format(dt);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isMe ? AppTheme.primary : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(0),
            bottomRight: isMe ? const Radius.circular(0) : const Radius.circular(16),
          ),
          border: isMe ? null : Border.all(color: AppTheme.grey200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              msg['body'],
              style: GoogleFonts.poppins(fontSize: 13, color: isMe ? Colors.white : AppTheme.grey900),
            ),
            const SizedBox(height: 4),
            Text(
              timeStr,
              style: GoogleFonts.poppins(fontSize: 10, color: isMe ? Colors.white70 : AppTheme.grey600),
            ),
          ],
        ),
      ),
    );
  }
}
