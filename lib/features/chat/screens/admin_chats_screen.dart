import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/services/chat_service.dart';
import '../../../core/theme/app_colors.dart';

/// Admin inbox: one row per agent thread, newest first, with unread badges.
class AdminChatsScreen extends StatefulWidget {
  const AdminChatsScreen({super.key});

  @override
  State<AdminChatsScreen> createState() => _AdminChatsScreenState();
}

class _AdminChatsScreenState extends State<AdminChatsScreen> {
  late Future<List<SupportThread>> _threads;

  @override
  void initState() {
    super.initState();
    _threads = ChatService.adminThreads();
  }

  Future<void> _refresh() async {
    setState(() => _threads = ChatService.adminThreads());
    await _threads;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agent Chats'),
        actions: [
          IconButton(
              onPressed: _refresh, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.orange,
        onRefresh: _refresh,
        child: FutureBuilder<List<SupportThread>>(
          future: _threads,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(
                  child: CircularProgressIndicator(color: AppColors.orange));
            }
            final threads = snap.data ?? const <SupportThread>[];
            if (threads.isEmpty) {
              return ListView(
                children: [
                  const SizedBox(height: 120),
                  Center(
                    child: Text('No agent messages yet.',
                        style: GoogleFonts.inter(
                            color: scheme.onSurfaceVariant)),
                  ),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: threads.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (_, i) => _tile(threads[i], scheme),
            );
          },
        ),
      ),
    );
  }

  Widget _tile(SupportThread t, ColorScheme scheme) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppColors.orange.withValues(alpha: 0.15),
        child: Text(
          t.fullName.isNotEmpty ? t.fullName[0].toUpperCase() : '?',
          style: const TextStyle(
              color: AppColors.orange, fontWeight: FontWeight.bold),
        ),
      ),
      title: Text(t.fullName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
      subtitle: Text(t.lastBody,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
              fontSize: 12, color: scheme.onSurfaceVariant)),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(DateFormat('d MMM').format(t.lastAt),
              style: GoogleFonts.inter(
                  fontSize: 10, color: scheme.onSurfaceVariant)),
          const SizedBox(height: 4),
          if (t.unread > 0)
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                  color: AppColors.orange, shape: BoxShape.circle),
              child: Text('${t.unread}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      onTap: () async {
        await context.pushNamed('admin-chat-thread',
            pathParameters: {'agentId': t.agentId},
            extra: t.fullName);
        _refresh();
      },
    );
  }
}
