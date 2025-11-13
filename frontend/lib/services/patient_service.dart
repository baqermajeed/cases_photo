import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import '../core/constants/api_constants.dart';
import '../models/patient.dart';
import 'auth_service.dart';

class PatientService {
  final AuthService authService = AuthService();
  static const Duration _timeout = Duration(seconds: 12);

  // Get all patients with search and pagination
  Future<Map<String, dynamic>> getPatients({
    String? query,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final token = await authService.getToken();
      if (token == null) {
        return {'success': false, 'message': 'غير مسجل الدخول'};
      }

      String url = '${ApiConstants.baseUrl}${ApiConstants.patients}?page=$page&limit=$limit';
      if (query != null && query.isNotEmpty) {
        url += '&q=$query';
      }

      final response = await http
          .get(
            Uri.parse(url),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final patients = (data['data'] as List)
            .map((e) => Patient.fromJson(e))
            .toList();

        return {
          'success': true,
          'patients': patients,
          'pagination': data['pagination'],
        };
      } else {
        String msg = 'فشل في جلب البيانات';
        try {
          final err = jsonDecode(utf8.decode(response.bodyBytes));
          msg = err['detail']?.toString() ?? err['message']?.toString() ?? msg;
        } catch (_) {}
        if (response.statusCode == 401) {
          msg = 'انتهت جلسة الدخول. يرجى تسجيل الدخول مجدداً.';
        }
        return {'success': false, 'message': msg, 'status': response.statusCode};
      }
    } on TimeoutException {
      return {'success': false, 'message': 'انتهت مهلة الاتصال. تحقق من الشبكة.'};
    } catch (e) {
      return {'success': false, 'message': 'خطأ في الاتصال: $e'};
    }
  }

