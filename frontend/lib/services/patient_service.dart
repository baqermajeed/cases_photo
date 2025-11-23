import 'dart:async';
import 'package:image_picker/image_picker.dart';
import '../models/patient.dart' as domain;
import '../core/network/connectivity_service.dart';
import '../data/local/app_database.dart';
import '../data/remote/patient_api.dart';
import '../data/repositories/patient_repository.dart';

class PatientService {
  final PatientRepository _repo = PatientRepository(
    db: AppDatabase(),
    api: PatientApi(),
  );
  final ConnectivityService _net = ConnectivityService.instance;

  // Offline-first: read from Drift immediately, then sync in background
  Future<Map<String, dynamic>> getPatients({
    String? query,
    int page = 1,
    int limit = 1000,
  }) async {
    final local = await _repo.getLocalPatients(query: query);
    // background sync
    () async {
      final online = await _net.isOnline();
      if (online) {
        await _repo.updateLocalFromNetwork(query: query);
      }
    }();
    return {
      'success': true,
      'patients': local,
      'pagination': null,
    };
  }

  // Fetch all patients across pages (not needed with Drift cache)
  Future<Map<String, dynamic>> getAllPatients({String? query}) async {
    return getPatients(query: query);
  }

  // Get patient by ID
  Future<domain.Patient?> getPatient(String id) async {
    final local = await _repo.getLocalPatients();
    final p = local.firstWhere(
      (e) => e.id == id,
      orElse: () => domain.Patient(
        id: '',
        name: '',
        phone: '',
        address: '',
        registrationDate: DateTime.now(),
        steps: const [],
      ),
    );
    if (p.id.isEmpty) return null;
    // background refresh for this patient
    () async {
      final online = await _net.isOnline();
      if (online) {
        final api = PatientApi();
        final fresh = await api.getPatient(id);
        if (fresh != null) {
          await _repo.savePatientsToLocal([fresh]);
        }
      }
    }();
    return p;
  }

  // Create new patient
  Future<Map<String, dynamic>> createPatient({
    required String name,
    required String phone,
    required String address,
  }) async {
    final online = await _net.isOnline();
    if (!online) {
      return {'success': false, 'message': 'لا يمكن تنفيذ العملية بدون اتصال بالإنترنت'};
    }
    return _repo.createPatient(name: name, phone: phone, address: address);
  }

  // Update patient basic info
  Future<Map<String, dynamic>> updatePatient({
    required String id,
    required String name,
    required String phone,
    required String address,
  }) async {
    final online = await _net.isOnline();
    if (!online) {
      return {'success': false, 'message': 'لا يمكن تنفيذ العملية بدون اتصال بالإنترنت'};
    }
    return _repo.updatePatient(id: id, name: name, phone: phone, address: address);
  }

  // Upload images to a step
  Future<Map<String, dynamic>> uploadImages({
    required String patientId,
    required int stepNumber,
    required List<XFile> images,
  }) async {
    final online = await _net.isOnline();
    if (!online) {
      return {'success': false, 'message': 'لا يمكن تنفيذ العملية بدون اتصال بالإنترنت'};
    }
    final api = PatientApi();
    final res = await api.uploadImages(patientId: patientId, stepNumber: stepNumber, images: images);
    if (res['success'] == true) {
      // refresh patient data locally
      final fresh = await api.getPatient(patientId);
      if (fresh != null) {
        await _repo.savePatientsToLocal([fresh]);
      }
    }
    return res;
  }

  // Mark step as done
  Future<Map<String, dynamic>> markStepDone({
    required String patientId,
    required int stepNumber,
    required bool isDone,
  }) async {
    final online = await _net.isOnline();
    if (!online) {
      return {'success': false, 'message': 'لا يمكن تنفيذ العملية بدون اتصال بالإنترنت'};
    }
    final api = PatientApi();
    final res = await api.markStepDone(patientId: patientId, stepNumber: stepNumber, isDone: isDone);
    if (res['success'] == true) {
      // reflect locally
      await _repo.db.markStepDoneLocal(patientId: patientId, stepNumber: stepNumber, isDone: isDone);
    }
    return res;
  }

  // Delete image
  Future<Map<String, dynamic>> deleteImage({
    required String patientId,
    required int stepNumber,
    required String imageId,
  }) async {
    final online = await _net.isOnline();
    if (!online) {
      return {'success': false, 'message': 'لا يمكن تنفيذ العملية بدون اتصال بالإنترنت'};
    }
    final api = PatientApi();
    final res = await api.deleteImage(patientId: patientId, stepNumber: stepNumber, imageId: imageId);
    if (res['success'] == true) {
      final fresh = await api.getPatient(patientId);
      if (fresh != null) {
        await _repo.savePatientsToLocal([fresh]);
      }
    }
    return res;
  }

  // Get statistics (admin only)
  Future<Map<String, dynamic>> getStatistics() async {
    final local = await _repo.getLocalPatients();
    int total = local.length;
    int completed = local.where((p) => p.progressPercentage >= 100).length;
    int incomplete = total - completed;
    return {
      'success': true,
      'data': {
        'total_patients': total,
        'completed_patients': completed,
        'incomplete_patients': incomplete,
      },
    };
  }

  // Get completed patients (admin only)
  Future<Map<String, dynamic>> getCompletedPatients() async {
    final local = await _repo.getLocalPatients();
    final completed = local.where((p) => p.progressPercentage >= 100).toList();
    return {'success': true, 'patients': completed};
  }

  // Delete patient (admin only)
  Future<Map<String, dynamic>> deletePatient(String patientId) async {
    final online = await _net.isOnline();
    if (!online) {
      return {'success': false, 'message': 'لا يمكن تنفيذ العملية بدون اتصال بالإنترنت'};
    }
    return _repo.deletePatient(patientId);
  }
}
