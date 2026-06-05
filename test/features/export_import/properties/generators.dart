import 'dart:convert';

import 'package:duasaku_app/features/export_import/domain/models/backup_metadata.dart';
import 'package:duasaku_app/features/export_import/domain/models/data_type.dart';
import 'package:glados/glados.dart';

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

/// Current schema version used across all property tests.
const currentSchemaVersion = 7;

/// All 11 required table keys in a valid DuaSaku backup.
const requiredTableKeys = [
  'wallets',
  'categories',
  'transactions',
  'budgets',
  'recurringTransactions',
  'recurringExecutionLogs',
  'goals',
  'goalDeposits',
  'budgetAlerts',
  'budgetAlertPreferences',
  'budgetAlertThresholdStatus',
];

// ---------------------------------------------------------------------------
// Helper Utilities
// ---------------------------------------------------------------------------

/// Generates a random non-empty alphanumeric string.
String randomString(Random rng, int length) {
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  return String.fromCharCodes(
    List.generate(length, (_) => chars.codeUnitAt(rng.nextInt(chars.length))),
  );
}

/// Generates a random ISO 8601 timestamp string.
String randomIso8601(Random rng) {
  final dt = DateTime(
    2020 + rng.nextInt(5),
    1 + rng.nextInt(12),
    1 + rng.nextInt(28),
    rng.nextInt(24),
    rng.nextInt(60),
    rng.nextInt(60),
  );
  return dt.toUtc().toIso8601String();
}

/// Generates a random semver string (e.g. "1.2.3").
String randomSemver(Random rng) {
  return '${rng.nextInt(5)}.${rng.nextInt(10)}.${rng.nextInt(20)}';
}

// ---------------------------------------------------------------------------
// Custom Glados Generators
// ---------------------------------------------------------------------------

/// Extension on [Any] to provide custom generators for export/import testing.
extension ExportImportGenerators on Any {
  // -------------------------------------------------------------------------
  // validDatabaseState
  // -------------------------------------------------------------------------

  /// Generates a `Map<String, List<Map<String, dynamic>>>` with consistent FK
  /// relationships across all 11 tables. Each record has an 'id' field.
  /// Transactions reference valid walletIds and categoryIds.
  Generator<Map<String, List<Map<String, dynamic>>>> get validDatabaseState {
    return simple(
      generate: (random, size) => _buildValidDatabaseState(random, size),
      shrink: (input) sync* {
        // Shrink by removing records from the largest table
        for (final key in requiredTableKeys) {
          final records = input[key]!;
          if (records.length > 1) {
            final shrunk = Map<String, List<Map<String, dynamic>>>.from(input);
            shrunk[key] = records.sublist(0, records.length - 1);
            // Ensure FK consistency after shrinking
            if (_isFkConsistent(shrunk)) {
              yield shrunk;
            }
          }
        }
      },
    );
  }

  // -------------------------------------------------------------------------
  // validBackupMetadata
  // -------------------------------------------------------------------------

  /// Generates a BackupMetadata with valid appVersion (semver), positive
  /// schemaVersion, ISO 8601 exportedAt, non-empty deviceId, exportedBy = 'duasaku'.
  Generator<BackupMetadata> get validBackupMetadata {
    return simple(
      generate: (random, size) {
        return BackupMetadata(
          appVersion: randomSemver(random),
          schemaVersion: currentSchemaVersion,
          exportedAt: randomIso8601(random),
          deviceId: randomString(random, 8 + random.nextInt(16)),
          exportedBy: 'duasaku',
        );
      },
      shrink: (input) sync* {
        // Shrink deviceId length
        if (input.deviceId.length > 1) {
          yield BackupMetadata(
            appVersion: input.appVersion,
            schemaVersion: input.schemaVersion,
            exportedAt: input.exportedAt,
            deviceId: input.deviceId.substring(0, input.deviceId.length - 1),
            exportedBy: 'duasaku',
          );
        }
      },
    );
  }

  // -------------------------------------------------------------------------
  // validDateRange
  // -------------------------------------------------------------------------

  /// Generates start/end DateTime pairs where start <= end.
  Generator<(DateTime, DateTime)> get validDateRange {
    return simple(
      generate: (random, size) {
        final start = DateTime(
          2020 + random.nextInt(4),
          1 + random.nextInt(12),
          1 + random.nextInt(28),
        );
        final daysToAdd = random.nextInt(365.clamp(1, size * 30 + 1));
        final end = start.add(Duration(days: daysToAdd));
        return (start, end);
      },
      shrink: (input) sync* {
        final (start, end) = input;
        final diff = end.difference(start).inDays;
        if (diff > 1) {
          yield (start, start.add(Duration(days: diff ~/ 2)));
        }
      },
    );
  }

