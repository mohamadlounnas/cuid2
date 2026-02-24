import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cuid2/src/cuid2_base.dart';
import 'package:pointycastle/digests/sha3.dart';

import './fp_native.dart' if (dart.library.html) './fp_web.dart' as fp_native;

/// Adapted from https://github.com/juanelas/bigint-conversion
/// MIT License Copyright (c) 2018 Juan Hernández Serrano
BigInt bufToBigInt(Uint8List buf) {
  final bits = 8;

  BigInt value = BigInt.zero;
  for (final i in buf) {
    final bi = BigInt.from(i);
    value = (value << bits) + bi;
  }
  return value;
}

int Function() createCounter(int count) => () => count++;

String createEntropy(double Function() random, {int length = 4}) {
  String entropy = "";

  while (entropy.length < length) {
    entropy = "$entropy${(random() * 36).floor().toRadixString(36)}";
  }

  return entropy;
}

String createFingerprint({String? environment, double Function()? random}) {
  random ??= createRandom();
  final fingerprint =
      '${environment ?? fp_native.createFingerprint()}${createEntropy(random, length: Cuid.maxLength)}';
  return hash(fingerprint).substring(0, Cuid.maxLength);
}

double Function() createRandom({bool throwIfInsecure = false}) {
  Random random;

  try {
    random = Random.secure();
  } on UnsupportedError {
    if (throwIfInsecure) rethrow;
    print(
        "`Random.secure()` is not supported on this platform. Falling back to cryptographically insecure `Random()`.");
    random = Random();
  }

  return () => random.nextDouble();
}

String hash([String input = ""]) {
  final d = SHA3Digest(512);
  final sha3 = d.process(utf8.encode(input));

  // Drop the first character because it will bias the histogram
  // to the left.
  return bufToBigInt(sha3).toRadixString(36).substring(1);
}
