import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import '../core/constants/api_constants.dart';
import '../models/patient.dart';
import 'auth_service.dart';
import 'dio_client.dart';
import 'network_checker.dart';

class PatientService {
  final AuthService authService = AuthService();

  // -------------------------
  // Get Patients
  // -------------------------
  Future<Map<String, dynamic>> getPatients({
    String? query,
    int page = 1,
    int limit = 1000,
  }) async {
    if (!await NetworkChecker.hasInternet()) {
      return {'success': false, 'message': 'لا يوجد اتصال بالإنترنت'};
    }

    try {
      final token = await authService.getToken();
      if (token == null) {
        return {'success': false, 'message': 'غير مسجل الدخول'};
      }

      String url =
          '${ApiConstants.baseUrl}${ApiConstants.patients}?page=$page&limit=$limit';

      if (query != null && query.isNotEmpty) {
        url += '&q=${Uri.encodeQueryComponent(query)}';
      }

      final response = await DioClient.dio.get(
        url,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final data = response.data;
      final patients = (data['data'] as List)
          .map((e) => Patient.fromJson(e))
          .toList();

      return {
        'success': true,
        'patients': patients,
        'pagination': data['pagination'],
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'تعذر الاتصال بالخادم',
      };
    }
  }

  // -------------------------
  // Get All Patients
  // -------------------------
  Future<Map<String, dynamic>> getAllPatients({String? query}) async {
    final List<Patient> all = [];
    int page = 1;
    int size = 100;

    while (true) {
      final result =
          await getPatients(query: query, page: page, limit: size);

      if (result['success'] != true) {
        return result;
      }

      final batch = result['patients'] as List<Patient>;
      all.addAll(batch);

      final pagination = result['pagination'];
      bool hasMore = false;

      if (pagination is Map && pagination['has_next'] == true) {
        hasMore = true;
      } else if (batch.length == size) {
        hasMore = true;
      }

      if (!hasMore) break;
      page++;
    }

    return {'success': true, 'patients': all};
  }

  // -------------------------
  // Get Patient By ID
  // -------------------------
  Future<Patient?> getPatient(String id) async {
    if (!await NetworkChecker.hasInternet()) return null;

    try {
      final token = await authService.getToken();
      if (token == null) return null;

      final response = await DioClient.dio.get(
        '${ApiConstants.baseUrl}${ApiConstants.patientById(id)}',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      return Patient.fromJson(response.data['data']);
    } catch (_) {
      return null;
    }
  }

  // -------------------------
  // Create Patient
  // -------------------------
  Future<Map<String, dynamic>> createPatient({
    required String name,
    required String phone,
    required String address,
  }) async {
    if (!await NetworkChecker.hasInternet()) {
      return {'success': false, 'message': 'لا يوجد اتصال بالإنترنت'};
    }

    try {
      final token = await authService.getToken();
      if (token == null) {
        return {'success': false, 'message': 'غير مسجل الدخول'};
      }

      final response = await DioClient.dio.post(
        '${ApiConstants.baseUrl}${ApiConstants.patients}',
        data: {
          'name': name,
          'phone': phone,
          'address': address,
        },
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      return {
        'success': true,
        'patient': Patient.fromJson(response.data['data']),
      };
    } catch (e) {
      return {'success': false, 'message': 'فشل الاتصال بالخادم'};
    }
  }

  // -------------------------
  // Update Patient
  // -------------------------
  Future<Map<String, dynamic>> updatePatient({
    required String id,
    required String name,
    required String phone,
    required String address,
    String? note,
  }) async {
    if (!await NetworkChecker.hasInternet()) {
      return {'success': false, 'message': 'لا يوجد اتصال بالإنترنت'};
    }

    try {
      final token = await authService.getToken();

      final response = await DioClient.dio.patch(
        '${ApiConstants.baseUrl}${ApiConstants.patientById(id)}',
        data: {
          'name': name,
          'phone': phone,
          'address': address,
          if (note != null) 'note': note,
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      return {
        'success': true,
        'patient': Patient.fromJson(response.data['data']),
      };
    } catch (_) {
      return {'success': false, 'message': 'فشل تحديث بيانات المريض'};
    }
  }

  // -------------------------
  // Upload Images
  // -------------------------
  Future<Map<String, dynamic>> uploadImages({
    required String patientId,
    required int stepNumber,
    required List<XFile> images,
  }) async {
    if (!await NetworkChecker.hasInternet()) {
      return {'success': false, 'message': 'لا يوجد اتصال بالإنترنت'};
    }

    try {
      final token = await authService.getToken();
      final url =
          '${ApiConstants.baseUrl}${ApiConstants.uploadImages(patientId, stepNumber)}';

      final formData = FormData();

      for (var img in images) {
        formData.files.add(
          MapEntry(
            'files',
            await MultipartFile.fromFile(img.path),
          ),
        );
      }

      final response = await DioClient.dio.post(
        url,
        data: formData,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      return {
        'success': true,
        'message': response.data['message'] ?? 'تم رفع الصور بنجاح',
        'data': response.data['data'],
      };
    } catch (_) {
      return {
        'success': false,
        'message': 'فشل رفع الصور، حاول مرة أخرى',
      };
    }
  }

  // -------------------------
  // Mark Step Done
  // -------------------------
  Future<Map<String, dynamic>> markStepDone({
    required String patientId,
    required int stepNumber,
    required bool isDone,
  }) async {
    if (!await NetworkChecker.hasInternet()) {
      return {'success': false, 'message': 'لا يوجد اتصال بالإنترنت'};
    }

    try {
      final token = await authService.getToken();

      await DioClient.dio.patch(
        '${ApiConstants.baseUrl}${ApiConstants.markStepDone(
              patientId,
              stepNumber,
            )}',
        data: {'is_done': isDone},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      return {'success': true};
    } catch (_) {
      return {'success': false, 'message': 'فشل تحديث الخطوة'};
    }
  }

  // -------------------------
  // Delete Patient
  // -------------------------
  Future<Map<String, dynamic>> deletePatient(String id) async {
    if (!await NetworkChecker.hasInternet()) {
      return {'success': false, 'message': 'لا يوجد اتصال بالإنترنت'};
    }

    try {
      final token = await authService.getToken();
      if (token == null) {
        return {'success': false, 'message': 'غير مسجل الدخول'};
      }

      await DioClient.dio.delete(
        '${ApiConstants.baseUrl}${ApiConstants.patientById(id)}',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      return {'success': true};
    } catch (_) {
      return {'success': false, 'message': 'فشل حذف المريض'};
    }
  }

  // -------------------------
  // Completed Patients (Admin)
  // -------------------------
  Future<Map<String, dynamic>> getCompletedPatients() async {
    if (!await NetworkChecker.hasInternet()) {
      return {'success': false, 'message': 'لا يوجد اتصال بالإنترنت'};
    }

    try {
      final token = await authService.getToken();
      if (token == null) {
        return {'success': false, 'message': 'غير مسجل الدخول'};
      }

      final response = await DioClient.dio.get(
        '${ApiConstants.baseUrl}${ApiConstants.patients}/filter/completed',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final patients = (response.data['data'] as List)
          .map((e) => Patient.fromJson(e))
          .toList();

      return {'success': true, 'patients': patients};
    } catch (_) {
      return {'success': false, 'message': 'فشل جلب المرضى المكتملين'};
    }
  }

  // -------------------------
  // Delete Image
  // -------------------------
  Future<Map<String, dynamic>> deleteImage({
    required String patientId,
    required int stepNumber,
    required String imageId,
  }) async {
    if (!await NetworkChecker.hasInternet()) {
      return {'success': false, 'message': 'لا يوجد اتصال بالإنترنت'};
    }

    try {
      final token = await authService.getToken();

      await DioClient.dio.delete(
        '${ApiConstants.baseUrl}${ApiConstants.deleteImage(
              patientId,
              stepNumber,
              imageId,
            )}',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      return {'success': true, 'message': 'تم حذف الصورة'};
    } catch (_) {
      return {'success': false, 'message': 'فشل حذف الصورة'};
    }
  }

  // -------------------------
  // Dashboard Stats
  // -------------------------
  Future<Map<String, dynamic>> getStatistics() async {
    if (!await NetworkChecker.hasInternet()) {
      return {'success': false, 'message': 'لا يوجد اتصال بالإنترنت'};
    }

    try {
      final token = await authService.getToken();

      final response = await DioClient.dio.get(
        '${ApiConstants.baseUrl}/patients/stats/dashboard',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      return {
        'success': true,
        'data': response.data['data'],
      };
    } catch (_) {
      return {'success': false, 'message': 'فشل جلب الإحصائيات'};
    }
  }

  // -------------------------
  // Completed by Phase
  // -------------------------
  Future<Map<String, dynamic>> getCompletedByPhase(int phase) async {
    if (!await NetworkChecker.hasInternet()) {
      return {'success': false, 'message': 'لا يوجد اتصال بالإنترنت'};
    }

    try {
      final token = await authService.getToken();
      if (token == null) {
        return {'success': false, 'message': 'غير مسجل الدخول'};
      }

      final response = await DioClient.dio.get(
        '${ApiConstants.baseUrl}/patients/filter/completed/phase/$phase',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final patients = (response.data['data'] as List)
          .map((e) => Patient.fromJson(e))
          .toList();

      return {'success': true, 'patients': patients};
    } catch (_) {
      return {'success': false, 'message': 'فشل جلب المرضى للمراحل'};
    }
  }

  // -------------------------
  // Zero-step patients
  // -------------------------
  Future<Map<String, dynamic>> getZeroStepPatients() async {
    if (!await NetworkChecker.hasInternet()) {
      return {'success': false, 'message': 'لا يوجد اتصال بالإنترنت'};
    }

    try {
      final token = await authService.getToken();
      if (token == null) {
        return {'success': false, 'message': 'غير مسجل الدخول'};
      }

      final response = await DioClient.dio.get(
        '${ApiConstants.baseUrl}/patients/filter/zero-step',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final patients = (response.data['data'] as List)
          .map((e) => Patient.fromJson(e))
          .toList();

      return {'success': true, 'patients': patients};
    } catch (_) {
      return {'success': false, 'message': 'فشل جلب المرضى (لا خطوات مكتملة)'};
    }
  }
}
