/*
 * Copyright (C) 2019-2022 The Kraken authors. All rights reserved.
 * Copyright (C) 2022-present The WebF authors. All rights reserved.
 */
import 'dart:io';

import 'package:mercuryjs/mercuryjs.dart';

// TODO: Don't use header to mark context.
const String HttpHeaderContext = 'x-context';

class MercuryHttpOverrides extends HttpOverrides {
  static MercuryHttpOverrides? _instance;

  MercuryHttpOverrides._();

  factory MercuryHttpOverrides.instance() {
    _instance ??= MercuryHttpOverrides._();
    return _instance!;
  }

  static double? getContextHeader(HttpHeaders headers) {
    String? doubleVal = headers.value(HttpHeaderContext);
    if (doubleVal == null) {
      return null;
    }
    return double.tryParse(doubleVal);
  }

  static void setContextHeader(HttpHeaders headers, double contextId) {
    headers.set(HttpHeaderContext, contextId.toString());
  }

  final HttpOverrides? parentHttpOverrides = HttpOverrides.current;
  final Map<double, HttpClientInterceptor> _contextIdToHttpClientInterceptorMap = <double, HttpClientInterceptor>{};

  void registerMercuryContext(double contextId, HttpClientInterceptor httpClientInterceptor) {
    _contextIdToHttpClientInterceptorMap[contextId] = httpClientInterceptor;
  }

  bool unregisterMercuryContext(double contextId) {
    // Returns true if [value] was in the map, false otherwise.
    return _contextIdToHttpClientInterceptorMap.remove(contextId) != null;
  }

  bool hasInterceptor(double contextId) {
    return _contextIdToHttpClientInterceptorMap.containsKey(contextId);
  }

  HttpClientInterceptor getInterceptor(double contextId) {
    return _contextIdToHttpClientInterceptorMap[contextId]!;
  }

  void clearInterceptors() {
    _contextIdToHttpClientInterceptorMap.clear();
  }

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    HttpClient nativeHttpClient;
    if (parentHttpOverrides != null) {
      nativeHttpClient = parentHttpOverrides!.createHttpClient(context);
    } else {
      nativeHttpClient = super.createHttpClient(context);
    }

    return ProxyHttpClient(nativeHttpClient, this);
  }

  @override
  String findProxyFromEnvironment(Uri url, Map<String, String>? environment) {
    if (parentHttpOverrides != null) {
      return parentHttpOverrides!.findProxyFromEnvironment(url, environment);
    } else {
      return super.findProxyFromEnvironment(url, environment);
    }
  }
}

MercuryHttpOverrides setupHttpOverrides(HttpClientInterceptor? httpClientInterceptor, {required double contextId}) {
  final MercuryHttpOverrides httpOverrides = MercuryHttpOverrides.instance();

  if (httpClientInterceptor != null) {
    httpOverrides.registerMercuryContext(contextId, httpClientInterceptor);
  }

  HttpOverrides.global = httpOverrides;
  return httpOverrides;
}

// Returns the origin of the URI in the form scheme://host:port
String getOrigin(Uri uri) {
  if (uri.isScheme('http') || uri.isScheme('https')) {
    return uri.origin;
  } else {
    return uri.path;
  }
}

// @TODO: Remove controller dependency.
Uri getEntrypointUri(double? contextId) {
  MercuryController? controller = MercuryController.getControllerOfJSContextId(contextId);
  String url = controller?.url ?? '';
  return Uri.tryParse(url) ?? MercuryController.fallbackBundleUri(contextId ?? 0.0);
}
