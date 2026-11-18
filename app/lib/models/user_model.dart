import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class UserModel extends Equatable {
  final String uid;
  final String name;
  final String username;
  final String email;
  final String degreeProgram;
  final String language;
  final List<String> pushTokens;
  final List<String> friendUids;
  final Map<String, DateTime> badges;
  final bool onboardingComplete;
  final int disputeCount;
  final DateTime? disputePenaltyUntil;
  final DateTime createdAt;

  const UserModel({
    required this.uid,
    required this.name,
    required this.username,
    required this.email,
    required this.degreeProgram,
    required this.language,
    required this.pushTokens,
    required this.friendUids,
    required this.badges,
    required this.onboardingComplete,
    this.disputeCount = 0,
    this.disputePenaltyUntil,
    required this.createdAt,
  });

  UserModel copyWith({
    String? uid,
    String? name,
    String? username,
    String? email,
    String? degreeProgram,
    String? language,
    List<String>? pushTokens,
    List<String>? friendUids,
    Map<String, DateTime>? badges,
    bool? onboardingComplete,
    int? disputeCount,
    DateTime? disputePenaltyUntil,
    DateTime? createdAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      username: username ?? this.username,
      email: email ?? this.email,
      degreeProgram: degreeProgram ?? this.degreeProgram,
      language: language ?? this.language,
      pushTokens: pushTokens ?? this.pushTokens,
      friendUids: friendUids ?? this.friendUids,
      badges: badges ?? this.badges,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      disputeCount: disputeCount ?? this.disputeCount,
      disputePenaltyUntil: disputePenaltyUntil ?? this.disputePenaltyUntil,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'username': username,
      'email': email,
      'degreeProgram': degreeProgram,
      'language': language,
      'pushTokens': pushTokens,
      'friendUids': friendUids,
      'badges': badges.map(
        (key, value) => MapEntry(key, Timestamp.fromDate(value)),
      ),
      'onboardingComplete': onboardingComplete,
      'disputeCount': disputeCount,
      'disputePenaltyUntil': disputePenaltyUntil != null
          ? Timestamp.fromDate(disputePenaltyUntil!)
          : null,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map, String documentId) {
    final badgesMap = map['badges'] as Map? ?? const {};
    // A badge value may momentarily be null in an optimistic (latency-
    // compensated) snapshot if it was written with serverTimestamp() and hasn't
    // resolved yet — tolerate it instead of throwing the non-nullable cast.
    final badges = <String, DateTime>{
      for (final entry in badgesMap.entries)
        if (entry.value is Timestamp)
          entry.key as String: (entry.value as Timestamp).toDate(),
    };

    return UserModel(
      uid: documentId,
      name: map['name'] as String? ?? '',
      username: map['username'] as String? ?? '',
      email: map['email'] as String? ?? '',
      degreeProgram: map['degreeProgram'] as String? ?? '',
      language: map['language'] as String? ?? 'en',
      pushTokens: List<String>.from(map['pushTokens'] as Iterable? ?? const []),
      friendUids: List<String>.from(map['friendUids'] as Iterable? ?? const []),
      badges: badges,
      onboardingComplete: map['onboardingComplete'] as bool? ?? false,
      disputeCount: map['disputeCount'] as int? ?? 0,
      disputePenaltyUntil: (map['disputePenaltyUntil'] as Timestamp?)?.toDate(),
      createdAt: (map['createdAt'] as Timestamp? ?? Timestamp.now()).toDate(),
    );
  }

  @override
  List<Object?> get props => [
    uid,
    name,
    username,
    email,
    degreeProgram,
    language,
    pushTokens,
    friendUids,
    badges,
    onboardingComplete,
    disputeCount,
    disputePenaltyUntil,
    createdAt,
  ];
}
