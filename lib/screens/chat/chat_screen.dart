import 'package:flutter/material.dart';
import 'package:flutter_chat_application/services/websocket_service.dart';
import 'package:flutter_chat_application/storage/secure_storage.dart';
import 'package:flutter_chat_application/widgets/message_input.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

class ChatScreen extends StatefulWidget {
  final String id;
  const ChatScreen({super.key, required this.id});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final WebSocketService _webSocketService = WebSocketService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> _messages = [];
  late String myEmail;
  late String myId;

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
      myEmail = decodedToken['email'];
      myId = decodedToken['sub'];

      await _webSocketService.initSocket();

      _webSocketService.socket.emit('joinConversation', {
        'conversationId': widget.id,
      });

      // Remove any existing listener to avoid duplicates
      _webSocketService.socket.off('historyMessage');
      _webSocketService.socket.on('historyMessage', (data) {
        if (data['status'] != 'success') {
          return;
        } else {
          setState(() {
            _messages = List<Map<String, dynamic>>.from(data['data']);
          });

          // Scroll to the bottom when history is loaded
          _scrollToBottom();
        }
      });

      // Adding the onMessage listener only once
      _webSocketService.socket.off('onMessage'); // Remove previous listener
      _webSocketService.socket.on('onMessage', (data) {
        if (data['status'] != 'success') return;

        setState(() {
          _messages.add(data['data']); // Add new message to the bottom
        });

        // Scroll to the bottom when a new message is added
        _scrollToBottom();
      });
    } catch (e) {
      print(e);
    }
  }

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) {
      return;
    }

    final newMessage = {
      'userId': myId,
      'userEmail': myEmail,
      'conversationId': widget.id,
      'messageText': _messageController.text.trim(),
    };

    _webSocketService.socket.emit('newMessage', newMessage);

    // The listener is already added in _initSocket, so no need to add it here again.
    _messageController.clear();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController
            .position.maxScrollExtent, // Always scroll to the bottom
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Chat")),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(12),
              reverse: false,
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return Align(
                  alignment: message['userEmail'] == myEmail
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: message['userEmail'] == myEmail
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      if (message['userEmail'] != myEmail)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            message['userEmail'] ?? '',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 10, horizontal: 14),
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.75),
                        decoration: BoxDecoration(
                          color: message['userEmail'] == myEmail
                              ? Colors.blueAccent
                              : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          message['messageText'] ?? '',
                          style: TextStyle(
                            color: message['userEmail'] == myEmail
                                ? Colors.white
                                : Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: MessageInput(
              controller: _messageController,
              onSend: _sendMessage,
            ),
          ),
        ],
      ),
    );
  }
}
