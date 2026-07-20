// lib/services/payments_service.dart
// Matches payments.js API calls

import 'api_client.dart';

class PaymentsService {
  static Future<List<dynamic>> getPayments() async =>
      await ApiClient.get('/payments/');

  static Future<Map<String, dynamic>> getPaymentStats() async =>
      await ApiClient.get('/payments/stats/');

  static Future<Map<String, dynamic>> recordPayment(Map<String, dynamic> data) async =>
      await ApiClient.post('/payments/', body: data);

  static Future<Map<String, dynamic>> getPayment(int id) async =>
      await ApiClient.get('/payments/$id/');
}