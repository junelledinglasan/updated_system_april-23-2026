// lib/services/reports_service.dart
// Matches reports.js API calls (1:1 na parehong endpoints)
// FIX: lahat ng year-based methods ay tumatanggap na ng String
// (hindi na int) — para pwedeng "All" o kahit anong year na i-type,
// hindi lang yung mga naka-hardcode noon sa dropdown.

import 'api_client.dart';

class ReportsService {
  static Future<Map<String, dynamic>> getOverview(String year) async =>
      await ApiClient.get('/reports/overview/', params: {'year': year});

  static Future<List<dynamic>> getMonthlyCollection(String year) async =>
      await ApiClient.get('/reports/monthly-collection/', params: {'year': year});

  static Future<Map<String, dynamic>> getLoanStatus(String yearOrAll) async =>
      await ApiClient.get('/reports/loan-status/', params: {'year': yearOrAll});

  static Future<Map<String, dynamic>> getLoanType(String yearOrAll) async =>
      await ApiClient.get('/reports/loan-type/', params: {'year': yearOrAll});

  static Future<Map<String, dynamic>> getPaymentBehavior(String year) async =>
      await ApiClient.get('/reports/payment-behavior/', params: {'year': year});

  static Future<List<dynamic>> getAuditLog(String year) async =>
      await ApiClient.get('/reports/audit-log/', params: {'year': year});

  static Future<List<dynamic>> getClassification(String year) async =>
      await ApiClient.get('/reports/classification/', params: {'year': year});

  static Future<List<dynamic>> getMemberPerformance(String year) async =>
      await ApiClient.get('/reports/member-performance/', params: {'year': year, 'limit': '20'});

  static Future<Map<String, dynamic>> getTopBorrowers(String year) async =>
      await ApiClient.get('/reports/top-borrowers/', params: {'year': year});

  static Future<List<dynamic>> getLoanDistribution(String year) async =>
      await ApiClient.get('/reports/loan-distribution/', params: {'year': year});

  static Future<List<dynamic>> getYearlyComparison() async =>
      await ApiClient.get('/reports/yearly-comparison/');

  static Future<List<dynamic>> getShareCapitalGrowth(String year) async =>
      await ApiClient.get('/reports/share-capital-growth/', params: {'year': year});

  static Future<List<dynamic>> getOverdueAnalysis(String year) async =>
      await ApiClient.get('/reports/overdue-analysis/', params: {'year': year});

  static Future<List<dynamic>> getMonthlyLoans(String year) async =>
      await ApiClient.get('/reports/monthly-loans/', params: {'year': year});

  static Future<List<dynamic>> getRepaymentProgress(String year) async =>
      await ApiClient.get('/reports/repayment-progress/', params: {'year': year});

  static Future<Map<String, dynamic>> getDelinquency({int months = 1}) async =>
      await ApiClient.get('/reports/delinquency/', params: {'months': '$months'});

  static Future<Map<String, dynamic>> getCollectionEfficiency(String year) async =>
      await ApiClient.get('/reports/collection-efficiency/', params: {'year': year});

  static Future<Map<String, dynamic>> getMemberGrowth(String year) async =>
      await ApiClient.get('/reports/member-growth/', params: {'year': year});

  static Future<Map<String, dynamic>> getLoanApprovalRate(String year) async =>
      await ApiClient.get('/reports/approval-rate/', params: {'year': year});

  static Future<Map<String, dynamic>> getUpcomingMaturities({int months = 3}) async =>
      await ApiClient.get('/reports/upcoming-maturities/', params: {'months': '$months'});

  static Future<Map<String, dynamic>> getFirstTimeBorrowers(String year) async =>
      await ApiClient.get('/reports/first-time-borrowers/', params: {'year': year});

  static Future<Map<String, dynamic>> getRiskAssessment() async =>
      await ApiClient.get('/reports/risk-assessment/');

  static Future<Map<String, dynamic>> previewReport(String type, String from, String to) async =>
      await ApiClient.get('/reports/preview/', params: {'type': type, 'from': from, 'to': to});

  static String exportExcelUrl(String baseUrl, String type, String from, String to) =>
      '$baseUrl/reports/export/excel/?type=${Uri.encodeComponent(type)}&from=$from&to=$to';

  static String exportPdfUrl(String baseUrl, String type, String from, String to) =>
      '$baseUrl/reports/export/pdf/?type=${Uri.encodeComponent(type)}&from=$from&to=$to';
}