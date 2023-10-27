import 'package:mercury/mercury.dart';

class MercuryDispatcher extends EventTarget {
  Map<String, List<Function(String data)>> subscribed = Map()

  MercuryDispatcher(BindingContext? context) : super(context)

  @override
  EventTarget? get parentEventTarget {
    return null;
  }

  @override
  void initializeMethods(Map<String, BindingObjectMethod> methods) {
    methods['dispatch'] = BindingObjectMethodSync(call: (args) {
      assert(args[0] is String && args[1] is String);

      subscribed[args[0]]?.forEach((func) { func(args[1]); });
      return true;
    });
  }

  @override
  void initializeProperties(Map<String, BindingObjectProperty> properties) {
  }
}
