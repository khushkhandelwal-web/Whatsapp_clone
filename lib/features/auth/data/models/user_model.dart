class UserModel {
  final String  uid, name, email;
  final String? photoUrl;

  const UserModel({
    required this.uid,
    required this.name,
    required this.email,
    this.photoUrl,
  });

  factory UserModel.fromMap(Map<String, dynamic> d) => UserModel(
    uid:      d['uid']      as String? ?? '',
    name:     d['name']     as String? ?? '',
    email:    d['email']    as String? ?? '',
    photoUrl: d['photoUrl'] as String?,
  );

  Map<String, dynamic> toMap() => {
    'uid':   uid,
    'name':  name,
    'email': email,
    if (photoUrl != null) 'photoUrl': photoUrl,
  };
}