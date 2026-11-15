import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class MedicalAssessment {
  final String assessment;
  final String urgencyLevel;
  final List<String> immediateActions;
  final String whyItMatters;

  MedicalAssessment({
    required this.assessment,
    required this.urgencyLevel,
    required this.immediateActions,
    required this.whyItMatters,
  });

  factory MedicalAssessment.fromJson(Map<String, dynamic> json) {
    return MedicalAssessment(
      assessment: json['assessment'] ?? 'No assessment provided.',
      urgencyLevel: json['urgency_level'] ?? 'Normal',
      immediateActions: List<String>.from(json['immediate_action'] ?? []),
      whyItMatters: json['why_it_matters'] ?? '',
    );
  }
}

class AIService {
  final String _apiKey = "your_api_key_here"; // Replace with your actual API key

  final List<String> _fallbackModels = [
    'openrouter/free',
    'google/gemma-2-9b-it:free',
    'mistralai/mistral-7b-instruct:free',
  ];

  String _getRelevantMedicalContext(String prompt) {
    String p = prompt.toLowerCase();
    if (p.contains('bone') || p.contains('density') || p.contains('calcium')) {
      return "\n[NASA Guideline]: Astronauts lose 1-1.5% bone mass per month in microgravity. Countermeasures include ARED exercise and ensuring 1000mg Calcium + 800IU Vit D daily.";
    } else if (p.contains('chest') || p.contains('heart') || p.contains('bpm')) {
      return "\n[NASA Guideline]: Sudden chest pain or arrhythmia in space may indicate pneumothorax, myocardial infarction, or severe fluid shifts. Immediate ECG and ground control consultation required.";
    } else if (p.contains('sleep') || p.contains('fatigue')) {
      return "\n[NASA Guideline]: Astronauts average 6 hours of sleep. Sleep debt reduces cognitive performance. Recommend 8 hours in a darkened sleep pod (circadian lighting).";
    }
    return "";
  }

  Future<MedicalAssessment> analyzeData(String dataContext, String userPrompt) async {
    String enrichedContext = dataContext + _getRelevantMedicalContext(userPrompt);

    for (String modelName in _fallbackModels) {
      try {
        final url = Uri.parse('https://openrouter.ai/api/v1/chat/completions');

        final body = jsonEncode({
          "model": modelName,
          "messages": [
            {
              "role": "system",
              "content": "You are Gibby Buddy, the specialized flight surgeon for astronauts (who are NOT doctors). "
                  "You must respond to users prompt ONLY with a raw JSON object (no markdown, no ```json) using this exact schema:\n"
                  "{\n"
                  "  \"assessment\": \"Brief medical assessment of the situation.\",\n"
                  "  \"urgency_level\": \"Normal | Caution | Emergency\",\n"
                  "  \"immediate_action\": [\"Step 1\", \"Step 2\"],\n"
                  "  \"why_it_matters\": \"Brief explanation of the physiological impact.\"\n"
                  "}\n\n"
                  "Here are examples of how you must respond:\n\n"
                  "EXAMPLE 1:\n"
                  "User Request: 'I feel short of breath. SpO2 is 91%.'\n"
                  "Your Response:\n"
                  "{\"assessment\": \"Hypoxia detected.\", \"urgency_level\": \"Emergency\", \"immediate_action\": [\"Check O2 tank pressure.\", \"Move to emergency breathing mask.\", \"Assume seated position.\"], \"why_it_matters\": \"Rapid desaturation in microgravity indicates a life-threatening environmental failure.\"}\n\n"
                  "EXAMPLE 2:\n"
                  "User Request: 'My bone density is 94% of baseline.'\n"
                  "Your Response:\n"
                  "{\"assessment\": \"Normal expected bone loss.\", \"urgency_level\": \"Normal\", \"immediate_action\": [\"Maintain ARED exercise.\", \"Log Calcium and Vit D intake.\"], \"why_it_matters\": \"Microgravity removes mechanical loading, causing bone resorption.\"}"
            },
            {
              "role": "user",
              "content": "Data Context:\n$enrichedContext\n\nUser Request:\n$userPrompt"
            }
          ],
          "response_format": {"type": "json_object"}
        });

        final response = await http.post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_apiKey',
          },
          body: body,
        ).timeout(const Duration(seconds: 20));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          String rawText = data['choices'][0]['message']['content'] ?? "{}";
          rawText = rawText.replaceAll('```json', '').replaceAll('```', '').trim();

          try {
            final jsonResponse = jsonDecode(rawText);
            return MedicalAssessment.fromJson(jsonResponse);
          } catch (e) {
            debugPrint("Failed to parse AI JSON: $rawText");
            return MedicalAssessment(
              assessment: "Error parsing AI response.",
              urgencyLevel: "Caution",
              immediateActions: ["Consult flight surgeon manual."],
              whyItMatters: ""
            );
          }
        }

        debugPrint("OPENROUTER API ERROR ($modelName): ${response.statusCode}");
        debugPrint("Details: ${response.body}");

        if (response.statusCode == 503 || response.statusCode == 429 || response.statusCode == 404) {
          continue;
        }

        return MedicalAssessment(assessment: "API Error: ${response.statusCode}", urgencyLevel: "Caution", immediateActions: [], whyItMatters: "");

      } catch (e) {
        debugPrint("AI HTTP Exception with $modelName: $e");
        if (modelName == _fallbackModels.last) {
          return MedicalAssessment(assessment: "Connection Error.", urgencyLevel: "Caution", immediateActions: [], whyItMatters: "");
        }
      }
    }
    return MedicalAssessment(assessment: "All AI models are busy.", urgencyLevel: "Normal", immediateActions: [], whyItMatters: "");
  }
}