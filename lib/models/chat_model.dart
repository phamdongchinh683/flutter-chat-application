class ChatModel {
  final String userIds;
  final String userEmail;
  final String conversationName;
  final String message;
  final bool isGroup;

  ChatModel(
      {required this.userIds,
      required this.userEmail,
      required this.conversationName,
      required this.message,
      required this.isGroup});

  Map<String, dynamic> toJson() {
    return {
      'userIds': userIds,
      'userEmail': userEmail,
      'conversationName': conversationName,
      'message': message,
      'isGroup': isGroup,
    };
  }
}
