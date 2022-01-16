import 'dart:async';

import '../tile_identity.dart';

import '../grid/slippy_map_translator.dart';
import 'tile_supplier.dart';

class ProviderTileSupplier extends TileSupplier {
  final TileProvider _provider;
  final SlippyMapTranslator _translator;

  ProviderTileSupplier(this._provider)
      : _translator = SlippyMapTranslator(_provider.maximumZoom);

  @override
  int get maximumZoom => _provider.maximumZoom;

  @override
  Stream<Tile> stream(TileRequest request) {
    TileIdentity tileId = request.tileId;
    if (tileId.z > maximumZoom) {
      tileId = _translator
          .specificZoomTranslation(request.tileId, zoom: maximumZoom)
          .translated;
    }

    final streamController = _StreamFutureState();
    // start retrieval right away for the tile that we want
    streamController.add(_provider.provide(tileId, request.primaryFormat));
    final secondaryFormat = request.secondaryFormat;
    if (secondaryFormat != null) {
      streamController.add(_provider.provide(tileId, secondaryFormat,
          zoom: request.tileId.z.toDouble()));
    }
    return streamController.stream;
  }
}

class _StreamFutureState {
  var _count = 0;
  // ignore: close_sinks
  final _controller = StreamController<Tile>();

  Stream<Tile> get stream => _controller.stream;

  void add(Future<Tile> future) {
    ++_count;
    future.then((value) {
      _controller.sink.add(value);
      _countDown();
    }).onError((error, stackTrace) {
      _controller.sink.addError(error ?? 'unknown', stackTrace);
      _countDown();
    });
  }

  void _countDown() {
    if (--_count == 0) {
      _controller.sink.close();
    }
  }
}

extension _FutureExtension<T> on Future<T> {
  Completer<T> toCompleter() {
    final completer = Completer<T>();
    then((value) => completer.complete(value)).onError((error, stackTrace) =>
        completer.completeError(error ?? 'error', stackTrace));
    return completer;
  }
}