import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// Message d'une conversation (`matches/{matchId}/messages/{messageId}`).
class MessageModel extends Equatable {
  final String id;
  final String senderId;
  final String text;
  final DateTime sentAt;
  final DateTime? readAt;

  const MessageModel({
    required this.id,
    required this.senderId,
    required this.text,
    required this.sentAt,
    this.readAt,
  });

  bool isMine(String myUid) => senderId == myUid;

  factory MessageModel.fromMap(String id, Map<String, dynamic> map) {
    return MessageModel(
      id: id,
      senderId: map['senderId'] as String? ?? '',
      text: map['text'] as String? ?? '',
      sentAt: (map['sentAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      readAt: (map['readAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'text': text,
      'sentAt': Timestamp.fromDate(sentAt),
      if (readAt != null) 'readAt': Timestamp.fromDate(readAt!),
    };
  }

  @override
  List<Object?> get props => [id, senderId, text, sentAt, readAt];
}
