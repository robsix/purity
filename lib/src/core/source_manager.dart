/**
 * author: Daniel Robinson  http://github.com/0xor1
 */

part of purity.core;

class SourceManager extends Source implements IManager{
  final Fn_PurityEventSourceManager_PurityEventSource ;
  final CloseApp _closeApp;
  final BiConnection _connection;
  final List<Transmittable> _messageQueue = new List<Transmittable>();
  final Map<ObjectId, PurityModel> _models = new Map<ObjectId, PurityModel>();
  final int _garbageCollectionFrequency; //in seconds
  bool _garbageCollectionInProgress = false;
  Timer _garbageCollectionTimer;

  SourceManager(this._appModel, this._closeApp, this._connection, this._garbageCollectionFrequency){
    _registerPurityTranTypes();
    _setGarbageCollectionTimer();
    _incoming.listen(_receiveString, onDone: shutdown, onError: (error) => shutdown());
    _sendTran(
      new PurityAppSessionInitialisedTransmission()
      ..model = _appModel);
  }
  
  void shutdown(){
    ignoreAllEvents();
    if(_garbageCollectionTimer != null){
      _garbageCollectionTimer.cancel();
    }
    _closeApp(_appModel);
    _closeStream();
    emitEvent(new PurityAppSessionShutdownEvent());
  }

  dynamic _preprocessTran(dynamic v){
    if(v is PurityModel){
      if(!_models.containsKey(v._purityId)){
        _models[v._purityId] = v;
        listen(v, Omni, (PurityEvent e){
          if(_garbageCollectionInProgress){
            _messageQueue.add(e);
          }else{
            _sendTran(e);
          }
        });
      }
      return new PurityClientModel(v._purityId);
    }
    return v;
  }

  void _receiveString(String str){
    var tran = new Transmittable.fromTranString(str);
    if(tran is PurityGarbageCollectionReportTransmission){
      _runGarbageCollectionSequence(tran.models);
    }else if(tran is PurityInvocationTransmission){
      var modelMirror = reflect(_models[(tran.model as PurityModelBase)._purityId]);
      modelMirror.invoke(tran.method, tran.posArgs, tran.namArgs);
    }else{
      throw new UnsupportedMessageTypeError(reflect(tran).type.reflectedType);
    }
  }
  
  void _sendTran(Transmittable tran){
    _sendString(tran.toTranString(_preprocessTran));
  }

  void _setGarbageCollectionTimer(){
    if(_garbageCollectionTimer != null){
      _garbageCollectionTimer.cancel();
    }
    _garbageCollectionInProgress = false;
    if(_garbageCollectionFrequency == 0 || _garbageCollectionFrequency == null){
      return;
    }
    _garbageCollectionTimer = new Timer(new Duration(seconds: _garbageCollectionFrequency), (){
      _garbageCollectionInProgress = true;
      _sendTran(new PurityGarbageCollectionStartTransmission());
    });
  }
  
  void _runGarbageCollectionSequence(Set<PurityModelBase> models){
    models.forEach((model){
      _models.remove(model._purityId);
    });
    for(var i = 0; i < _messageQueue.length; i++){
      _sendTran(_messageQueue[i]);
    }
    _messageQueue.clear();
    _setGarbageCollectionTimer();
  }
}