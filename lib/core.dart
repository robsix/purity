/**
 * Author:  Daniel Robinson http://github.com/0xor1
 */

/// Contains the core Purity types to implement a single page web app
/// in the Purity pattern.
library purity.core;

import 'dart:mirrors';
import 'dart:async';
import 'package:bson/bson.dart' show ObjectId;
import 'package:emitters/emitters.dart';
import 'package:transmittable/transmittable.dart';
export 'package:emitters/emitters.dart';
export 'package:transmittable/transmittable.dart';

part 'src/core/source.dart';
part 'src/core/source_end_point.dart';
part 'src/core/proxy_end_point.dart';
part 'src/core/consumer.dart';
part 'src/core/end_point_connection.dart';
part 'src/core/end_point.dart';
part 'src/core/host.dart';

part 'src/core/tran/source_event.dart';
part 'src/core/tran/shutdown.dart';
part 'src/core/tran/end_point_message.dart';
part 'src/core/tran/proxy_invocation.dart';
part 'src/core/tran/transmission.dart';
part 'src/core/tran/source_ready.dart';
part 'src/core/tran/garbage_collection_report.dart';
part 'src/core/tran/garbage_collection_start.dart';

part 'src/core/error/unsupported_proxy_invocation_error.dart';
part 'src/core/error/invalid_init_source_return_type_error.dart';
part 'src/core/error/unsupported_message_type_error.dart';
part 'src/core/error/consumer_settings_already_initialised_error.dart';
part 'src/core/error/restricted_method_error.dart';

typedef void Action();
typedef void SendString(String str);
typedef void SendTran(Transmittable tran);
typedef dynamic SeedApplication(_EndPoint srcEndPoint);
typedef dynamic CloseSource(Source seed);
typedef void InitConsumer(Source proxy, _EndPoint proxyEndPoint);

const String PURITY_WEB_SOCKET_ROUTE_PATH = '/purity_socket';

bool _consumerSettingsInitialised = false;
InitConsumer _initConsumer;
Action _handleConnectionClose;

bool get consumerSettingsInitialised => _consumerSettingsInitialised;
InitConsumer get initConsumer => _initConsumer;
Action get hanleConnectionClose => _handleConnectionClose;

/**
 * Stores the [initConsumer] and [handleConnectionClose] to be called when the [SourceEndPoint] is ready,
 * and when the [EndPointConnection] to the [SourceEndPoint] is closed, respectively.
 *
 * Throws [ConsumerSettingsAlreadyInitialisedError] if called more than once.
 */
void initConsumerSettings(InitConsumer initConsumer, Action handleConnectionClose){
  if(_consumerSettingsInitialised){
    throw new ConsumerSettingsAlreadyInitialisedError();
  }
  _consumerSettingsInitialised = true;
  _initConsumer = initConsumer;
  _handleConnectionClose = handleConnectionClose;
}

/**
 * Clears the current set of consumer initialisation settings.
 *
 * This is only expected to be used in the unit testing of the purity.core library.
 */
void clearConsumerSettings(){
  _initConsumer = null;
  _handleConnectionClose = null;
  _consumerSettingsInitialised = false;
}

final Registrar _registerPurityCoreTranTypes = generateRegistrar(
    'purity.core', 'pc', [
    new TranRegistration.codec(Source, (Source p) => p._purityId.toHexString(), (String s) => new Source._proxy(new ObjectId.fromHexString(s))),
    new TranRegistration.subtype(_ProxyInvocation, () => new _ProxyInvocation()),
    new TranRegistration.subtype(_SourceReady, () => new _SourceReady()),
    new TranRegistration.subtype(_GarbageCollectionReport, () => new _GarbageCollectionReport()),
    new TranRegistration.subtype(_GarbageCollectionStart, () => new _GarbageCollectionStart()),
    new TranRegistration.subtype(Shutdown, () => new Shutdown()),
    new TranRegistration.subtype(EndPointMessage, () => new EndPointMessage()),
    new TranRegistration.subtype(_SourceEvent, () => new _SourceEvent())
  ]);