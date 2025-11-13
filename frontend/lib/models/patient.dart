class PatientImage {
  final String id;
  final String url;
  final DateTime uploadedAt;

  PatientImage({
    required this.id,
    required this.url,
    required this.uploadedAt,
  });

  factory PatientImage.fromJson(Map<String, dynamic> json) {
    return PatientImage(
      id: json['id'] as String,
      url: json['url'] as String,
      uploadedAt: DateTime.parse(json['uploaded_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'url': url,
      'uploaded_at': uploadedAt.toIso8601String(),
    };
  }
}

class Step {
  final String id;
  final int stepNumber;
  final String title;
  final String? description;
  final List<PatientImage> images;
  final bool isDone;

  Step({
    required this.id,
    required this.stepNumber,
    required this.title,
    this.description,
    required this.images,
    required this.isDone,
  });

  factory Step.fromJson(Map<String, dynamic> json) {
    return Step(
      id: json['id'] as String,
      stepNumber: json['step_number'] as int,
      title: json['title'] as String,
      description: json['description'] as String?,
      images: (json['images'] as List<dynamic>)
          .map((e) => PatientImage.fromJson(e as Map<String, dynamic>))
          .toList(),
      isDone: json['is_done'] as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'step_number': stepNumber,
      'title': title,
      'description': description,
      'images': images.map((e) => e.toJson()).toList(),
      'is_done': isDone,
    };
  }

  Step copyWith({
    String? id,
    int? stepNumber,
    String? title,
    String? description,
    List<PatientImage>? images,
    bool? isDone,
  }) {
    return Step(
      id: id ?? this.id,
      stepNumber: stepNumber ?? this.stepNumber,
      title: title ?? this.title,
      description: description ?? this.description,
      images: images ?? this.images,
      isDone: isDone ?? this.isDone,
    );
  }
}

class Patient {
  final String id;
  final String name;
  final String phone;
  final String address;
  final DateTime registrationDate;
  final List<Step> steps;

  Patient({
    required this.id,
    required this.name,
    required this.phone,
    required this.address,
    required this.registrationDate,
    required this.steps,
  });

  factory Patient.fromJson(Map<String, dynamic> json) {
    return Patient(
      id: json['_id'] as String? ?? json['id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String,
      address: json['address'] as String,
      registrationDate: DateTime.parse(json['registration_date'] as String),
      steps: (json['steps'] as List<dynamic>)
          .map((e) => Step.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'address': address,
      'registration_date': registrationDate.toIso8601String(),
      'steps': steps.map((e) => e.toJson()).toList(),
    };
  }

  // Helper to get progress percentage
  double get progressPercentage {
    if (steps.isEmpty) return 0.0;
    int completedSteps = steps.where((s) => s.isDone).length;
    return (completedSteps / steps.length) * 100;
  }

  // Helper to get completed steps count
  int get completedStepsCount {
    return steps.where((s) => s.isDone).length;
  }
}
