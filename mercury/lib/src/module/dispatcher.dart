import 'package:mercury/mercury.dart';

class MercuryDispatcher extends EventTarget {
  Map<String, List<Function(String data)>> subscribed = {};

  MercuryDispatcher(BindingContext? context) : super(context);

  @override
  EventTarget? get parentEventTarget {
    return null;
  }

  @override
  void initializeMethods(Map<String, BindingObjectMethod> methods) {
    methods['dispatchToDart'] = BindingObjectMethodSync(call: (args) {
      print('called from js: $args');
      // subscribed[args[0]]?.forEach((func) { func(args[1]); });
      return true;
    });
  }

  @override
  void initializeProperties(Map<String, BindingObjectProperty> properties) {
  }

  void subscribe(String event, Function(String data) func) {
    subscribed[event] ??= [];

    subscribed[event]!.add(func);
  }
}
