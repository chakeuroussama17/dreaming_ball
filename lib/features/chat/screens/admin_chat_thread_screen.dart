import 'package:flutter/material.dart';
import '../widgets/chat_thread_view.dart';

/// Admin viewing one agent's support thread.
class AdminChatThreadScreen extends StatelessWidget {
  final String agentId;
  final String agentName;
  const AdminChatThreadScreen(
      {super.key, required this.agentId, required this.agentName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(agentName)),
      body: ChatThreadView(agentId: agentId, asAdmin: true),
    );
  }
}