  // -------------------------------------------------------------------------
  // randomDataTypeSubset
  // -------------------------------------------------------------------------

  /// Generates non-empty `Set<DataType>` subsets.
  Generator<Set<DataType>> get randomDataTypeSubset {
    return simple(
      generate: (random, size) {
        final allTypes = DataType.values.toList();
        final count = 1 + random.nextInt(allTypes.length);
        allTypes.shuffle(random);
        return allTypes.take(count).toSet();
      },
      shrink: (input) sync* {
        // Shrink by removing one element at a time (keep non-empty)
        if (input.length > 1) {
          for (final element in input) {
            yield Set<DataType>.from(input)..remove(element);
          }
        }
      },
    );
  }

  // -------------------------------------------------------------------------
  // malformedBackupJson
  // -------------------------------------------------------------------------

  /// Generates JSON strings that are either: not valid JSON, missing metadata,
  /// wrong exportedBy, metadata is not a Map, or exportedBy is null.
  Generator<String> get malformedBackupJson {
    return simple(
      generate: (random, size) => _buildMalformedBackupJson(random),
      shrink: (input) => [],
    );
  }

  // -------------------------------------------------------------------------
  // brokenFkBackup
  // -------------------------------------------------------------------------

  /// Generates valid backup structure but with intentionally broken FK references.
  Generator<Map<String, dynamic>> get brokenFkBackup {
    return simple(
      generate: (random, size) => _buildBrokenFkBackup(random, size),
      shrink: (input) => [],
    );
  }
}

// ---------------------------------------------------------------------------
// Internal Builder Functions
// ---------------------------------------------------------------------------

Map<String, List<Map<String, dynamic>>> _buildValidDatabaseState(
  Random rng,
  int size,
) {
  final walletCount = 1 + rng.nextInt((size ~/ 3).clamp(1, 5));
  final categoryCount = 1 + rng.nextInt((size ~/ 3).clamp(1, 6));

  final wallets = List.generate(walletCount, (i) {
    return {
      'id': 'w_${rng.nextInt(999999)}_$i',
      'name': 'Wallet ${randomString(rng, 4)}',
      'balance': (rng.nextDouble() * 10000000).toStringAsFixed(2),
      'createdAt': randomIso8601(rng),
    };
  });

  final categories = List.generate(categoryCount, (i) {
    return {
      'id': 'c_${rng.nextInt(999999)}_$i',
      'name': 'Category ${randomString(rng, 5)}',
      'type': rng.nextBool() ? 'income' : 'expense',
      'createdAt': randomIso8601(rng),
    };
  });

  final transactionCount = rng.nextInt((size ~/ 2).clamp(0, 6));
  final transactions = List.generate(transactionCount, (i) {
    return {
      'id': 't_${rng.nextInt(999999)}_$i',
      'walletId': wallets[rng.nextInt(wallets.length)]['id'],
      'categoryId': categories[rng.nextInt(categories.length)]['id'],
      'amount': (rng.nextDouble() * 1000000).toStringAsFixed(2),
      'date': randomIso8601(rng),
      'note': randomString(rng, rng.nextInt(20)),
    };
  });

  final budgetCount = rng.nextInt(3);
  final budgets = List.generate(budgetCount, (i) {
    return {
      'id': 'b_${rng.nextInt(999999)}_$i',
      'categoryId': categories[rng.nextInt(categories.length)]['id'],
      'amount': (rng.nextDouble() * 5000000).toStringAsFixed(2),
      'createdAt': randomIso8601(rng),
    };
  });

  final recurringCount = rng.nextInt(3);
  final recurringTransactions = List.generate(recurringCount, (i) {
    return {
      'id': 'rt_${rng.nextInt(999999)}_$i',
      'walletId': wallets[rng.nextInt(wallets.length)]['id'],
      'categoryId': categories[rng.nextInt(categories.length)]['id'],
      'amount': (rng.nextDouble() * 500000).toStringAsFixed(2),
      'createdAt': randomIso8601(rng),
    };
  });

  final recurringLogCount = recurringTransactions.isEmpty ? 0 : rng.nextInt(3);
  final recurringExecutionLogs = List.generate(recurringLogCount, (i) {
    return {
      'id': 'rel_${rng.nextInt(999999)}_$i',
      'recurringTransactionId':
          recurringTransactions[rng.nextInt(recurringTransactions.length)]['id'],
      'createdAt': randomIso8601(rng),
    };
  });

  final goalCount = rng.nextInt(3);
  final goals = List.generate(goalCount, (i) {
    return {
      'id': 'g_${rng.nextInt(999999)}_$i',
      'walletId': wallets[rng.nextInt(wallets.length)]['id'],
      'targetAmount': (rng.nextDouble() * 50000000).toStringAsFixed(2),
      'createdAt': randomIso8601(rng),
    };
  });

  final goalDepositCount = goals.isEmpty ? 0 : rng.nextInt(4);
  final goalDeposits = List.generate(goalDepositCount, (i) {
    return {
      'id': 'gd_${rng.nextInt(999999)}_$i',
      'goalId': goals[rng.nextInt(goals.length)]['id'],
      'amount': (rng.nextDouble() * 1000000).toStringAsFixed(2),
      'createdAt': randomIso8601(rng),
    };
  });

  final budgetAlertCount = rng.nextInt(3);
  final budgetAlerts = List.generate(budgetAlertCount, (i) {
    return {
      'id': 'ba_${rng.nextInt(999999)}_$i',
      'message': randomString(rng, 10),
      'createdAt': randomIso8601(rng),
    };
  });

  final budgetAlertPreferences = List.generate(rng.nextInt(2), (i) {
    return {
      'id': 'bap_${rng.nextInt(999999)}_$i',
      'isEnabled': rng.nextBool(),
      'createdAt': randomIso8601(rng),
    };
  });

  final budgetAlertThresholdStatus = List.generate(rng.nextInt(2), (i) {
    return {
      'id': 'bats_${rng.nextInt(999999)}_$i',
      'createdAt': randomIso8601(rng),
    };
  });

  return {
    'wallets': wallets,
    'categories': categories,
    'transactions': transactions,
    'budgets': budgets,
    'recurringTransactions': recurringTransactions,
    'recurringExecutionLogs': recurringExecutionLogs,
    'goals': goals,
    'goalDeposits': goalDeposits,
    'budgetAlerts': budgetAlerts,
    'budgetAlertPreferences': budgetAlertPreferences,
    'budgetAlertThresholdStatus': budgetAlertThresholdStatus,
  };
}

