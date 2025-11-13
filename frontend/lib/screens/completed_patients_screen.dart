import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:cached_network_image/cached_network_image.dart';
import '../core/theme/app_theme.dart';
import '../models/patient.dart';
import '../services/patient_service.dart';
import 'patient_detail_screen.dart';

class CompletedPatientsScreen extends StatefulWidget {
  const CompletedPatientsScreen({super.key});

  @override
  State<CompletedPatientsScreen> createState() => _CompletedPatientsScreenState();
}

class _CompletedPatientsScreenState extends State<CompletedPatientsScreen> {
  final _patientService = PatientService();
  List<Patient> _patients = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCompletedPatients();
  }

  Future<void> _loadCompletedPatients() async {
    setState(() => _isLoading = true);
    final result = await _patientService.getCompletedPatients();
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result['success'] == true) {
          _patients = result['patients'] as List<Patient>;
        }
      });

      if (result['success'] != true && result['message'] != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  Future<void> _deletePatient(Patient patient) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حذف مريض'),
          content: Text('هل أنت متأكد من حذف ملف المريض "${patient.name}"؟\n\nسيتم حذف جميع البيانات والصور نهائياً.'),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed),
              child: const Text('حذف'),
            ),
          ],
        ),
      ),
    );

    if (confirm == true) {
      final result = await _patientService.deletePatient(patient.id);
      if (mounted) {
        if (result['success'] == true) {
          setState(() {
            _patients.removeWhere((p) => p.id == patient.id);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم حذف المريض بنجاح'),
              backgroundColor: AppTheme.successGreen,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'فشل في حذف المريض'),
              backgroundColor: AppTheme.errorRed,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: const Text(
            'المرضى المكتملين',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 20,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_forward_rounded),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _patients.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 80,
                          color: AppTheme.successGreen.withOpacity(0.5),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'لا توجد حالات مكتملة بعد',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadCompletedPatients,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _patients.length,
                      itemBuilder: (context, index) {
                        final patient = _patients[index];
                        return _CompletedPatientCard(
                          patient: patient,
                          onTap: () async {
                            final updated = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PatientDetailScreen(
                                  patientId: patient.id,
                                ),
                              ),
                            );
                            if (updated is Patient) {
                              setState(() {
                                final idx = _patients.indexWhere((p) => p.id == updated.id);
                                if (idx != -1) {
                                  // Check if still completed
                                  if (updated.progressPercentage >= 100) {
                                    _patients[idx] = updated;
                                  } else {
                                    _patients.removeAt(idx);
                                  }
                                }
                              });
                            }
                          },
                          onDelete: () => _deletePatient(patient),
                        );
                      },
                    ),
                  ),
      ),
    );
  }
}

class _CompletedPatientCard extends StatelessWidget {
  final Patient patient;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _CompletedPatientCard({
    required this.patient,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = intl.DateFormat('dd/MM/yyyy', 'ar');

    // جلب الصورة
    String? avatarUrl;
    try {
      final step1 = patient.steps.firstWhere((s) => s.stepNumber == 1);
      if (step1.images.isNotEmpty) avatarUrl = step1.images.first.url;
    } catch (_) {}

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            const Color(0xFF10B981).withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withOpacity(0.15),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // الصورة
                Container(
                  width: 70,
                  height: 85,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    image: avatarUrl != null
                        ? DecorationImage(
                            image: CachedNetworkImageProvider(avatarUrl!),
                            fit: BoxFit.cover,
                          )
                        : null,
                    color: avatarUrl == null ? AppTheme.successGreen.withOpacity(0.1) : null,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.successGreen.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: avatarUrl == null
                      ? const Icon(
                          Icons.person_rounded,
                          color: AppTheme.successGreen,
                          size: 36,
                        )
                      : null,
                ),
                const SizedBox(width: 14),
                // المعلومات
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              patient.name,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textDark,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  AppTheme.successGreen,
                                  Color(0xFF10B981),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.check_circle, color: Colors.white, size: 16),
                                SizedBox(width: 4),
                                Text(
                                  'مكتمل',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        patient.phone,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.calendar_today_rounded, size: 13, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text(
                            dateFormat.format(patient.registrationDate),
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // زر حذف
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppTheme.errorRed,
                    size: 24,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
