import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeDataSnapshot extends Fake implements DataSnapshot {
  final Object? _val;
  FakeDataSnapshot(this._val);

  @override
  Object? get value => _val;

  @override
  bool get exists => _val != null;

  @override
  bool hasChild(String path) {
    if (_val is! Map) return false;
    return child(path).exists;
  }

  @override
  DataSnapshot child(String path) {
    if (_val is! Map) return FakeDataSnapshot(null);
    final parts = path.split('/').where((p) => p.isNotEmpty);
    Object? current = _val;
    for (final p in parts) {
      if (current is Map) {
        current = current[p];
      } else {
        return FakeDataSnapshot(null);
      }
    }
    return FakeDataSnapshot(current);
  }
}

class FakeTransactionResult extends Fake implements TransactionResult {
  @override
  final bool committed;
  @override
  final DataSnapshot snapshot;

  FakeTransactionResult({required this.committed, required this.snapshot});
}

class FakeOnDisconnect extends Fake implements OnDisconnect {
  @override
  Future<void> cancel() async {}
  @override
  Future<void> remove() async {}
  @override
  Future<void> set(Object? value) async {}
  @override
  Future<void> update(Map<String, Object?> value) async {}
}

class FakeDatabaseStore {
  final Map<String, dynamic> _root = {};
  Future<void> _lock = Future.value();

  Object? get(String path) {
    final parts = path.split('/').where((p) => p.isNotEmpty);
    Object? current = _root;
    for (final p in parts) {
      if (current is Map) {
        current = current[p];
      } else {
        return null;
      }
    }
    return current;
  }

  void set(String path, Object? value) {
    final parts = path.split('/').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return;
    Map<String, dynamic> current = _root;
    for (var i = 0; i < parts.length - 1; i++) {
      final p = parts[i];
      if (!current.containsKey(p) || current[p] is! Map) {
        current[p] = <String, dynamic>{};
      }
      current = current[p] as Map<String, dynamic>;
    }
    if (value == null) {
      current.remove(parts.last);
    } else {
      current[parts.last] = _deepCopy(value);
    }
  }

  void update(String path, Map<String, Object?> values) {
    final parts = path.split('/').where((p) => p.isNotEmpty).toList();
    Map<String, dynamic> current = _root;
    for (final p in parts) {
      if (!current.containsKey(p) || current[p] is! Map) {
        current[p] = <String, dynamic>{};
      }
      current = current[p] as Map<String, dynamic>;
    }
    for (final entry in values.entries) {
      if (entry.key.contains('/')) {
        set('$path/${entry.key}', entry.value);
      } else {
        if (entry.value == null) {
          current.remove(entry.key);
        } else {
          current[entry.key] = _deepCopy(entry.value);
        }
      }
    }
  }

  Future<TransactionResult> runTransaction(
    String path,
    TransactionHandler handler,
  ) async {
    // 1. Initial local evaluation before lock (matches RTDB client local run)
    final initialSnapshot = _deepCopy(get(path));
    final initialResult = handler(initialSnapshot);
    if (initialResult.aborted) {
      return FakeTransactionResult(
        committed: false,
        snapshot: FakeDataSnapshot(initialSnapshot),
      );
    }

    // 2. Lock for server-side commit / conflict resolution
    final prev = _lock;
    final completer = Completer<void>();
    _lock = completer.future;

    try {
      await prev;
      final currentData = _deepCopy(get(path));
      if (!_deepEquals(initialSnapshot, currentData)) {
        // Concurrently modified: re-evaluate handler against latest server data
        final retryResult = handler(currentData);
        if (retryResult.aborted) {
          return FakeTransactionResult(
            committed: false,
            snapshot: FakeDataSnapshot(currentData),
          );
        }
        set(path, retryResult.value);
        return FakeTransactionResult(
          committed: true,
          snapshot: FakeDataSnapshot(retryResult.value),
        );
      }

      set(path, initialResult.value);
      return FakeTransactionResult(
        committed: true,
        snapshot: FakeDataSnapshot(initialResult.value),
      );
    } finally {
      completer.complete();
    }
  }

  static bool _deepEquals(dynamic a, dynamic b) {
    if (identical(a, b)) return true;
    if (a is Map && b is Map) {
      if (a.length != b.length) return false;
      for (final key in a.keys) {
        if (!b.containsKey(key) || !_deepEquals(a[key], b[key])) return false;
      }
      return true;
    }
    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (var i = 0; i < a.length; i++) {
        if (!_deepEquals(a[i], b[i])) return false;
      }
      return true;
    }
    return a == b;
  }

  static dynamic _deepCopy(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(
        value.map((k, v) => MapEntry(k.toString(), _deepCopy(v))),
      );
    }
    if (value is List) {
      return value.map(_deepCopy).toList();
    }
    return value;
  }
}

class FakeDatabaseReference extends Fake implements DatabaseReference {
  @override
  final String path;
  final FakeDatabaseStore store;

  FakeDatabaseReference(this.path, this.store);

  @override
  DatabaseReference child(String pathString) {
    final cleanChild = pathString.startsWith('/') ? pathString.substring(1) : pathString;
    final newPath = path.isEmpty ? cleanChild : '$path/$cleanChild';
    return FakeDatabaseReference(newPath, store);
  }

  @override
  Future<DataSnapshot> get() async {
    return FakeDataSnapshot(store.get(path));
  }

  @override
  Future<void> set(Object? value) async {
    store.set(path, value);
  }

  @override
  Future<void> update(Map<String, Object?> value) async {
    store.update(path, value);
  }

  @override
  OnDisconnect onDisconnect() => FakeOnDisconnect();

  @override
  Future<TransactionResult> runTransaction(
    TransactionHandler transactionHandler, {
    bool applyLocally = true,
  }) async {
    return store.runTransaction(path, transactionHandler);
  }
}

class FakeFirebaseDatabase extends Fake implements FirebaseDatabase {
  final store = FakeDatabaseStore();

  @override
  DatabaseReference ref([String? path]) {
    return FakeDatabaseReference(path ?? '', store);
  }
}