/// Checks FK consistency of a database state map.
bool _isFkConsistent(Map<String, List<Map<String, dynamic>>> state) {
  final walletIds = state['wallets']!.map((r) => r['id'].toString()).toSet();
  final categoryIds =
      state['categories']!.map((r) => r['id'].toString()).toSet();
  final rtIds =
      state['recurringTransactions']!.map((r) => r['id'].toString()).toSet();
  final goalIds = state['goals']!.map((r) => r['id'].toString()).toSet();

  for (final t in state['transactions']!) {
    if (t['walletId'] != null && !walletIds.contains(t['walletId'].toString())) {
      return false;
    }
    if (t['categoryId'] != null &&
        !categoryIds.contains(t['categoryId'].toString())) {
      return false;
    }
  }
  for (final b in state['budgets']!) {
    if (b['categoryId'] != null &&
        !categoryIds.contains(b['categoryId'].toString())) {
      return false;
    }
  }
  for (final rt in state['recurringTransactions']!) {
    if (rt['walletId'] != null &&
        !walletIds.contains(rt['walletId'].toString())) {
      return false;
    }
    if (rt['categoryId'] != null &&
        !categoryIds.contains(rt['categoryId'].toString())) {
      return false;
    }
  }
  for (final rel in state['recurringExecutionLogs']!) {
    if (rel['recurringTransactionId'] != null &&
        !rtIds.contains(rel['recurringTransactionId'].toString())) {
      return false;
    }
  }
  for (final g in state['goals']!) {
    if (g['walletId'] != null && !walletIds.contains(g['walletId'].toString())) {
      return false;
    }
  }
  for (final gd in state['goalDeposits']!) {
    if (gd['goalId'] != null && !goalIds.contains(gd['goalId'].toString())) {
      return false;
    }
  }
  return true;
}

