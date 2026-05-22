import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mesh_rag_demo/services/retrieval_service.dart';

void main() {
  group('RetrievalService cosine math', () {
    test('normalize returns unit-length vector', () {
      final v = Float32List.fromList([3, 0, 4]);
      final n = RetrievalService.normalize(v);
      // length 5 → divides to [0.6, 0, 0.8]
      expect(n[0], closeTo(0.6, 1e-6));
      expect(n[1], closeTo(0.0, 1e-6));
      expect(n[2], closeTo(0.8, 1e-6));
    });

    test('normalize is identity on a zero vector', () {
      final v = Float32List.fromList([0, 0, 0]);
      final n = RetrievalService.normalize(v);
      expect(n[0], equals(0.0));
      expect(n[1], equals(0.0));
      expect(n[2], equals(0.0));
    });

    test('dot of normalized vectors = cosine similarity', () {
      final a = RetrievalService.normalize(Float32List.fromList([1, 0]));
      final b = RetrievalService.normalize(Float32List.fromList([1, 0]));
      expect(RetrievalService.dot(a, b), closeTo(1.0, 1e-6));

      final c = RetrievalService.normalize(Float32List.fromList([0, 1]));
      expect(RetrievalService.dot(a, c), closeTo(0.0, 1e-6));

      final d = RetrievalService.normalize(Float32List.fromList([-1, 0]));
      expect(RetrievalService.dot(a, d), closeTo(-1.0, 1e-6));
    });

    test('dot survives a 384-dim sanity case', () {
      final a = Float32List(384);
      final b = Float32List(384);
      for (var i = 0; i < 384; i++) {
        a[i] = (i % 2 == 0) ? 1.0 : 0.0;
        b[i] = (i % 2 == 0) ? 1.0 : 0.0;
      }
      final an = RetrievalService.normalize(a);
      final bn = RetrievalService.normalize(b);
      expect(RetrievalService.dot(an, bn), closeTo(1.0, 1e-5));
    });
  });
}
