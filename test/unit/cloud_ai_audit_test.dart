import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Zero Cloud AI & Privacy Audit Tests', () {
    test('pubspec.yaml contains NO cloud LLM SDK dependencies', () {
      final pubspecFile = File('pubspec.yaml');
      expect(pubspecFile.existsSync(), isTrue);

      final content = pubspecFile.readAsStringSync().toLowerCase();

      // Forbidden Cloud AI vendors & packages
      const forbiddenCloudSdks = [
        'google_generative_ai',
        'openai',
        'anthropic',
        'langchain',
        'groq',
        'together',
        'openrouter',
        'replicate',
        'huggingface_inference',
      ];

      for (final sdk in forbiddenCloudSdks) {
        expect(content.contains(sdk), isFalse,
            reason: 'pubspec.yaml must NOT contain cloud AI SDK: $sdk');
      }
    });

    test('lib directory contains NO cloud LLM endpoints or URLs', () {
      final libDir = Directory('lib');
      expect(libDir.existsSync(), isTrue);

      final files = libDir.listSync(recursive: true).whereType<File>();

      const forbiddenUrls = [
        'api.openai.com',
        'generativelanguage.googleapis.com',
        'api.anthropic.com',
        'api.groq.com',
        'openrouter.ai/api',
      ];

      for (final file in files) {
        if (!file.path.endsWith('.dart')) continue;
        final fileContent = file.readAsStringSync().toLowerCase();

        for (final url in forbiddenUrls) {
          expect(fileContent.contains(url), isFalse,
              reason: 'File ${file.path} must NOT contain cloud LLM endpoint: $url');
        }
      }
    });
  });
}
