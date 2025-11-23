import 'dart:async';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/network/dio_client.dart';
import '../../models/patient.dart';
import '../../services/auth_service.dart';

class PatientApi {
  final AuthService authService = AuthService();

  Future<Map<String, dynamic>> getAllPatients({String? query}) async {
    int page = 1;
    int limit = 100;
    final List<Patient> all = [];
    while (true) {
      final chunk = await _getPatients(page: page, limit: limit, query: query);
      if (chunk['success'] != true) return chunk;
      final items = chunk['patients'] as List<Patient>;
      all.addAll(items);
      final pagination = chunk['pagination'];
      bool hasMore;
      if (pagination is Map<String, dynamic>) {
        if (pagination['has_next'] is bool) {
          hasMore = pagination['has_next'] == true;
        } else if (pagination['page'] != null && pagination['total_pages'] != null) {
          try {
            final int current = (pagination['page'] as num).toInt();
            final int total = (pagination['total_pages'] as num).toInt();
            hasMore = current < total;
          } catch (_) {
            hasMore = items.length == limit;
          }
        } else if (pagination['next_page'] != null) {
          hasMore = pagination['next_page'] != null;
        } else {
          hasMore = items.length == limit;
        }
      } else {
        hasMore = items.length == limit;
      }
      if (!hasMore) break;
      page += 1;
    }
    return {'success': true, 'patients': all};
  }

  Future<Map<String, dynamic>> _getPatients({required int page, required int limit, String? query}) async {
    try {
      final token = await authService.getToken();
      if (token == null) return {'success': false, 'message': 'غير مسجل الدخول'};
      final queryParams = {'page': page, 'limit': limit, if (query != null && query.isNotEmpty) 'q': query};
      final res = await DioClient.instance.get<Map<String, dynamic>>(
        '/patients',
        query: queryParams,
        headers: {'Authorization': 'Bearer $token'},
      );
      final data = res.data!;
      final patients = (data['data'] as List).map((e) => Patient.fromJson(e)).toList();
      return {'success': true, 'patients': patients, 'pagination': data['pagination']};
    } on DioException catch (e) {
      return {'success': false, 'message': e.message ?? 'فشل في جلب البيانات'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Patient?> getPatient(String id) async {
    try {
      final token = await authService.getToken();
      if (token == null) return null;
      final res = await DioClient.instance.get<Map<String, dynamic>>(
        '/patients/$id',
        headers: {'Authorization': 'Bearer $token'},
      );
      return Patient.fromJson(res.data!['data']);
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> createPatient({required String name, required String phone, required String address}) async {
    try {
      final token = await authService.getToken();
      if (token == null) return {'success': false, 'message': 'غير مسجل الدخول'};
      final res = await DioClient.instance.post<Map<String, dynamic>>(
        '/patients',
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        data: {'name': name, 'phone': phone, 'address': address},
      );
      return {'success': true, 'patient': Patient.fromJson(res.data!['data'])};
    } on DioException catch (e) {
      return {'success': false, 'message': e.message ?? 'فشل في إضافة المريض'};
    }
  }

  Future<Map<String, dynamic>> updatePatient({required String id, required String name, required String phone, required String address}) async {
    try {
      final token = await authService.getToken();
      if (token == null) return {'success': false, 'message': 'غير مسجل الدخول'};
      final res = await DioClient.instance.patch<Map<String, dynamic>>(
        '/patients/$id',
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        data: {'name': name, 'phone': phone, 'address': address},
      );
      return {'success': true, 'patient': Patient.fromJson(res.data!['data'])};
    } on DioException catch (e) {
      return {'success': false, 'message': e.message ?? 'فشل في تحديث بيانات المريض'};
    }
  }

  Future<Map<String, dynamic>> uploadImages({required String patientId, required int stepNumber, required List<XFile> images}) async {
    try {
      final token = await authService.getToken();
      if (token == null) return {'success': false, 'message': 'غير مسجل الدخول'};
      final files = await Future.wait(images.map((x) => MultipartFile.fromFile(x.path, filename: x.name)));
      final form = FormData.fromMap({'files': files});
      final res = await DioClient.instance.post<Map<String, dynamic>>(
        '/patients/$patientId/steps/$stepNumber/upload',
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'multipart/form-data'},
        data: form,
        contentType: 'multipart/form-data',
      );
      return {'success': true, 'message': res.data?['message'] ?? 'تم رفع الصور بنجاح', 'data': res.data?['data']};
    } on DioException catch (e) {
      return {'success': false, 'message': e.message ?? 'فشل في رفع الصور'};
    }
  }

  Future<Map<String, dynamic>> markStepDone({required String patientId, required int stepNumber, required bool isDone}) async {
    try {
      final token = await authService.getToken();
      if (token == null) return {'success': false, 'message': 'غير مسجل الدخول'};
      await DioClient.instance.patch<Map<String, dynamic>>(
        '/patients/$patientId/steps/$stepNumber/done',
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        data: {'is_done': isDone},
      );
      return {'success': true};
    } on DioException catch (e) {
      return {'success': false, 'message': e.message ?? 'فشل في تحديث الحالة'};
    }
  }

  Future<Map<String, dynamic>> deleteImage({required String patientId, required int stepNumber, required String imageId}) async {
    try {
      final token = await authService.getToken();
      if (token == null) return {'success': false, 'message': 'غير مسجل الدخول'};
      await DioClient.instance.delete<Map<String, dynamic>>(
        '/patients/$patientId/steps/$stepNumber/images/$imageId',
        headers: {'Authorization': 'Bearer $token'},
      );
      return {'success': true, 'message': 'تم حذف الصورة'};
    } on DioException catch (e) {
      return {'success': false, 'message': e.message ?? 'فشل في حذف الصورة'};
    }
  }

  Future<Map<String, dynamic>> getStatistics() async {
    try {
      final token = await authService.getToken();
      if (token == null) return {'success': false, 'message': 'غير مسجل الدخول'};
      final res = await DioClient.instance.get<Map<String, dynamic>>(
        '/patients/stats/dashboard',
        headers: {'Authorization': 'Bearer $token'},
      );
      return {'success': true, 'data': res.data?['data']};
    } on DioException catch (e) {
      return {'success': false, 'message': e.message ?? 'فشل في جلب الإحصائيات'};
    }
  }

  Future<Map<String, dynamic>> getCompletedPatients() async {
    try {
      final token = await authService.getToken();
      if (token == null) return {'success': false, 'message': 'غير مسجل الدخول'};
      final res = await DioClient.instance.get<Map<String, dynamic>>(
        '/patients/filter/completed',
        headers: {'Authorization': 'Bearer $token'},
      );
      final patients = (res.data?['data'] as List).map((e) => Patient.fromJson(e)).toList();
      return {'success': true, 'patients': patients};
    } on DioException catch (e) {
      return {'success': false, 'message': e.message ?? 'فشل في جلب البيانات'};
    }
  }

  Future<Map<String, dynamic>> deletePatient(String patientId) async {
    try {
      final token = await authService.getToken();
      if (token == null) return {'success': false, 'message': 'غير مسجل الدخول'};
      await DioClient.instance.delete<Map<String, dynamic>>(
        '/patients/$patientId',
        headers: {'Authorization': 'Bearer $token'},
      );
      return {'success': true, 'message': 'تم حذف المريض بنجاح'};
    } on DioException catch (e) {
      return {'success': false, 'message': e.message ?? 'فشل في حذف المريض'};
    }
  }
}


