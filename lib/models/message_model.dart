class Message {
  final String userId;
  final String userEmail;
  final String conversationId;
  final String messageText;

  Message({
    required this.userId,
    required this.userEmail,
    required this.conversationId,
    required this.messageText,
  });

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'userEmail': userEmail,
      'conversationId': conversationId,
      'messageText': messageText,
    };
  }

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      userId: json['userId'],
      userEmail: json['userEmail'],
      conversationId: json['conversationId'],
      messageText: json['messageText'],
    );
  }
}
