import 'package:flutter/foundation.dart';
import 'package:google_mlkit_entity_extraction/google_mlkit_entity_extraction.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import '../core/utils/local_date_parser.dart';

/// Abstract service interface for On-Device Machine Learning operations.
abstract class SmartInputMlService {
  /// Initiates dynamic downloads of language translation and entity extraction models
  /// in the background without blocking the UI.
  Future<void> initializeSilently();

  /// Translates Indonesian text to English and extracts the date/time entities.
  /// Falls back to null on failure.
  Future<DateTime?> extractDateTime(String text, {DateTime? referenceDate});

  /// Closes active translation and extraction engines.
  Future<void> close();
}

/// Concrete implementation of [SmartInputMlService] using Google ML Kit.
class SmartInputMlServiceImpl implements SmartInputMlService {
  OnDeviceTranslator? _translatorIdEn;
  EntityExtractor? _entityExtractor;
  bool _initialized = false;

  @override
  Future<void> initializeSilently() async {
    if (_initialized) return;

    try {
      final translationModelManager = OnDeviceTranslatorModelManager();
      final entityModelManager = EntityExtractorModelManager();

      // Check if models are already downloaded
      final hasIndoModel = await translationModelManager.isModelDownloaded(
        TranslateLanguage.indonesian.bcpCode,
      );
      final hasEngModel = await translationModelManager.isModelDownloaded(
        TranslateLanguage.english.bcpCode,
      );
      final hasEntityModel = await entityModelManager.isModelDownloaded(
        EntityExtractorLanguage.english.name,
      );

      // Start asynchronous background downloads (without awaiting) for models not present
      if (!hasIndoModel) {
        debugPrint(
          '[SmartInputMlService] Starting background download for Indonesian translation model...',
        );
        translationModelManager.downloadModel(
          TranslateLanguage.indonesian.bcpCode,
        );
      }
      if (!hasEngModel) {
        debugPrint(
          '[SmartInputMlService] Starting background download for English translation model...',
        );
        translationModelManager.downloadModel(
          TranslateLanguage.english.bcpCode,
        );
      }
      if (!hasEntityModel) {
        debugPrint(
          '[SmartInputMlService] Starting background download for English Entity Extraction model...',
        );
        entityModelManager.downloadModel(EntityExtractorLanguage.english.name);
      }

      // Initialize engines immediately if models are ready, or lazy load later in parsing
      if (hasIndoModel && hasEngModel) {
        _translatorIdEn = OnDeviceTranslator(
          sourceLanguage: TranslateLanguage.indonesian,
          targetLanguage: TranslateLanguage.english,
        );
      }

      if (hasEntityModel) {
        _entityExtractor = EntityExtractor(
          language: EntityExtractorLanguage.english,
        );
      }

      _initialized = true;
      debugPrint(
        '[SmartInputMlService] Background initialization triggered successfully.',
      );
    } catch (e) {
      debugPrint(
        '[SmartInputMlService] Error triggering silent initialization: $e',
      );
    }
  }

  /// Lazy initializations of engines if they are not already instantiated but the models are downloaded.
  Future<bool> _ensureEnginesReady() async {
    if (_translatorIdEn != null && _entityExtractor != null) return true;

    try {
      final translationModelManager = OnDeviceTranslatorModelManager();
      final entityModelManager = EntityExtractorModelManager();

      final hasIndoModel = await translationModelManager.isModelDownloaded(
        TranslateLanguage.indonesian.bcpCode,
      );
      final hasEngModel = await translationModelManager.isModelDownloaded(
        TranslateLanguage.english.bcpCode,
      );
      final hasEntityModel = await entityModelManager.isModelDownloaded(
        EntityExtractorLanguage.english.name,
      );

      if (hasIndoModel && hasEngModel && _translatorIdEn == null) {
        _translatorIdEn = OnDeviceTranslator(
          sourceLanguage: TranslateLanguage.indonesian,
          targetLanguage: TranslateLanguage.english,
        );
      }

      if (hasEntityModel && _entityExtractor == null) {
        _entityExtractor = EntityExtractor(
          language: EntityExtractorLanguage.english,
        );
      }
    } catch (e) {
      debugPrint('[SmartInputMlService] Error instantiating ML engines: $e');
    }

    return _translatorIdEn != null && _entityExtractor != null;
  }

  @override
  Future<DateTime?> extractDateTime(
    String text, {
    DateTime? referenceDate,
  }) async {
    if (text.trim().isEmpty) return null;

    final localParsed = LocalDateParser.parse(
      text,
      referenceDate: referenceDate,
    );
    if (localParsed != null) {
      return localParsed;
    }

    try {
      final ready = await _ensureEnginesReady();
      if (!ready) {
        debugPrint(
          '[SmartInputMlService] ML Kit models are not fully downloaded/ready yet.',
        );
        return null;
      }

      // 1. Translate Indonesian input text to English
      final String englishText = await _translatorIdEn!.translateText(text);
      if (englishText.trim().isEmpty) return null;

      // 2. Perform entity extraction on English translation
      final ref = referenceDate ?? DateTime.now();
      final List<EntityAnnotation> annotations = await _entityExtractor!
          .annotateText(englishText, referenceTime: ref.millisecondsSinceEpoch);

      // 3. Find the first DateTimeEntity
      for (final annotation in annotations) {
        for (final entity in annotation.entities) {
          if (entity is DateTimeEntity) {
            return DateTime.fromMillisecondsSinceEpoch(entity.timestamp);
          }
        }
      }
    } catch (e) {
      debugPrint(
        '[SmartInputMlService] Error parsing date/time via ML Kit: $e',
      );
    }

    return null;
  }

  @override
  Future<void> close() async {
    try {
      await _translatorIdEn?.close();
      await _entityExtractor?.close();
      _translatorIdEn = null;
      _entityExtractor = null;
      _initialized = false;
    } catch (e) {
      debugPrint('[SmartInputMlService] Error during close: $e');
    }
  }
}
