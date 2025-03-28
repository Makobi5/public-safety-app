// lib/models/incident.dart

class Incident {
  final String id;
  final String userId;
  final String title;
  final String description;
  final String reference;
  final String status;
  final String category;
  final String location;
  final String createdAt;
  final String updatedAt;
  final String? additionalDetails;
  final List<IncidentProgress> progressUpdates;
  final List<AdminNote> adminNotes;

  Incident({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    required this.reference,
    required this.status,
    required this.category, 
    required this.location,
    required this.createdAt,
    required this.updatedAt,
    this.additionalDetails,
    this.progressUpdates = const [],
    this.adminNotes = const [],
  });

  factory Incident.fromMap(Map<String, dynamic> map) {
    // Parse the progress updates
    List<IncidentProgress> progressUpdates = [];
    if (map['incident_progress'] != null && map['incident_progress'] is List) {
      progressUpdates = List<Map<String, dynamic>>.from(map['incident_progress'])
          .map((progressMap) => IncidentProgress.fromMap(progressMap))
          .toList();
    }

    // Parse the admin notes
    List<AdminNote> adminNotes = [];
    if (map['admin_notes'] != null && map['admin_notes'] is List) {
      adminNotes = List<Map<String, dynamic>>.from(map['admin_notes'])
          .map((noteMap) => AdminNote.fromMap(noteMap))
          .toList();
    }

    return Incident(
      id: map['id'] ?? '',
      userId: map['user_id'] ?? '',
      title: map['title'] ?? 'Untitled Report',
      description: map['description'] ?? '',
      reference: map['reference'] ?? 'No Reference',
      status: map['status'] ?? 'Pending',
      category: map['category'] ?? 'Uncategorized',
      location: map['location'] ?? 'Unknown location',
      createdAt: map['created_at'] ?? '',
      updatedAt: map['updated_at'] ?? '',
      additionalDetails: map['additional_details'],
      progressUpdates: progressUpdates,
      adminNotes: adminNotes,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'description': description,
      'reference': reference,
      'status': status,
      'category': category,
      'location': location,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'additional_details': additionalDetails,
    };
  }
}

class IncidentProgress {
  final String id;
  final String incidentId;
  final String? updatedById;
  final String? updatedByName;
  final String progressDetails;
  final String? statusChange;
  final String updatedAt;

  IncidentProgress({
    required this.id,
    required this.incidentId,
    this.updatedById,
    this.updatedByName,
    required this.progressDetails,
    this.statusChange,
    required this.updatedAt,
  });

  factory IncidentProgress.fromMap(Map<String, dynamic> map) {
    return IncidentProgress(
      id: map['id'] ?? '',
      incidentId: map['incident_id'] ?? '',
      updatedById: map['updated_by_id'],
      updatedByName: map['updated_by_name'],
      progressDetails: map['progress_details'] ?? 'No details provided',
      statusChange: map['status_change'],
      updatedAt: map['updated_at'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'incident_id': incidentId,
      'updated_by_id': updatedById,
      'updated_by_name': updatedByName,
      'progress_details': progressDetails,
      'status_change': statusChange,
      'updated_at': updatedAt,
    };
  }
}

class AdminNote {
  final String id;
  final String incidentId;
  final String? adminId;
  final String? adminName;
  final String note;
  final bool isImportant;
  final String createdAt;

  AdminNote({
    required this.id,
    required this.incidentId,
    this.adminId,
    this.adminName,
    required this.note,
    this.isImportant = false,
    required this.createdAt,
  });

  factory AdminNote.fromMap(Map<String, dynamic> map) {
    return AdminNote(
      id: map['id'] ?? '',
      incidentId: map['incident_id'] ?? '',
      adminId: map['admin_id'],
      adminName: map['admin_name'],
      note: map['note'] ?? 'No content',
      isImportant: map['is_important'] == true,
      createdAt: map['created_at'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'incident_id': incidentId,
      'admin_id': adminId,
      'admin_name': adminName,
      'note': note,
      'is_important': isImportant,
      'created_at': createdAt,
    };
  }
}