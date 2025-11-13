class ApiConstants {
  // Base URL - غيّر هذا للـ IP الخاص بجهازك أو السيرفر
  // للإيميوليتر Android: استخدم 'http://10.0.2.2:5030'
  // للجهاز الحقيقي: استخدم IP جهاز الكمبيوتر
  static const String baseUrl = 'http://10.0.2.2:5030';  // ✅ Android Emulator
  
  // Auth endpoints
  static const String login = '/auth/login';
  static const String me = '/auth/me';
  
  // Patient endpoints
  static const String patients = '/patients';
  static String patientById(String id) => '/patients/$id';
  
  // Step endpoints
  static String uploadImages(String patientId, int stepNumber) =>
      '/patients/$patientId/steps/$stepNumber/upload';
  static String markStepDone(String patientId, int stepNumber) =>
      '/patients/$patientId/steps/$stepNumber/done';
  static String deleteImage(String patientId, int stepNumber, String imageId) =>
      '/patients/$patientId/steps/$stepNumber/images/$imageId';
  
  // Metrics
  static const String metrics = '/metrics';
}
