import 'package:vistora_mobile/core/api/api_parsing.dart';

class SupportTicketPage {
  const SupportTicketPage({
    required this.items,
    required this.page,
    required this.lastPage,
    required this.total,
  });

  final List<SupportTicket> items;
  final int page;
  final int lastPage;
  final int total;
}

class SupportTicket {
  const SupportTicket({
    required this.id,
    required this.ticketNo,
    required this.corpId,
    required this.subject,
    required this.description,
    required this.category,
    required this.priority,
    required this.status,
    required this.updatedAt,
    required this.messagesCount,
    this.raisedByName,
    this.raisedByEmail,
    this.messages = const [],
  });

  final int id;
  final String ticketNo;
  final String corpId;
  final String subject;
  final String description;
  final String category;
  final String priority;
  final String status;
  final DateTime? updatedAt;
  final int messagesCount;
  final String? raisedByName;
  final String? raisedByEmail;
  final List<SupportTicketMessage> messages;

  factory SupportTicket.fromJson(Map<String, dynamic> json) {
    final raiser = asMap(json['raiser']);
    return SupportTicket(
      id: asInt(json['id']),
      ticketNo: json['ticket_no']?.toString() ?? 'Ticket',
      corpId: json['corp_id']?.toString() ?? '',
      subject: json['subject']?.toString() ?? 'Support request',
      description: json['description']?.toString() ?? '',
      category: json['category']?.toString() ?? 'general',
      priority: json['priority']?.toString() ?? 'medium',
      status: json['status']?.toString() ?? 'open',
      updatedAt: asDateTime(json['updated_at']),
      messagesCount: asInt(json['messages_count']),
      raisedByName: asNullableString(raiser['name']),
      raisedByEmail: asNullableString(raiser['email']),
      messages: asList(
        json['messages'],
      ).map((item) => SupportTicketMessage.fromJson(asMap(item))).toList(),
    );
  }
}

class SupportTicketMessage {
  const SupportTicketMessage({
    required this.id,
    required this.body,
    required this.userId,
    required this.userName,
    required this.createdAt,
  });

  final int id;
  final String body;
  final int userId;
  final String userName;
  final DateTime? createdAt;

  factory SupportTicketMessage.fromJson(Map<String, dynamic> json) {
    final user = asMap(json['user']);
    return SupportTicketMessage(
      id: asInt(json['id']),
      body: json['body']?.toString() ?? '',
      userId: asInt(json['user_id']),
      userName: user['name']?.toString() ?? 'Support',
      createdAt: asDateTime(json['created_at']),
    );
  }
}
