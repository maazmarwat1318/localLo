import 'package:cloud_firestore/cloud_firestore.dart';

class FakeDoc extends DocumentSnapshot {
  @override
  String id;
  bool exist;
  bool hasData = false;
  FakeDoc({required this.exist, required this.id});

  @override
  operator [](Object field) {
    // TODO: implement []
  }

  @override
  Object? data() {
    // TODO: implement data
    throw UnimplementedError();
  }

  @override
  // TODO: implement exists
  bool get exists => exist;

  @override
  bool get hadData => hasData;

  @override
  get(Object field) {
    // TODO: implement get
    throw UnimplementedError();
  }

  @override
  // TODO: implement metadata
  SnapshotMetadata get metadata => throw UnimplementedError();

  @override
  // TODO: implement reference
  DocumentReference<Object?> get reference => throw UnimplementedError();
}
