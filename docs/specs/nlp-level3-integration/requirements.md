# Requirements Document: Level 3 Joint NLP Model Integration

## Introduction
This specification outlines the integration of the Level 3 Joint NLP model (covering Intent Classification, Category Classification, and Named Entity Recognition (NER)) into the DuaSaku app. 
The system operates completely on-device using a TensorFlow Lite (`.tflite`) model and client-side tokenization implemented in pure Dart.

## Functional Requirements

### 1. Asset Delivery and Declaration
- **Req 1.1**: The Level 3 model file (`duasaku_level3.tflite`) and its config (`metadata.json`) MUST be located in the `assets/ml/` directory.
- **Req 1.2**: The `pubspec.yaml` MUST declare the assets folder `assets/ml/` so they are bundled with the application.

### 2. Client-Side Tokenization
- **Req 2.1**: The tokenization pipeline MUST run locally and synchronously on the device.
- **Req 2.2**: The tokenizer MUST lower-case all inputs.
- **Req 2.3**: The tokenizer MUST strip punctuation exactly matching Keras's standard: `[!"#$%&'()*+,-./:;<=>?@[\]^_`{|}~]`.
- **Req 2.4**: The tokenizer MUST map words to integer IDs using the vocabulary list stored in `metadata.json`.
- **Req 2.5**: Unknown words MUST map to the ID of the `[UNK]` token dynamically retrieved from the vocabulary map, falling back to 1.
- **Req 2.6**: Sequences MUST be padded or truncated to a fixed `max_len` (from metadata, which is 10) using 0 for padding.

### 3. Joint Intent, Category, and NER Inference (TFLite)
- **Req 3.1**: The parser MUST load the `.tflite` model using the `tflite_flutter` package.
- **Req 3.2**: The model inference input MUST have the shape `[1, max_len]` of `int32`.
- **Req 3.3**: The inference MUST yield three outputs:
  - **Intent**: Output shape `[1, 1]` containing sigmoid probability (probability > 0.5 is Income, <= 0.5 is Expense).
  - **Category**: Output shape `[1, num_categories]` containing probability scores.
  - **NER**: Output shape `[1, max_len, num_ner_tags]` containing probability distribution of tags per token.
- **Req 3.4**: The output decoding MUST resolve the tags as follows:
  - Argmax over Category scores to find the predicted category index, mapped to category names using `category_map` in `metadata.json`.
  - Argmax over NER scores at each position to identify the tag (e.g., `B-AMOUNT`, `I-AMOUNT`, `B-NOTE`, `I-NOTE`, `O`, `PAD`).
  - Extracted Amount tokens (under `B-AMOUNT` or `I-AMOUNT`) and Notes tokens (under `B-NOTE` or `I-NOTE`) MUST be reconstructed from raw input tokens (split by whitespace before punctuation stripping) to preserve decimal markers (dots/commas).
  - The extracted amount string MUST be parsed into a `double`. If parsing fails, it defaults to 0.0.
  - The final parsed transaction details MUST be mapped to a standard `ParsedTransaction` model.

### 4. Integration & Fallbacks
- **Req 4.1**: `TfliteTransactionParserService` MUST implement the `TransactionParserServiceInterface` to allow seamless swapping.
- **Req 4.2**: The Riverpod provider `transactionParserServiceProvider` MUST be updated to inject `TfliteTransactionParserService` into the application.
