/**
 * Author:  Daniel Robinson http://github.com/0xor1
 */

part of purity.core;

/**
 * An end-point for an [EndPointConnection].
 */
abstract class EndPoint extends Source{
  
  final EndPointConnection _connection;
  
  /// Constructs a new [EndPoint] instance with the supplied [EndPointConnection].
  EndPoint(this._connection){
    _registerPurityCoreTranTypes();
    _connection._incoming.listen(receiveString, onDone: shutdown, onError: (error) => shutdown());
  }
  
  /// shuts down the [EndPointConnection].
  void shutdown(){
    _connection._close();
    emitEvent(
      new ShutdownEvent());
  }
  
  void receiveString(String str);
}