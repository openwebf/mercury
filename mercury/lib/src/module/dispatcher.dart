import 'package:mercury/mercury.dart';

class MercuryDispatcher extends EventTarget {
  Map<String, List<Function(List<dynamic>)>> _subscribed = {};

  MercuryDispatcher(BindingContext? context) : super(context);

  @override
  EventTarget? get parentEventTarget {
    return null;
  }

  @override
  void initializeMethods(Map<String, BindingObjectMethod> methods) {
    methods['dispatchToDart'] = BindingObjectMethodSync(call: (args) {
      assert(args[0] is String);
      _subscribed[args[0]]?.forEach((func) { func(args[1]); });
      return true;
    });
  }

  @override
  void initializeProperties(Map<String, BindingObjectProperty> properties) {
  }

  void subscribe(String event, Function(List<dynamic>) func) {
    _subscribed[event] ??= [];

    _subscribed[event]!.add(func);
  }
}
