import 'package:vistora_mobile/core/api/api_client.dart';
import 'package:vistora_mobile/core/api/api_parsing.dart';
import 'package:vistora_mobile/features/support/domain/support_ticket_models.dart';

class SupportTicketRepository {
  const SupportTicketRepository(this._api);
  final ApiClient _api;

  String _path(bool superadmin) =>
      superadmin ? '/superadmin/support/tickets' : '/support/tickets';

  Future<SupportTicketPage> page({
    required bool superadmin,
    int page = 1,
    int perPage = 10,
    String? query,
    String? status,
    String? priority,
    String? corpId,
  }) async {
    final response = await _api.get(
      _path(superadmin),
      queryParameters: {
        'page': page,
        'perPage': perPage,
        'q': ?query,
        'status': ?status,
        'priority': ?priority,
        'corp_id': ?corpId,
      },
    );
    final paginator = asMap(asMap(response['data'])['items']);
    final raw = asList(paginator['data']);
    return SupportTicketPage(
      items: raw.map((item) => SupportTicket.fromJson(asMap(item))).toList(),
      page: asInt(paginator['current_page'], page),
      lastPage: asInt(paginator['last_page'], 1),
      total: asInt(paginator['total'], raw.length),
    );
  }

  Future<SupportTicket> show(int id, {required bool superadmin}) async {
    final response = await _api.get('${_path(superadmin)}/$id');
    return SupportTicket.fromJson(asMap(response['data'])['ticket']);
  }

  Future<SupportTicket> create({
    required String subject,
    required String description,
    required String category,
    required String priority,
  }) async {
    final response = await _api.post(
      '/support/tickets',
      data: {
        'subject': subject,
        'description': description,
        'category': category,
        'priority': priority,
      },
    );
    return SupportTicket.fromJson(asMap(response['data'])['ticket']);
  }

  Future<void> reply(
    int id, {
    required bool superadmin,
    required String body,
  }) => _api.post('${_path(superadmin)}/$id/messages', data: {'body': body});

  Future<void> resolve(int id) =>
      _api.post('/superadmin/support/tickets/$id/resolve', data: {});

  Future<void> close(int id) =>
      _api.post('/superadmin/support/tickets/$id/close', data: {});
}