String _buildMalformedBackupJson(Random rng) {
  final variant = rng.nextInt(6);

  switch (variant) {
    case 0:
      // Not valid JSON
      return '{invalid json content: [broken';
    case 1:
      // No metadata field at all
      return jsonEncode({
        'data': {'wallets': []},
      });
    case 2:
      // metadata exists but missing exportedBy
      return jsonEncode({
        'metadata': {
          'appVersion': '1.0.0',
          'schemaVersion': currentSchemaVersion,
          'exportedAt': randomIso8601(rng),
          'deviceId': randomString(rng, 8),
        },
        'data': {'wallets': []},
      });
    case 3:
      // exportedBy is not 'duasaku'
      return jsonEncode({
        'metadata': {
          'appVersion': '1.0.0',
          'schemaVersion': currentSchemaVersion,
          'exportedAt': randomIso8601(rng),
          'deviceId': randomString(rng, 8),
          'exportedBy': 'other_app_${rng.nextInt(100)}',
        },
        'data': {'wallets': []},
      });
    case 4:
      // metadata is not a Map
      return jsonEncode({
        'metadata': 'invalid_string',
        'data': {'wallets': []},
      });
    case 5:
      // metadata has exportedBy = null
      return jsonEncode({
        'metadata': {
          'appVersion': '1.0.0',
          'schemaVersion': currentSchemaVersion,
          'exportedAt': randomIso8601(rng),
          'deviceId': randomString(rng, 8),
          'exportedBy': null,
        },
        'data': {'wallets': []},
      });
    default:
      return '{}';
  }
}

Map<String, dynamic> _buildBrokenFkBackup(Random rng, int size) {
  // First build a valid state
  final dbState = _buildValidDatabaseState(rng, size);

  final metadata = {
    'appVersion': randomSemver(rng),
    'schemaVersion': currentSchemaVersion,
    'exportedAt': randomIso8601(rng),
    'deviceId': randomString(rng, 10),
    'exportedBy': 'duasaku',
  };

  // Ensure we have at least one wallet and category for valid base
  if (dbState['wallets']!.isEmpty) {
    dbState['wallets'] = [
      {
        'id': 'w_fallback',
        'name': 'Fallback',
        'balance': '0',
        'createdAt': randomIso8601(rng),
      }
    ];
  }
  if (dbState['categories']!.isEmpty) {
    dbState['categories'] = [
      {
        'id': 'c_fallback',
        'name': 'Fallback',
        'type': 'expense',
        'createdAt': randomIso8601(rng),
      }
    ];
  }

  // Choose which FK to break
  final breakVariant = rng.nextInt(4);

  switch (breakVariant) {
    case 0:
      // Break transaction → wallet FK
      final categoryId = dbState['categories']!.first['id'] as String;
      dbState['transactions'] = [
        ...dbState['transactions']!,
        {
          'id': 'broken_t_${rng.nextInt(99999)}',
          'walletId': 'nonexistent_wallet_${rng.nextInt(99999)}',
          'categoryId': categoryId,
          'amount': '1000',
          'date': randomIso8601(rng),
        },
      ];
      break;
    case 1:
      // Break transaction → category FK
      final walletId = dbState['wallets']!.first['id'] as String;
      dbState['transactions'] = [
        ...dbState['transactions']!,
        {
          'id': 'broken_t_${rng.nextInt(99999)}',
          'walletId': walletId,
          'categoryId': 'nonexistent_category_${rng.nextInt(99999)}',
          'amount': '2000',
          'date': randomIso8601(rng),
        },
      ];
      break;
    case 2:
      // Break goal → wallet FK
      dbState['goals'] = [
        ...dbState['goals']!,
        {
          'id': 'broken_g_${rng.nextInt(99999)}',
          'walletId': 'nonexistent_wallet_${rng.nextInt(99999)}',
          'createdAt': randomIso8601(rng),
        },
      ];
      break;
    case 3:
      // Break goalDeposit → goal FK
      if (dbState['goals']!.isEmpty) {
        final walletId = dbState['wallets']!.first['id'] as String;
        dbState['goals'] = [
          {
            'id': 'g_fallback_${rng.nextInt(99999)}',
            'walletId': walletId,
            'createdAt': randomIso8601(rng),
          }
        ];
      }
      dbState['goalDeposits'] = [
        ...dbState['goalDeposits']!,
        {
          'id': 'broken_gd_${rng.nextInt(99999)}',
          'goalId': 'nonexistent_goal_${rng.nextInt(99999)}',
          'createdAt': randomIso8601(rng),
        },
      ];
      break;
  }

  return {
    'metadata': metadata,
    'data': dbState,
  };
}
