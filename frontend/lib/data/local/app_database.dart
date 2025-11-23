import 'package:drift/drift.dart';
import 'package:drift_sqflite/drift_sqflite.dart';

part 'app_database.g.dart';

class Patients extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get phone => text()();
  TextColumn get address => text()();
  // ISO8601 string to keep parity with backend
  TextColumn get registrationDate => text()();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Cases extends Table {
  TextColumn get id => text()();
  TextColumn get patientId => text().references(Patients, #id, onDelete: KeyAction.cascade)();
  TextColumn get title => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class Steps extends Table {
  TextColumn get id => text()();
  TextColumn get caseId => text().references(Cases, #id, onDelete: KeyAction.cascade)();
  IntColumn get stepNumber => integer()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  BoolColumn get isDone => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class Images extends Table {
  TextColumn get id => text()();
  TextColumn get stepId => text().references(Steps, #id, onDelete: KeyAction.cascade)();
  TextColumn get url => text()();
  TextColumn get uploadedAt => text()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Patients, Cases, Steps, Images])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  // Patients
  Future<void> upsertPatients(List<PatientsCompanion> rows) async {
    if (rows.isEmpty) return;
    await batch((b) {
      b.insertAllOnConflictUpdate(patients, rows);
    });
  }

  Future<void> deletePatientById(String id) async {
    await (delete(patients)..where((tbl) => tbl.id.equals(id))).go();
  }

  Stream<List<Patient>> watchAllPatientsBasic() {
    return (select(patients)..orderBy([(t) => OrderingTerm.desc(t.registrationDate)])).watch();
  }

  Future<List<Patient>> getAllPatientsBasic({String? query}) async {
    final q = select(patients)..orderBy([(t) => OrderingTerm.desc(t.registrationDate)]);
    if (query != null && query.trim().isNotEmpty) {
      final like = '%${query.trim()}%';
      q.where((tbl) => tbl.name.like(like) | tbl.phone.like(like));
    }
    return q.get();
  }

  Future<Patient?> getPatientBasic(String id) {
    return (select(patients)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  // Cases
  Future<void> upsertCase(CasesCompanion row) async {
    await into(cases).insertOnConflictUpdate(row);
  }

  Future<Case?> getCaseByPatient(String patientId) {
    return (select(cases)..where((c) => c.patientId.equals(patientId))).getSingleOrNull();
  }

  // Steps
  Future<void> replaceStepsForCase(String caseId, List<StepsCompanion> rows) async {
    await (delete(steps)..where((s) => s.caseId.equals(caseId))).go();
    if (rows.isNotEmpty) {
      await batch((b) => b.insertAllOnConflictUpdate(steps, rows));
    }
  }

  Future<void> markStepDoneLocal({required String patientId, required int stepNumber, required bool isDone}) async {
    final caseRow = await getCaseByPatient(patientId);
    if (caseRow == null) return;
    await (update(steps)
          ..where((s) => s.caseId.equals(caseRow.id) & s.stepNumber.equals(stepNumber)))
        .write(StepsCompanion(isDone: Value(isDone)));
  }

  // Images
  Future<void> replaceImagesForStep(String stepId, List<ImagesCompanion> rows) async {
    await (delete(images)..where((i) => i.stepId.equals(stepId))).go();
    if (rows.isNotEmpty) {
      await batch((b) => b.insertAllOnConflictUpdate(images, rows));
    }
  }
}

QueryExecutor _openConnection() {
  return SqfliteQueryExecutor.inDatabaseFolder(path: 'farahdent_drift.db', logStatements: false);
}

