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
  String? _myEmail;
  String? _myId;
  bool _isLoading = false;
  bool _isConnected = false;

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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Authentication error. Please login again.')),
        );
      }
      return;
    }

    try {
      Map<String, dynamic> decodedToken = JwtDecoder.decode(token);
      _myEmail = decodedToken['email'];
      _myId = decodedToken['sub'];

      await _webSocketService.initSocket();
      _isConnected = true;

      _webSocketService.socket.emit('joinConversation', {
        'conversationId': widget.id,
      });

      _setupSocketListeners();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connection error: ${e.toString()}')),
        );
      }
      print('Socket initialization error: $e');
    }
  }

  void _setupSocketListeners() {
    _webSocketService.socket.off('onMessageHistory');
    _webSocketService.socket.on('onMessageHistory', (data) {
      if (!mounted) return;

      if (data['status'] != 'success') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load message history')),
        );
        return;
      }

      setState(() {
        _messages = List<Map<String, dynamic>>.from(data['data']);
      });
      _scrollToBottom();
    });

    _webSocketService.socket.off('onMessage');
    _webSocketService.socket.on('onMessage', (data) {
      if (!mounted) return;

      if (data['status'] != 'success') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to receive message')),
        );
        return;
      }

      setState(() {
        if (data['data'].length > 2) {
          _messages.add(data['data']);
        } else if (data['data'].length == 2) {
          final messageIndex = _messages
              .indexWhere((message) => message['id'] == data['data']['id']);
          if (messageIndex != -1) {
            _messages[messageIndex]['messageText'] =
                data['data']['messageText'];
          }
        } else if (data['data'].length == 1) {
          _messages
              .removeWhere((message) => message['id'] == data['data']['id']);
        }
      });
      _scrollToBottom();
    });
  }

  void _updateMessage(String messageId, String messageText) {
    if (!_isConnected || _myId == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final messageIndex =
          _messages.indexWhere((message) => message['id'] == messageId);

      if (messageIndex != -1) {
        setState(() {
          _messages[messageIndex]['messageText'] = messageText;
        });
      }

      final message = {
        'id': messageId,
        'user_id': _myId,
        'userEmail': _myEmail,
        'conversation_id': widget.id,
        'message_text': messageText,
      };

      _webSocketService.socket.emit('updateMessage', message);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update message: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _deleteMessage(String messageId) {
    if (!_isConnected) return;

    setState(() {
      _isLoading = true;
    });

    try {
      setState(() {
        _messages.removeWhere((message) => message['id'] == messageId);
      });

      final message = {
        'id': messageId,
        'conversationId': widget.id,
      };

      _webSocketService.socket.emit('deleteMessage', message);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete message: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _sendMessage() {
    if (!_isConnected || _myId == null || _myEmail == null) return;
    if (_messageController.text.trim().isEmpty) return;

    try {
      final newMessage = {
        'userId': _myId,
        'userEmail': _myEmail,
        'conversationId': widget.id,
        'messageText': _messageController.text.trim(),
      };

      _webSocketService.socket.emit('newMessage', newMessage);
      _messageController.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message: ${e.toString()}')),
        );
      }
    }
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
  void dispose() {
    _webSocketService.socket.off('onMessageHistory');
    _webSocketService.socket.off('onMessage');
    _webSocketService.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Chat"),
      ),
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
                final myMessage = message['userEmail'] == _myEmail;
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
                                            : '${message['userEmail']}',
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