  // Get patient by ID
  Future<Patient?> getPatient(String id) async {
    try {
      final token = await authService.getToken();
      if (token == null) return null;

      final response = await http
          .get(
            Uri.parse('${ApiConstants.baseUrl}${ApiConstants.patientById(id)}'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return Patient.fromJson(data['data']);
      }
      return null;
    } on TimeoutException {
      return null;
    } catch (e) {
      return null;
    }
  }

  // Create new patient
  Future<Map<String, dynamic>> createPatient({
    required String name,
    required String phone,
    required String address,
  }) async {
    try {
      final token = await authService.getToken();
      if (token == null) {
        return {'success': false, 'message': 'غير مسجل الدخول'};
      }

      final response = await http
          .post(
            Uri.parse('${ApiConstants.baseUrl}${ApiConstants.patients}'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'name': name,
              'phone': phone,
              'address': address,
            }),
          )
          .timeout(_timeout);

      if (response.statusCode == 201) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return {
          'success': true,
          'patient': Patient.fromJson(data['data']),
        };
      } else {
        return {'success': false, 'message': 'فشل في إضافة المريض'};
      }
    } on TimeoutException {
      return {'success': false, 'message': 'انتهت مهلة الاتصال. تحقق من الشبكة.'};
    } catch (e) {
      return {'success': false, 'message': 'خطأ في الاتصال: $e'};
    }
  }

  // Upload images to a step
  Future<Map<String, dynamic>> uploadImages({
    required String patientId,
    required int stepNumber,
    required List<XFile> images,
  }) async {
    try {
      final token = await authService.getToken();
      if (token == null) {
        return {'success': false, 'message': 'غير مسجل الدخول'};
      }

      var request = http.MultipartRequest(
        'POST',
        Uri.parse(
            '${ApiConstants.baseUrl}${ApiConstants.uploadImages(patientId, stepNumber)}'),
      );

      request.headers['Authorization'] = 'Bearer $token';

      // Add all images with proper content-type
      String _extToMime(String path) {
        final lower = path.toLowerCase();
        if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
        if (lower.endsWith('.png')) return 'image/png';
        if (lower.endsWith('.webp')) return 'image/webp';
        if (lower.endsWith('.heic')) return 'image/heic';
        if (lower.endsWith('.heif')) return 'image/heif';
        return 'image/jpeg';
      }

      for (var image in images) {
        final mime = _extToMime(image.path);
        final mediaType = MediaType.parse(mime);
        request.files.add(
          await http.MultipartFile.fromPath('files', image.path, contentType: mediaType),
        );
      }

      final streamedResponse = await request.send().timeout(_timeout);
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        Map<String, dynamic>? payload;
        try {
          payload = jsonDecode(utf8.decode(response.bodyBytes));
        } catch (_) {}
        return {
          'success': true,
          'message': payload?['message'] ?? 'تم رفع الصور بنجاح',
          'data': payload?['data'], // قد تحتوي بيانات الخطوة
        };
      } else {
        String msg = 'فشل في رفع الصور';
        try {
          final err = jsonDecode(utf8.decode(response.bodyBytes));
          msg = err['detail']?.toString() ?? err['message']?.toString() ?? msg;
        } catch (_) {}
        return {'success': false, 'message': msg, 'status': response.statusCode};
      }
    } on TimeoutException {
      return {'success': false, 'message': 'انتهت مهلة الاتصال أثناء رفع الصور.'};
    } catch (e) {
      return {'success': false, 'message': 'خطأ في رفع الصور: $e'};
    }
  }

  // Mark step as done
  Future<Map<String, dynamic>> markStepDone({
    required String patientId,
    required int stepNumber,
    required bool isDone,
  }) async {
    try {
      final token = await authService.getToken();
      if (token == null) {
        return {'success': false, 'message': 'غير مسجل الدخول'};
      }

      final response = await http
          .patch(
            Uri.parse(
                '${ApiConstants.baseUrl}${ApiConstants.markStepDone(patientId, stepNumber)}'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'is_done': isDone}),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        return {'success': true};
      } else {
        return {'success': false, 'message': 'فشل في تحديث الحالة'};
      }
    } on TimeoutException {
      return {'success': false, 'message': 'انتهت مهلة الاتصال. تحقق من الشبكة.'};
    } catch (e) {
      return {'success': false, 'message': 'خطأ في الاتصال: $e'};
    }
  }

  // Delete image
  Future<Map<String, dynamic>> deleteImage({
    required String patientId,
    required int stepNumber,
    required String imageId,
  }) async {
    try {
      final token = await authService.getToken();
      if (token == null) {
        return {'success': false, 'message': 'غير مسجل الدخول'};
      }

      final response = await http
          .delete(
            Uri.parse(
                '${ApiConstants.baseUrl}${ApiConstants.deleteImage(patientId, stepNumber, imageId)}'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        return {'success': true, 'message': 'تم حذف الصورة'};
      } else {
        return {'success': false, 'message': 'فشل في حذف الصورة'};
      }
    } on TimeoutException {
      return {'success': false, 'message': 'انتهت مهلة الاتصال. تحقق من الشبكة.'};
    } catch (e) {
      return {'success': false, 'message': 'خطأ في الاتصال: $e'};
    }
  }

  // Get statistics (admin only)
  Future<Map<String, dynamic>> getStatistics() async {
    try {
      final token = await authService.getToken();
      if (token == null) {
        return {'success': false, 'message': 'غير مسجل الدخول'};
      }

      final response = await http
          .get(
            Uri.parse('${ApiConstants.baseUrl}/patients/stats/dashboard'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return {
          'success': true,
          'data': data['data'],
        };
      } else {
        return {'success': false, 'message': 'فشل في جلب الإحصائيات'};
      }
    } on TimeoutException {
      return {'success': false, 'message': 'انتهت مهلة الاتصال. تحقق من الشبكة.'};
    } catch (e) {
      return {'success': false, 'message': 'خطأ في الاتصال: $e'};
    }
  }

  // Get completed patients (admin only)
  Future<Map<String, dynamic>> getCompletedPatients() async {
    try {
      final token = await authService.getToken();
      if (token == null) {
        return {'success': false, 'message': 'غير مسجل الدخول'};
      }

      final response = await http
          .get(
            Uri.parse('${ApiConstants.baseUrl}/patients/filter/completed'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final patients = (data['data'] as List)
            .map((e) => Patient.fromJson(e))
            .toList();
        return {
          'success': true,
          'patients': patients,
        };
      } else {
        return {'success': false, 'message': 'فشل في جلب البيانات'};
      }
    } on TimeoutException {
      return {'success': false, 'message': 'انتهت مهلة الاتصال. تحقق من الشبكة.'};
    } catch (e) {
      return {'success': false, 'message': 'خطأ في الاتصال: $e'};
    }
  }

  // Delete patient (admin only)
  Future<Map<String, dynamic>> deletePatient(String patientId) async {
    try {
      final token = await authService.getToken();
      if (token == null) {
        return {'success': false, 'message': 'غير مسجل الدخول'};
      }

      final response = await http
          .delete(
            Uri.parse('${ApiConstants.baseUrl}${ApiConstants.patientById(patientId)}'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        return {'success': true, 'message': 'تم حذف المريض بنجاح'};
      } else {
        return {'success': false, 'message': 'فشل في حذف المريض'};
      }
    } on TimeoutException {
      return {'success': false, 'message': 'انتهت مهلة الاتصال. تحقق من الشبكة.'};
    } catch (e) {
      return {'success': false, 'message': 'خطأ في الاتصال: $e'};
    }
  }
}
