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
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initSocket();
  }

  String _formatDateTime(String? dateTimeStr) {
    if (dateTimeStr == null) return 'Unknown';
    try {
      final dateTime = DateTime.parse(dateTimeStr);
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Unknown';
    }
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

      _webSocketService.socket.off('onMessageHistory');
      _webSocketService.socket.on('onMessageHistory', (data) {
        if (data['status'] != 'success') {
          return;
        } else {
          setState(() {
            _messages = List<Map<String, dynamic>>.from(data['data']);
          });

          _scrollToBottom();
        }
      });

      _webSocketService.socket.off('onMessage');
      _webSocketService.socket.on('onMessage', (data) {
        print(data);
        if (data['status'] != 'success') {
          return;
        } else if (data['data'].length > 2) {
          setState(() {
            _messages.add(data['data']);
          });

          _scrollToBottom();
        } else if (data['data'].length == 2) {
          setState(() {
            _messages.firstWhere((message) =>
                    message['id'] == data['data']['id'])['messageText'] =
                data['data']['messageText'];
          });

          _scrollToBottom();
        } else if (data['data'].length == 1) {
          setState(() {
            _messages
                .removeWhere((message) => message['id'] == data['data']['id']);
          });
        }
      });
    } catch (e) {
      print(e);
    }
  }

  void _updateMessage(String messageId, String messageText) {
    setState(() {
      _messages.firstWhere(
          (message) => message['id'] == messageId)['messageText'] = messageText;
    });

    final message = {
      'id': messageId,
      'user_id': myId,
      'userEmail': myEmail,
      'conversation_id': widget.id,
      'message_text': _messageController.text.trim(),
    };

    _webSocketService.socket.emit('updateMessage', message);
  }

  void _deleteMessage(String messageId) {
    setState(() {
      _messages.removeWhere((message) => message['id'] == messageId);
    });

    final message = {
      'id': messageId,
      'conversationId': widget.id,
    };

    _webSocketService.socket.emit('deleteMessage', message);
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

    _messageController.clear();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
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
                final myMessage = message['userEmail'] == myEmail;
                final messageText = message['messageText'];

                return Align(
                  alignment:
                      myMessage ? Alignment.centerRight : Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: myMessage
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      if (!myMessage)
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
                          maxWidth: MediaQuery.of(context).size.width * 0.75,
                        ),
                        decoration: BoxDecoration(
                          color: myMessage
                              ? Colors.blueAccent
                              : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            GestureDetector(
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder: (BuildContext context) {
                                    return AlertDialog(
                                      title: Text(
                                        myMessage
                                            ? 'Your Message'
                                            : '${message['userEmail']}\'s Message',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      content: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            messageText ?? '',
                                            style: TextStyle(fontSize: 16),
                                          ),
                                          SizedBox(height: 8),
                                          Text(
                                            'Sent: ${_formatDateTime(message['createdAt'])}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey,
                                            ),
                                          ),
                                          if (message['isEdited'] == true)
                                            Text(
                                              'Edited: ${message['updatedAt'] ?? 'Unknown'}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey,
                                              ),
                                            ),
                                        ],
                                      ),
                                      actions: <Widget>[
                                        TextButton(
                                          onPressed: () {
                                            Navigator.pop(context);
                                          },
                                          child: const Text('Close'),
                                        ),
                                        if (myMessage) ...[
                                          TextButton(
                                            onPressed: () {
                                              Navigator.pop(context);
                                              _messageController.text =
                                                  messageText ?? '';
                                              showDialog(
                                                context: context,
                                                builder:
                                                    (BuildContext context) {
                                                  return AlertDialog(
                                                    title: const Text(
                                                        'Edit Message'),
                                                    content: TextField(
                                                      controller:
                                                          _messageController,
                                                      decoration:
                                                          const InputDecoration(
                                                        hintText:
                                                            'Edit your message',
                                                      ),
                                                    ),
                                                    actions: <Widget>[
                                                      TextButton(
                                                        onPressed: () {
                                                          Navigator.pop(
                                                              context);
                                                          _messageController
                                                              .clear();
                                                        },
                                                        child: const Text(
                                                            'Cancel'),
                                                      ),
                                                      TextButton(
                                                        onPressed: () {
                                                          _updateMessage(
                                                              message['id'],
                                                              _messageController
                                                                  .text
                                                                  .trim());
                                                          Navigator.pop(
                                                              context);
                                                          _messageController
                                                              .clear();
                                                        },
                                                        child: const Text(
                                                            'Update'),
                                                      ),
                                                    ],
                                                  );
                                                },
                                              );
                                            },
                                            child: const Text('Edit'),
                                          ),
                                          TextButton(
                                            onPressed: () {
                                              Navigator.pop(context);
                                              showDialog(
                                                context: context,
                                                builder:
                                                    (BuildContext context) {
                                                  return AlertDialog(
                                                    title: const Text(
                                                        'Delete Message'),
                                                    content: const Text(
                                                        'Are you sure you want to delete this message?'),
                                                    actions: <Widget>[
                                                      TextButton(
                                                        onPressed: () {
                                                          Navigator.pop(
                                                              context);
                                                        },
                                                        child: const Text(
                                                            'Cancel'),
                                                      ),
                                                      TextButton(
                                                        onPressed: () {
                                                          _deleteMessage(
                                                              message['id']);
                                                          Navigator.pop(
                                                              context);
                                                        },
                                                        child: const Text(
                                                            'Delete'),
                                                      ),
                                                    ],
                                                  );
                                                },
                                              );
                                            },
                                            child: const Text('Delete'),
                                          ),
                                        ],
                                      ],
                                    );
                                  },
                                );
                              },
                              onLongPress: myMessage
                                  ? () {
                                      showModalBottomSheet(
                                        context: context,
                                        builder: (BuildContext context) {
                                          return SafeArea(
                                            child: Wrap(
                                              children: <Widget>[
                                                ListTile(
                                                  leading:
                                                      const Icon(Icons.edit),
                                                  title: const Text(
                                                      'Edit Message'),
                                                  onTap: () {
                                                    Navigator.pop(context);
                                                    _messageController.text =
                                                        messageText ?? '';
                                                    showDialog(
                                                      context: context,
                                                      builder: (BuildContext
                                                          context) {
                                                        return AlertDialog(
                                                          title: const Text(
                                                              'Edit Message'),
                                                          content: TextField(
                                                            controller:
                                                                _messageController,
                                                            decoration:
                                                                const InputDecoration(
                                                              hintText:
                                                                  'Edit your message',
                                                            ),
                                                          ),
                                                          actions: <Widget>[
                                                            TextButton(
                                                              onPressed: () {
                                                                Navigator.pop(
                                                                    context);
                                                                _messageController
                                                                    .clear();
                                                              },
                                                              child: const Text(
                                                                  'Cancel'),
                                                            ),
                                                            TextButton(
                                                              onPressed:
                                                                  _isLoading
                                                                      ? null
                                                                      : () {
                                                                          _updateMessage(
                                                                              message['id'],
                                                                              _messageController.text.trim());
                                                                          Navigator.pop(
                                                                              context);
                                                                          _messageController
                                                                              .clear();
                                                                        },
                                                              child: _isLoading
                                                                  ? const SizedBox(
                                                                      width: 20,
                                                                      height:
                                                                          20,
                                                                      child:
                                                                          CircularProgressIndicator(
                                                                        strokeWidth:
                                                                            2,
                                                                      ),
                                                                    )
                                                                  : const Text(
                                                                      'Update'),
                                                            ),
                                                          ],
                                                        );
                                                      },
                                                    );
                                                  },
                                                ),
                                                ListTile(
                                                  leading:
                                                      const Icon(Icons.delete),
                                                  title: const Text(
                                                      'Delete Message'),
                                                  onTap: () {
                                                    Navigator.pop(context);
                                                    showDialog(
                                                      context: context,
                                                      builder: (BuildContext
                                                          context) {
                                                        return AlertDialog(
                                                          title: const Text(
                                                              'Delete Message'),
                                                          content: const Text(
                                                              'Are you sure you want to delete this message?'),
                                                          actions: <Widget>[
                                                            TextButton(
                                                              onPressed: () {
                                                                Navigator.pop(
                                                                    context);
                                                              },
                                                              child: const Text(
                                                                  'Cancel'),
                                                            ),
                                                            TextButton(
                                                              onPressed:
                                                                  _isLoading
                                                                      ? null
                                                                      : () {
                                                                          _deleteMessage(
                                                                              message['id']);
                                                                          Navigator.pop(
                                                                              context);
                                                                        },
                                                              child: _isLoading
                                                                  ? const SizedBox(
                                                                      width: 20,
                                                                      height:
                                                                          20,
                                                                      child:
                                                                          CircularProgressIndicator(
                                                                        strokeWidth:
                                                                            2,
                                                                      ),
                                                                    )
                                                                  : const Text(
                                                                      'Delete'),
                                                            ),
                                                          ],
                                                        );
                                                      },
                                                    );
                                                  },
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      );
                                    }
                                  : null,
                              child: Text(
                                messageText ?? '',
                                style: TextStyle(
                                  color:
                                      myMessage ? Colors.white : Colors.black87,
                                ),
                              ),
                            ),
                            if (message['isEdited'] == true)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  'edited',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: myMessage
                                        ? Colors.white70
                                        : Colors.black54,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                          ],
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
            child: Row(
              children: [
                Expanded(
                  child: MessageInput(
                    controller: _messageController,
                    onSend: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
