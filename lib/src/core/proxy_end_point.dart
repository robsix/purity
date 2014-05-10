/**
 * Author:  Daniel Robinson http://github.com/0xor1
 */

part of purity.core;

/**
 * A down-stream [EndPoint] to route [Event]s from [Source]s to their proxies for re-emitting to any listening [Consumer]s.
 */
class ProxyEndPoint extends EndPoint{
  final InitConsumer _initConsumption;
  final Action _onConnectionClose;
  final Map<ObjectId, _Proxy> _proxies = new Map<ObjectId, _Proxy>();
  bool _proxyEventInProgress = false;
  
  ProxyEndPoint(this._initConsumption, this._onConnectionClose, EndPointConnection connection):
    super(connection){
  }
  
  void shutdown(){
    _onConnectionClose();
    super.shutdown();
  }
  
  void receiveString(String str){
    var tran = new Transmittable.fromTranString(str, _postprocessTran);
    if(tran is _Transmission){
      if(tran is _Ready){
        _initConsumption(tran._src, this);
      }else if(tran is _GarbageCollectionStart){
        _runGarbageCollectionSequence();
      }
    }else if(tran is Event){
      _proxyEventInProgress = true;
      _proxies[tran.emitter._purityId].emitEvent(tran).then((_){ _proxyEventInProgress = false; });
    }else{
      throw new UnsupportedMessageTypeError(reflect(tran).type.reflectedType);
    }
  }
  
  dynamic _postprocessTran(dynamic v){
    if(v is _Proxy){
      v._send = _sendTran;
      if(!_proxies.containsKey(v._purityId)){
        _proxies[v._purityId] = v;
      }
    }
    return v;
  }
  
  void _sendTran(Transmittable tran){
    _connection._send(tran.toTranString());
  }
  
  void _runGarbageCollectionSequence(){
    if(_proxyEventInProgress){
      new Future.delayed(new Duration(), _runGarbageCollectionSequence);
      return;
    }else{
      var proxiesCollected = new Set<_Proxy>();
      _proxies.forEach((purityId, proxy){
        if(proxy._usageCount == 0){
          _proxies.remove(purityId);
          proxiesCollected.add(proxy);
        }
      });
      _sendTran(new _GarbageCollectionReport().._proxies = proxiesCollected);
    }
  }
}