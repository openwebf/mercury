#import <Flutter/Flutter.h>

@interface MercuryjsPlugin : NSObject<FlutterPlugin>

@property NSObject<FlutterPluginRegistrar> *registrar;

- (instancetype) initWithRegistrar: (NSObject<FlutterPluginRegistrar>*)registrar;

+ (FlutterMethodChannel *) getMethodChannel;

@end
