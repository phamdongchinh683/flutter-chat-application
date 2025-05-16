import 'package:flutter_chat_application/storage/secure_storage.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class WebSocketService {
  late IO.Socket socket;

  Future<void> initSocket() async {
    final String? token = await SecureStorage().retrieveToken();

    if (token == null) {
      return;
    }

    socket = IO.io(
        'http://localhost:3000',
        IO.OptionBuilder().setTransports(['websocket']).setAuth({
          'authorization': 'Bearer $token',
        }).build());

    socket.onConnect((_) {
      print('Connected to the WebSocket server');
    });

    socket.onDisconnect((_) {
      print('Disconnected from the WebSocket server');
    });

    socket.connect();
  }

  void dispose() {
    socket.dispose();
  }
}
