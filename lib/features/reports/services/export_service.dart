// Facade — delegates PDF work to PdfExportService and CSV work to CsvExportService.
import 'pdf_export_service.dart';
import 'csv_export_service.dart';

export 'pdf_export_service.dart' show PdfExportService;
export 'csv_export_service.dart' show CsvExportService;

class ExportService {
  final _pdf = PdfExportService();
  final _csv = CsvExportService();

  void setUserDetailsFromProfile(Map<String, dynamic> userData) =>
      _pdf.setUserDetailsFromProfile(userData);

  void setUserDetails({
    String? userName,
    String? businessName,
    String? location,
    String? gstNumber,
    String? address,
  }) =>
      _pdf.setUserDetails(
        userName: userName,
        businessName: businessName,
        location: location,
        gstNumber: gstNumber,
        address: address,
      );

  Future<String> exportToPdf({
    required String reportType,
    required String userMobile,
    required DateTime startDate,
    required DateTime endDate,
    required dynamic data,
    required String title,
    Map<String, dynamic>? userData,
  }) =>
      _pdf.exportToPdf(
        reportType: reportType,
        userMobile: userMobile,
        startDate: startDate,
        endDate: endDate,
        data: data,
        title: title,
        userData: userData,
      );

  Future<String> exportToExcel({
    required String reportType,
    required String userMobile,
    required DateTime startDate,
    required DateTime endDate,
    required dynamic data,
  }) =>
      _csv.exportToExcel(
        reportType: reportType,
        userMobile: userMobile,
        startDate: startDate,
        endDate: endDate,
        data: data,
      );

  String formatDate(DateTime date) => _pdf.formatDate(date);
}
