class User {
  final String email;
  final String password;
  final String phoneNumber;
  final String role;

  User({
    required this.email,
    required this.password,
    required this.phoneNumber,
    required this.role,
  });

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'password': password,
      'phoneNumber': phoneNumber,
      'role': role,
    };
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      email: json['email'],
      password: json['password'],
      phoneNumber: json['phoneNumber'],
      role: json['role'],
    );
  }
}
