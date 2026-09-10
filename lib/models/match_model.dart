import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// Représente un match entre deux utilisateurs (`matches/{matchId}`).
/// Convention : `matchId` = les deux uids triés et joints par un underscore,
/// ce qui évite les doublons et permet de retrouver le doc sans requête.
class MatchModel extends Equatable {
  final String id;
  final List<String> userIds;
  final DateTime createdAt;
  final String? lastMessage;
  final DateTime? lastMessageAt;

  const MatchModel({
    required this.id,
    required this.userIds,
    required this.createdAt,
    this.lastMessage,
    this.lastMessageAt,
  });

  static String buildId(String uidA, String uidB) {
    final sorted = [uidA, uidB]..sort();
    return sorted.join('_');
  }

  String otherUserId(String myUid) =>
      userIds.firstWhere((id) => id != myUid, orElse: () => myUid);

  factory MatchModel.fromMap(String id, Map<String, dynamic> map) {
    return MatchModel(
      id: id,
      userIds: List<String>.from(map['users'] as List? ?? []),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastMessage: map['lastMessage'] as String?,
      lastMessageAt: (map['lastMessageAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'users': userIds,
      'createdAt': Timestamp.fromDate(createdAt),
      if (lastMessage != null) 'lastMessage': lastMessage,
      // Toujours écrit, même sans message : la requête `watchMatchesForUser`
      // trie sur ce champ, or Firestore exclut les documents où le champ de
      // tri est absent. Un match sans conversation resterait donc invisible.
      'lastMessageAt': Timestamp.fromDate(lastMessageAt ?? createdAt),
    };
  }

  @override
  List<Object?> get props =>
      [id, userIds, createdAt, lastMessage, lastMessageAt];
}
