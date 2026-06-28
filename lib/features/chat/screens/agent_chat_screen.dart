import 'package:flutter/material.dart';
import '../../../core/services/supabase_service.dart';
import '../widgets/chat_thread_view.dart';

/// The agent's own support thread with the admin.
class AgentChatScreen extends StatelessWidget {
  const AgentChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = SupabaseService.userId;
    return Scaffold(
      appBar: AppBar(title: const Text('Chat with admin')),
      body: uid == null
          ? const Center(child: Text('Please sign in'))
          : ChatThreadView(agentId: uid, asAdmin: false),
    );
  }
}
