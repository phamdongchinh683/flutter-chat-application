import 'package:flutter/material.dart';
import 'package:flutter_chat_application/screens/chat/chat_screen.dart';
import 'package:flutter_chat_application/services/websocket_service.dart';
import 'package:flutter_chat_application/storage/secure_storage.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatListScreen> {
  final WebSocketService _webSocketService = WebSocketService();
  List<Map<String, dynamic>> _chatList = [];

  @override
  void initState() {
    super.initState();
    _initSocket();
  }

  Future<void> _initSocket() async {
    final String? token = await SecureStorage().retrieveToken();

    if (token == null || token.isEmpty) {
      print("No token found");
      return;
    }

    try {
      Map<String, dynamic> decodedToken = JwtDecoder.decode(token);
      await _webSocketService.initSocket();

      _webSocketService.socket.emit('myChats', {'userId': decodedToken['sub']});

      _webSocketService.socket.on('onChats', (data) {
        if (data['status'] != 'success') {
          return;
        } else {
          setState(() {
            _chatList = List<Map<String, dynamic>>.from(data['data']);
          });
        }
      });
    } catch (e) {
      print(e);
    }
  }

  @override
  void dispose() {
    _webSocketService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat List'),
      ),
      body: _chatList.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _chatList.length,
              itemBuilder: (context, index) {
                final chat = _chatList[index];
                final String conversationId = chat['conversationId'];
                final String conversationName = chat['conversationName'];

                return ListTile(
                  
                  title: Text(chat['conversationName']),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatScreen(id: conversationId),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
