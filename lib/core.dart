/**
 * Author:  Daniel Robinson http://github.com/0xor1
 */

library purity.core;

import 'dart:mirrors';
import 'dart:async';
import 'package:bson/bson.dart' show ObjectId;
import 'package:eventable/eventable.dart';
import 'package:transmittable/transmittable.dart';
export 'package:eventable/eventable.dart';
export 'package:transmittable/transmittable.dart';

part 'src/core/base.dart';
part 'src/core/source.dart';
part 'src/core/source_end_point.dart';
part 'src/core/proxy.dart';
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
part 'src/core/error/unsupported_message_type_error.dart';
part 'src/core/error/consumer_settings_already_initialised_error.dart';
part 'src/core/error/end_point_already_open_error.dart';
part 'src/core/error/restricted_method_error.dart';

typedef void Action();
typedef void SendString(String str);
typedef void SendTran(Transmittable tran);
typedef Future<Source> InitSource(EndPoint srcEndPoint);
typedef Future CloseSource(Source src);
typedef void InitConsumer(Proxy proxy, EndPoint proxyEndPoint);

const String PURITY_WEB_SOCKET_ROUTE_PATH = '/purity_socket';

Set<Symbol> _restrictedMethods = new Set<Symbol>();

/**
 * adds methods to a restricted access list preventing those methods from being called
 * remotely over an [EndPointConnection].
 */
void registerRestrictedMethods(Iterable<Symbol> toRestrict){
  _restrictedMethods.addAll(toRestrict);
}

bool _coreRestrictedMethodsRegistered = false;
void _registerCoreRestrictedMethods(){
  if(_coreRestrictedMethodsRegistered){ return; }
  _coreRestrictedMethodsRegistered = true;
  registerRestrictedMethods(reflectClass(EventDetector).instanceMembers.keys);
  registerRestrictedMethods(reflectClass(EventEmitter).instanceMembers.keys);
  registerRestrictedMethods(reflectClass(Source).instanceMembers.keys);
}

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

bool _purityCoreTranTypesRegistered = false;
void _registerPurityCoreTranTypes(){
  if(_purityCoreTranTypesRegistered){ return; }
  _purityCoreTranTypesRegistered = true;
  registerTranTypes('purity.core', 'pc', (){
    registerTranCodec('a', Proxy, (Proxy p) => p.purityId.toHexString(), (String s) => new Proxy(new ObjectId.fromHexString(s)));
    registerTranSubtype('b', ProxyInvocation);
    registerTranSubtype('d', SourceReady);
    registerTranSubtype('e', GarbageCollectionReport);
    registerTranSubtype('f', GarbageCollectionStart);
    registerTranSubtype('g', Shutdown);
    registerTranSubtype('h', EndPointMessage);
    registerTranSubtype('i', SourceEvent);
  });
}