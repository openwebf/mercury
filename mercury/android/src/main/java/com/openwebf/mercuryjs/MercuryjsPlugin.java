package com.openwebf.mercury;

import android.content.Context;

import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry.Registrar;

/**
 * MercuryjsPlugin
 */
public class MercuryjsPlugin implements FlutterPlugin, MethodCallHandler {
  /// The MethodChannel that will the communication between Flutter and native Android
  ///
  /// This local reference serves to register the plugin with the Flutter Engine and unregister it
  /// when the Flutter Engine is detached from the Activity
  public MethodChannel channel;
  private FlutterEngine flutterEngine;
  private Context mContext;
  private Mercury mMercury;

  // This static function is optional and equivalent to onAttachedToEngine. It supports the old
  // pre-Flutter-1.12 Android projects. You are encouraged to continue supporting
  // plugin registration via this function while apps migrate to use the new Android APIs
  // post-flutter-1.12 via https://flutter.dev/go/android-project-migration.
  //
  // It is encouraged to share logic between onAttachedToEngine and registerWith to keep
  // them functionally equivalent. Only one of onAttachedToEngine or registerWith will be called
  // depending on the user's project. onAttachedToEngine or registerWith must both be defined
  // in the same class.
  public static void registerWith(Registrar registrar) {
    final MethodChannel channel = new MethodChannel(registrar.messenger(), "mercuryjs");
    MercuryjsPlugin plugin = new MercuryjsPlugin();
    plugin.mContext = registrar.context();
    channel.setMethodCallHandler(plugin);
  }

  @Override
  public void onAttachedToEngine(FlutterPluginBinding flutterPluginBinding) {
    loadLibrary();
    mContext = flutterPluginBinding.getApplicationContext();
    channel = new MethodChannel(flutterPluginBinding.getFlutterEngine().getDartExecutor(), "mercuryjs");
    flutterEngine = flutterPluginBinding.getFlutterEngine();
    channel.setMethodCallHandler(this);
  }

  Mercury getMercury() {
    if (mMercury == null) {
      mMercury = Mercury.get(flutterEngine);
    }
    return mMercury;
  }

  private static boolean isLibraryLoaded = false;
  private static void loadLibrary() {
    if (isLibraryLoaded) {
      return;
    }
    // Loads `libmercuryjs.so`.
    System.loadLibrary("mercuryjs");
    // Loads `libquickjs.so`.
    System.loadLibrary("quickjs");
    isLibraryLoaded = true;
  }

  @Override
  public void onMethodCall(MethodCall call, Result result) {
    switch (call.method) {
      case "getDynamicLibraryPath": {
        Mercury mercury = getMercury();
        result.success(mercury == null ? "" : mercury.getDynamicLibraryPath());
        break;
      }
      case "getTemporaryDirectory":
        result.success(getTemporaryDirectory());
        break;
      default:
        result.notImplemented();
    }
  }

  @Override
  public void onDetachedFromEngine(FlutterPluginBinding binding) {
    channel.setMethodCallHandler(null);
    Mercury mercury = Mercury.get(flutterEngine);
    if (mercury == null) return;
    mercuryjs.destroy();
    flutterEngine = null;
  }

  private String getTemporaryDirectory() {
    return mContext.getCacheDir().getPath() + "/Mercuryjs";
  }
}
