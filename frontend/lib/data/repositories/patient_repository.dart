import 'dart:async';
import 'package:drift/drift.dart' as d;

import '../../models/patient.dart' as domain;
import '../local/app_database.dart';
import '../remote/patient_api.dart';

class PatientRepository {
  final AppDatabase db;
  final PatientApi api;

  PatientRepository({required this.db, required this.api});

  // Map Domain -> Drift companions
  Future<void> savePatientsToLocal(List<domain.Patient> patients) async {
    if (patients.isEmpty) return;
    await db.transaction(() async {
      for (final p in patients) {
        await db.upsertPatients([
          PatientsCompanion(
            id: d.Value(p.id),
            name: d.Value(p.name),
            phone: d.Value(p.phone),
            address: d.Value(p.address),
            registrationDate: d.Value(p.registrationDate.toIso8601String()),
            lastSyncedAt: d.Value(DateTime.now()),
          ),
        ]);

        // ensure case exists (1:1 with patient)
        final caseRow = await db.getCaseByPatient(p.id);
        final caseId = caseRow?.id ?? p.id; // reuse patient id for simplicity
        await db.upsertCase(
          CasesCompanion(
            id: d.Value(caseId),
            patientId: d.Value(p.id),
            title: const d.Value(null),
            createdAt: d.Value(caseRow?.createdAt ?? DateTime.now()),
          ),
        );

        // steps
        final stepsRows = <StepsCompanion>[];
        for (final s in p.steps) {
          stepsRows.add(
            StepsCompanion(
              id: d.Value(s.id),
              caseId: d.Value(caseId),
              stepNumber: d.Value(s.stepNumber),
              title: d.Value(s.title),
              description: d.Value(s.description),
              isDone: d.Value(s.isDone),
            ),
          );
        }
        await db.replaceStepsForCase(caseId, stepsRows);

        // images
        for (final s in p.steps) {
          final imagesRows = s.images
              .map(
                (img) => ImagesCompanion(
                  id: d.Value(img.id),
                  stepId: d.Value(s.id),
                  url: d.Value(img.url),
                  uploadedAt: d.Value(img.uploadedAt.toIso8601String()),
                ),
              )
              .toList();
          await db.replaceImagesForStep(s.id, imagesRows);
        }
      }
    });
  }

  // Local -> Domain
  Future<List<domain.Patient>> getLocalPatients({String? query}) async {
    // 1) Patients in one query
    final patientRows = await db.getAllPatientsBasic(query: query);
    if (patientRows.isEmpty) return const [];
    final patientIds = patientRows.map((p) => p.id).toList();

    // 2) Cases for all patients (single query)
    final caseRows = await (db.select(db.cases)..where((c) => c.patientId.isIn(patientIds))).get();
    final patientIdToCaseId = <String, String>{};
    for (final c in caseRows) {
      patientIdToCaseId[c.patientId] = c.id;
    }
    // Ensure caseId even if not present (fallback to patientId)
    for (final pid in patientIds) {
      patientIdToCaseId.putIfAbsent(pid, () => pid);
    }
    final caseIds = patientIdToCaseId.values.toSet().toList();

    // 3) Steps for all cases (single query)
    final stepRows = await (db.select(db.steps)..where((s) => s.caseId.isIn(caseIds))).get();
    final stepIds = stepRows.map((s) => s.id).toList();

    // 4) Images for all steps (single query)
    final imgRows = stepIds.isEmpty
        ? const []
        : await (db.select(db.images)..where((i) => i.stepId.isIn(stepIds))).get();

    // Build maps
    final stepIdToImages = <String, List<dynamic>>{};
    for (final img in imgRows) {
      (stepIdToImages[img.stepId] ??= <dynamic>[]).add(img);
    }

    final caseIdToSteps = <String, List<dynamic>>{};
    for (final s in stepRows) {
      (caseIdToSteps[s.caseId] ??= <dynamic>[]).add(s);
    }

    // 5) Assemble domain models
    final out = <domain.Patient>[];
    for (final p in patientRows) {
      final caseId = patientIdToCaseId[p.id] ?? p.id;
      final stepsData = (caseIdToSteps[caseId] ?? const <dynamic>[])
        ..sort((a, b) => a.stepNumber.compareTo(b.stepNumber));
      final steps = stepsData
          .map((s) => domain.Step(
                id: s.id,
                stepNumber: s.stepNumber,
                title: s.title,
                description: s.description,
                images: (stepIdToImages[s.id] ?? const <dynamic>[])
                    .map((i) => domain.PatientImage(
                          id: i.id,
                          url: i.url,
                          uploadedAt: DateTime.parse(i.uploadedAt),
                        ))
                    .toList(),
                isDone: s.isDone,
              ))
          .toList();

      out.add(domain.Patient(
        id: p.id,
        name: p.name,
        phone: p.phone,
        address: p.address,
        registrationDate: DateTime.parse(p.registrationDate),
        steps: steps,
      ));
    }

    out.sort((a, b) => b.registrationDate.compareTo(a.registrationDate));
    return out;
  }

  // Sync
  Future<void> updateLocalFromNetwork({String? query}) async {
    final remote = await api.getAllPatients(query: query);
    if (remote['success'] == true) {
      final List<domain.Patient> fresh = (remote['patients'] as List<domain.Patient>);
      await savePatientsToLocal(fresh);
    }
  }

  // CRUD guarded by caller (online check)
  Future<Map<String, dynamic>> createPatient({required String name, required String phone, required String address}) async {
    final res = await api.createPatient(name: name, phone: phone, address: address);
    if (res['success'] == true) {
      await savePatientsToLocal([res['patient'] as domain.Patient]);
    }
    return res;
  }

  Future<Map<String, dynamic>> updatePatient({required String id, required String name, required String phone, required String address}) async {
    final res = await api.updatePatient(id: id, name: name, phone: phone, address: address);
    if (res['success'] == true) {
      await savePatientsToLocal([res['patient'] as domain.Patient]);
    }
    return res;
  }

  Future<Map<String, dynamic>> deletePatient(String patientId) async {
    final res = await api.deletePatient(patientId);
    if (res['success'] == true) {
      await db.deletePatientById(patientId);
    }
    return res;
  }
}


