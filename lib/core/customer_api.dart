import 'api_client.dart';

class CustomerApi {
  CustomerApi(this.api);

  final ApiClient api;

  Future<Map<String, dynamic>> home() async {
    final response = await api.get('/customer/home');
    return Map<String, dynamic>.from(response.data);
  }

  Future<List<dynamic>> orders() async {
    final response = await api.get('/customer/orders');
    return List<dynamic>.from(response.data['data'] ?? []);
  }

  Future<Map<String, dynamic>> order(int id) async {
    final response = await api.get('/customer/orders/$id');
    return Map<String, dynamic>.from(response.data['data'] ?? {});
  }

  Future<List<dynamic>> payments() async {
    final response = await api.get('/customer/payments');
    return List<dynamic>.from(response.data['data'] ?? []);
  }

  Future<List<dynamic>> notifications() async {
    final response = await api.get('/customer/notifications');
    return List<dynamic>.from(response.data['data'] ?? []);
  }

  Future<int> unreadNotifications() async {
    final response = await api.get('/customer/notifications/unread-count');
    return int.tryParse('${response.data['count'] ?? 0}') ?? 0;
  }

  Future<void> readNotification(int id) async {
    await api.post('/customer/notifications/$id/read');
  }

  Future<void> readAllNotifications() async {
    await api.post('/customer/notifications/read-all');
  }

  Future<Map<String, dynamic>> profile() async {
    final response = await api.get('/customer/profile');
    return Map<String, dynamic>.from(response.data['data'] ?? {});
  }

  Future<Map<String, dynamic>> updateProfile({
    required String name,
    required String phone,
    required String address,
  }) async {
    final response = await api.post(
      '/customer/profile',
      data: {
        'name': name,
        'phone': phone,
        'address': address,
      },
    );

    return Map<String, dynamic>.from(response.data['data'] ?? {});
  }

  Future<Map<String, dynamic>> chat() async {
    final response = await api.get('/customer/chat');
    return Map<String, dynamic>.from(response.data);
  }

  Future<Map<String, dynamic>> sendChat(String message) async {
    final response = await api.post(
      '/customer/chat/messages',
      data: {'message': message},
    );

    return Map<String, dynamic>.from(response.data);
  }

  Future<List<dynamic>> history() async {
    final response = await api.get('/customer/history');
    return List<dynamic>.from(response.data['data'] ?? []);
  }
}
