import 'package:flutter/material.dart';
import 'package:flutter_chat_application/models/chat_model.dart';
import 'package:flutter_chat_application/screens/chat/chat_screen.dart';
import 'package:flutter_chat_application/services/auth_service.dart';
import 'package:flutter_chat_application/services/websocket_service.dart';
import 'package:flutter_chat_application/storage/secure_storage.dart';
import 'package:flutter_chat_application/widgets/auth_alert.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:rflutter_alert/rflutter_alert.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatListScreen> {
  final WebSocketService _webSocketService = WebSocketService();
  final AuthService _authService = AuthService();

  List<Map<String, dynamic>> _chatList = [];
  List<Map<String, dynamic>> _users = [];
  List<String> _ids = [];
  bool _dropdownSelect = false;
  String? _token;
  Map<String, dynamic>? _decodedToken;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    _token = await SecureStorage().retrieveToken();
    if (_token == null || _token!.isEmpty) {
      return;
    }
    _decodedToken = JwtDecoder.decode(_token!);
    await _getConversations();
    await _getUsers();
  }

  Future<void> _getUsers() async {
    if (_token == null || _token!.isEmpty) return;

    final response = await AuthService().getUsers();
    if (mounted) {
      setState(() {
        _users =
            response.map((user) => Map<String, dynamic>.from(user)).toList();
      });
    }
  }

  Future<void> _getConversations() async {
    if (_token == null || _token!.isEmpty) return;

    final response = await AuthService().getConversations();
    if (mounted) {
      setState(() {
        _chatList =
            response.map((chat) => Map<String, dynamic>.from(chat)).toList();
      });
    }
  }

  void _selectUser(String userId) {
    setState(() {
      if (_ids.contains(userId)) {
        _ids.remove(userId);
      } else {
        _ids.add(userId);
      }
    });
  }

  Future<void> _createChat() async {
    if (_token == null || _token!.isEmpty || _decodedToken == null) {
      return;
    }

    try {
      await _webSocketService.initSocket();

      final data = ChatModel(
        userIds: [
          ...{
            ...{_decodedToken!['sub']},
            ..._ids
          }
        ].join(','),
        userEmail: _decodedToken!['email'],
        conversationName: _users
            .where((user) => [
                  ...{
                    ...{_decodedToken!['sub']},
                    ..._ids
                  }
                ].contains(user['id']))
            .map((user) => user['email'])
            .join(','),
        message: 'I am created a new chat',
        isGroup: _ids.length > 1,
      );

      _webSocketService.socket.emit('newChat', data);

      void onMessageHandler(dynamic data) {
        if (!mounted) return;

        if (data['status'] != 'success') {
          const AuthAlert(
            title: 'Failed',
            description: 'Failed to initiate chat',
            type: AlertType.error,
          ).show(context);
          return;
        }

        setState(() {
          _ids.clear();
          _dropdownSelect = false;
        });
        _getConversations();

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(id: data['data']),
          ),
        );
      }

      _webSocketService.socket.on('onMessage', onMessageHandler);
    } catch (e) {
      if (mounted) {
        const AuthAlert(
          title: 'Error',
          description: 'Failed to create chat',
          type: AlertType.error,
        ).show(context);
      }
      print('Error creating chat: $e');
    }
  }

  @override
  void dispose() {
    _webSocketService.socket.off('onMessage');
    _webSocketService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat List'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.person_add),
            onSelected: _selectUser,
            itemBuilder: (BuildContext context) {
              if (_decodedToken == null) return [];

              return _users
                  .where((user) => user['id'] != _decodedToken!['sub'])
                  .map((user) {
                final String userId = user['id'].toString();
                final String userEmail = user['email'] ?? 'Not available';
                return PopupMenuItem<String>(
                  value: userId,
                  child: Row(
                    children: [
                      Checkbox(
                        value: _ids.contains(userId),
                        onChanged: (bool? value) {
                          _selectUser(userId);
                        },
                      ),
                      Expanded(
                        child: Text(
                          userEmail,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList();
            },
          ),
          if (_ids.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline),
              onPressed: _createChat,
            ),
          if (_ids.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                _ids.length == 1 ? 'Single Chat' : 'Group Chat',
                style: const TextStyle(fontSize: 12),
              ),
            ),
        ],
      ),
      body: _chatList.isEmpty
          ? const Center(child: Text("You have no chats"))
          : ListView.builder(
              itemCount: _chatList.length,
              itemBuilder: (context, index) {
                final chat = _chatList[index];
                final String conversationId = chat['conversationId'];

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
