// lib/service/incident_report_service.dart

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'notification_service.dart';

class IncidentReportService {
  static final IncidentReportService _instance = IncidentReportService._internal();
  final NotificationService _notificationService = NotificationService();
  
  factory IncidentReportService() {
    return _instance;
  }

  IncidentReportService._internal();
  
  // Submit a new incident report
  Future<Map<String, dynamic>> submitIncidentReport({
    required String incidentType,
    required String district,
    required String description,
    required String reportedBy,
    String? policeStationId,
    String? location,
    List<String>? mediaUrls,
  }) async {
    try {
      final supabase = Supabase.instance.client;
      
      // Get the police station ID if not provided
      String? assignedStationId = policeStationId;
      if (assignedStationId == null) {
        // Try to find a police station in the district
        final stationsResponse = await supabase
            .from('police_stations')
            .select('id')
            .eq('district', district)
            .limit(1);
            
        if (stationsResponse != null && stationsResponse is List && stationsResponse.isNotEmpty) {
          assignedStationId = stationsResponse[0]['id'];
          debugPrint('Auto-assigned to police station: $assignedStationId');
        }
      }
      
      // Create the incident record
      final incidentData = {
        'incident_type': incidentType,
        'district': district,
        'description': description,
        'reported_by': reportedBy,
        'status': 'Pending',
        'police_station_id': assignedStationId,
        'location': location,
        'created_at': DateTime.now().toIso8601String(),
        'media_urls': mediaUrls,
      };
      
      debugPrint('Submitting incident report: $incidentData');
      
      // Insert into database
      final response = await supabase
          .from('incidents')
          .insert(incidentData)
          .select()
          .single();
      
      if (response != null) {
        debugPrint('Incident report submitted successfully with ID: ${response['id']}');
        
        // Process notifications for this new incident
        await _notificationService.processNewIncident(response);
        
        return response;
      } else {
        throw Exception('Failed to get response after submitting incident');
      }
    } catch (e) {
      debugPrint('Error submitting incident report: $e');
      rethrow;
    }
  }
  
  // Update an existing incident
  Future<Map<String, dynamic>> updateIncidentStatus({
    required String incidentId,
    required String status,
    String? notes,
    String? updatedBy,
  }) async {
    try {
      final supabase = Supabase.instance.client;
      
      // Update the incident
      final response = await supabase
          .from('incidents')
          .update({
            'status': status,
            'notes': notes,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', incidentId)
          .select()
          .single();
      
      if (response != null) {
        // Log the activity
        await supabase.from('incident_activity').insert({
          'incident_id': incidentId,
          'action': 'Status updated to $status',
          'performed_by': updatedBy,
          'created_at': DateTime.now().toIso8601String(),
        });
        
        return response;
      } else {
        throw Exception('Failed to update incident status');
      }
    } catch (e) {
      debugPrint('Error updating incident status: $e');
      rethrow;
    }
  }
}