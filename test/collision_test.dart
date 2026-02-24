import 'dart:async';
import 'dart:isolate';

import 'package:test/test.dart';
import './utils.dart';

void isolateWorker(SendPort dataToMainPort) async {
  final dataFromMainPort = ReceivePort();
  dataToMainPort.send(dataFromMainPort.sendPort);

  int? max;
  await for (final data in dataFromMainPort) {
    if (data is int) {
      max = data;
    }

    if (max != null) {
      break;
    }
  }

  final result = createIdPool(max: max!);
  dataToMainPort.send(result);

  dataFromMainPort.close();
}

Future<Map<String, String>> createIdPoolInIsolate(int max) async {
  final dataFromIsolatePort = ReceivePort();

  await Isolate.spawn<SendPort>(
    isolateWorker,
    dataFromIsolatePort.sendPort,
  );

  final dataToIsolatePortCompleter = Completer<SendPort>();
  final resultCompleter = Completer<Map<String, String>>();

  dataFromIsolatePort.listen((message) {
    if (message is SendPort) {
      dataToIsolatePortCompleter.complete(message);
    } else {
      resultCompleter.complete(message);
    }
  });

  final dataToIsolatePort = await dataToIsolatePortCompleter.future;
  dataToIsolatePort.send(max);

  final result = await resultCompleter.future;

  dataFromIsolatePort.close();

  return result;
}

Future<List<Map<String, String>>> createIdPoolsInIsolates(
    int numOfIsolates, int max) {
  return Future.wait(
      List.generate(numOfIsolates, (_) => createIdPoolInIsolate(max)));
}

void main() async {
  const numPools = 7;
  int n = (300000 / numPools).ceil() * numPools;
  info('Testing $n unique IDs...');
  final pools = await createIdPoolsInIsolates(numPools, (n / numPools).ceil());
  final ids = pools
      .map((x) => x['ids']!)
      .expand((element) => element.split(':'))
      .toList();
  final sampleIds = ids.take(10);
  final set = Set.from(ids);
  final histogram = pools[0]['histogram']!.split(':').map(int.parse);
  info('sample ids: $sampleIds');
  info('histogram: $histogram');
  final expectedBinSize = (n / numPools / histogram.length).ceil();
  const tolerance = 0.05;
  final minBinSize = (expectedBinSize * (1 - tolerance)).round();
  final maxBinSize = (expectedBinSize * (1 + tolerance)).round();
  info('expectedBinSize: $expectedBinSize');
  info('minBinSize: $minBinSize');
  info('maxBinSize: $maxBinSize');

  test('given lots of ids generated, should generate no collisions', () {
    expect(set.length, equals(n));
  });

  test(
      'given lots of ids generated, should produce a histogram within distribution tolerance',
      () {
    expect(histogram, everyElement((x) => x > minBinSize && x < maxBinSize));
  });

  test('given lots of ids generated, should contain only valid characters', () {
    final pattern = RegExp(r'^[a-z0-9]+$');
    expect(ids, everyElement((id) => pattern.hasMatch(id)));
  });
}
