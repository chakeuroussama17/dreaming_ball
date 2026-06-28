import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/services/chat_service.dart';
import '../../../core/theme/app_colors.dart';

/// A full agent↔admin chat thread (message list + composer). Used by both the
/// agent (their own thread) and the admin (any agent's thread).
class ChatThreadView extends StatefulWidget {
  final String agentId; // whose thread to show
  final bool asAdmin; // is the current viewer the admin?
  const ChatThreadView({super.key, required this.agentId, required this.asAdmin});

  @override
  State<ChatThreadView> createState() => _ChatThreadViewState();
}

class _ChatThreadViewState extends State<ChatThreadView> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _markRead();
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (!_scroll.hasClients) return;
    _scroll.jumpTo(_scroll.position.maxScrollExtent);
  }

  Future<void> _markRead() async {
    if (widget.asAdmin) {
      await ChatService.markReadAsAdmin(widget.agentId);
    } else {
      await ChatService.markReadAsAgent();
    }
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    _input.clear();
    try {
      if (widget.asAdmin) {
        await ChatService.sendAsAdmin(widget.agentId, text);
      } else {
        await ChatService.sendAsAgent(text);
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<List<SupportMessage>>(
            stream: ChatService.threadStream(widget.agentId),
            builder: (context, snap) {
              // Oldest first (newest at the bottom), regardless of stream order.
              final msgs = [...(snap.data ?? const <SupportMessage>[])]
                ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
              if (snap.connectionState == ConnectionState.waiting &&
                  msgs.isEmpty) {
                return const Center(
                    child: CircularProgressIndicator(color: AppColors.orange));
              }
              if (msgs.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      widget.asAdmin
                          ? 'No messages yet.'
                          : 'Send a message to request a plan or ask the admin anything.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                          color: scheme.onSurfaceVariant, fontSize: 13),
                    ),
                  ),
                );
              }
              // After new data: mark read + keep the latest message in view.
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _markRead();
                _scrollToBottom();
              });
              return ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                itemCount: msgs.length,
                itemBuilder: (_, i) => _bubble(msgs[i], scheme),
              );
            },
          ),
        ),
        _composer(scheme),
      ],
    );
  }

  Widget _bubble(SupportMessage m, ColorScheme scheme) {
    // "Mine" = authored by the current viewer.
    final mine = m.isAdmin == widget.asAdmin;
    final bg = mine ? AppColors.orange : scheme.surfaceContainerHighest;
    final fg = mine ? Colors.white : scheme.onSurface;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(mine ? 16 : 4),
            bottomRight: Radius.circular(mine ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment:
              mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(m.body,
                style: GoogleFonts.inter(color: fg, fontSize: 14, height: 1.3)),
            const SizedBox(height: 3),
            Text(DateFormat('d MMM · HH:mm').format(m.createdAt),
                style: GoogleFonts.inter(
                    color: fg.withValues(alpha: 0.7), fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _composer(ColorScheme scheme) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _input,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(
                  hintText: 'Type a message…',
                  filled: true,
                  fillColor: scheme.surfaceContainerHighest,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _sending ? null : _send,
              style: IconButton.styleFrom(backgroundColor: AppColors.orange),
              icon: const Icon(Icons.send_rounded, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
