class UserEntity {
  final String id;
  final String? email;
  final String? username;
  final bool isGuest;

  UserEntity({
    required this.id,
    this.email,
    this.username,
    required this.isGuest,
  });
}
