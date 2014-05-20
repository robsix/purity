/**
 * Author:  Daniel Robinson http://github.com/0xor1
 */

part of purity.core;

/**
 * An identifiable source of [Event]s.
 *
 * It is critical that all public methods on a [Source] always return void.
 * A [Source] should communicate internal state changes with other entities
 * solely by emitting [Event]s.
 */
class Source extends Base{
  InstanceMirror _this;

  Source():super(new ObjectId());

  void invoke(ProxyInvocation inv){
    if(_this == null){
      _this = reflect(this);
      _registerCoreRestrictedMethods();
    }
    if(_restrictedMethods.contains(inv.method) || MirrorSystem.getName(inv.method).startsWith('_')){
      throw new RestrictedMethodError(inv.method);
    }else{
      _this.invoke(inv.method, inv.posArgs, inv.namArgs);
    }
  }

  Future<Event> emitEvent(Transmittable data){
    data.lock();
    return super.emitEvent(data);
  }
}