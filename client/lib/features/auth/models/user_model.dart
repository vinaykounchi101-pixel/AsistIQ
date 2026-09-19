enum UserRole {
  requester,
  operator,
  lead,
  manager,
  admin;

  static UserRole fromString(String role) {
    final cleanRole = role.toLowerCase().replaceAll('_', '').replaceAll(' ', '');
    if (cleanRole.contains('admin')) return UserRole.admin;
    if (cleanRole.contains('lead')) return UserRole.lead;
    if (cleanRole.contains('manager')) return UserRole.manager;
    if (cleanRole.contains('operator')) return UserRole.operator;
    return UserRole.requester;
  }

  String toDisplayString() {
    switch (this) {
      case UserRole.requester:
        return 'Requester';
      case UserRole.operator:
        return 'Operator';
      case UserRole.lead:
        return 'Team Lead';
      case UserRole.manager:
        return 'Helpdesk Manager';
      case UserRole.admin:
        return 'System Admin';
    }
  }

  bool get isStaff => this != UserRole.requester;
  bool get isManagement => this == UserRole.manager || this == UserRole.admin;
  bool get isAdmin => this == UserRole.admin;
}

class UserModel {
  final String id;
  final String email;
  final String fullName;
  final UserRole role;
  final String? department;
  final bool isActive;
  final String? avatarUrl;

  const UserModel({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    this.department,
    this.isActive = true,
    this.avatarUrl,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id']?.toString() ?? '',
      email: json['email'] as String? ?? '',
      fullName: json['full_name'] as String? ?? json['name'] as String? ?? '',
      role: UserRole.fromString(json['role'] as String? ?? 'requester'),
      department: json['department'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      avatarUrl: json['avatar_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'role': role.name,
      'department': department,
      'is_active': isActive,
      'avatar_url': avatarUrl,
    };
  }

  UserModel copyWith({
    String? id,
    String? email,
    String? fullName,
    UserRole? role,
    String? department,
    bool? isActive,
    String? avatarUrl,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      department: department ?? this.department,
      isActive: isActive ?? this.isActive,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }
}
