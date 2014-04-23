/**
 * author: Daniel Robinson  http://github.com/0xor1
 */

part of purity.internal;

class PurityAppSession extends PurityModel{
  final String name;
  final PurityModel _appModel;
  final CloseApp _closeApp;
  final Stream<String> _incoming;
  final SendString _sendString;
  final List<Transmittable> _messageQueue = new List<Transmittable>();
  final Map<ObjectId, PurityModel> _models = new Map<ObjectId, PurityModel>();
  final int _garbageCollectionFrequency; //in seconds
  bool _garbageCollectionInProgress = false;
  Timer _garbageCollectionTimer;

  PurityAppSession(String this.name, PurityModel this._appModel, CloseApp this._closeApp, Stream<String> this._incoming, SendString this._sendString, int this._garbageCollectionFrequency){
    _setGarbageCollectionTimer();
    var shutdownSession = (){ 
      ignoreAllEvents();
      if(_garbageCollectionTimer != null){
        _garbageCollectionTimer.cancel();
      }
      _closeApp(_appModel); };
    _incoming.listen(_receiveString, onDone: shutdownSession, onError: (error) => shutdownSession());
    _sendTran(
      new PurityAppSessionInitialisedTransmission()
      ..model = _appModel);
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
      throw new PurityUnsupportedMessageTypeError(tran.runtimeType);
    }
  }
  
  void _sendTran(Transmittable tran){
    _sendString(tran.toTranString(_preprocessTran));
  }

  void _setGarbageCollectionTimer(){
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
    _garbageCollectionInProgress = false;
    _setGarbageCollectionTimer();
  }
}