/*
 * Copyright (C) 2019-2022 The Kraken authors. All rights reserved.
 * Copyright (C) 2022-present The WebF authors. All rights reserved.
 */

import 'package:mercuryjs/launcher.dart';
import 'package:mercuryjs/devtools.dart';

String enumKey(String key) {
  return key.split('.').last;
}

// Information about the Frame on the page.
class Frame extends JSONEncodable {
  // Frame unique identifier.
  final String id;

  // Parent frame identifier.
  String? parentId;

  // Identifier of the loader associated with this frame.
  final String loaderId;

  // Frame's name as specified in the tag.
  String? name;

  // Frame document's URL without fragment.
  final String url;

  // Frame document's URL fragment including the '#'.
  String? urlFragment;

  // Frame document's registered domain, taking the public suffixes list into account. Extracted from the Frame's url. Example URLs: http://www.google.com/file.html -> "google.com" http://a.b.co.uk/file.html -> "b.co.uk"
  final String domainAndRegistry;

  // Frame document's security origin.
  final String securityOrigin;

  // Frame document's mimeType as determined by the browser.
  final String mimeType;

  // If the frame failed to load, this contains the URL that could not be loaded. Note that unlike url above, this URL may contain a fragment.
  String? unreachableUrl;

  // Indicates whether this frame was tagged as an ad.
  String? AdFrameType;

  // Indicates whether the main document is a secure context and explains why that is the case.
  final String secureContextType;

  // Indicates whether this is a cross origin isolated context.
  final String crossOriginIsolatedContextType;

  // Indicated which gated APIs / features are available.
  final List<String> gatedAPIFeatures;

  Frame(this.id, this.loaderId, this.url, this.domainAndRegistry, this.securityOrigin, this.mimeType,
      this.secureContextType, this.crossOriginIsolatedContextType, this.gatedAPIFeatures,
      {this.parentId, this.name, this.urlFragment, this.unreachableUrl, this.AdFrameType});

  @override
  Map toJson() {
    Map<String, dynamic> map = {
      'id': id,
      'loaderId': loaderId,
      'url': url,
      'domainAndRegistry': domainAndRegistry,
      'securityOrigin': securityOrigin,
      'mimeType': mimeType,
      'secureContextType': secureContextType,
      'crossOriginIsolatedContextType': crossOriginIsolatedContextType,
      'gatedAPIFeatures': gatedAPIFeatures
    };

    if (parentId != null) map['parentId'] = parentId;
    if (name != null) map['name'] = name;
    if (urlFragment != null) map['urlFragment'] = urlFragment;
    if (unreachableUrl != null) map['unreachableUrl'] = unreachableUrl;
    if (AdFrameType != null) map['AdFrameType'] = AdFrameType;
    return map;
  }
}

class FrameResource extends JSONEncodable {
  // Resource URL.
  final String url;

  // Type of this resource.
  final String type;

  // Resource mimeType as determined by the browser.
  final String mimeType;

  // last-modified timestamp as reported by server.
  int? lastModified;

  // Resource content size.
  int? contentSize;

  // True if the resource failed to load.
  bool? failed;

  // True if the resource was canceled during loading.
  bool? canceled;

  FrameResource(this.url, this.type, this.mimeType, {this.lastModified, this.contentSize, this.failed, this.canceled});

  @override
  Map toJson() {
    Map<String, dynamic> map = {'url': url, 'type': type, 'mimeType': mimeType};
    if (lastModified != null) map['lastModified'] = lastModified;
    if (contentSize != null) map['contentSize'] = contentSize;
    if (failed != null) map['failed'] = failed;
    if (canceled != null) map['canceled'] = canceled;
    return map;
  }
}

// Information about the Frame hierarchy along with their cached resources.
class FrameResourceTree extends JSONEncodable {
  // Frame information for this tree item.
  final Frame frame;

  // Child frames.
  List<FrameResourceTree>? childFrames;

  // Information about frame resources.
  final List<FrameResource> resources;

  FrameResourceTree(this.frame, this.resources, {this.childFrames});

  @override
  Map toJson() {
    Map<String, dynamic> map = {'frame': frame, 'resources': resources};
    if (childFrames != null) map['childFrames'] = childFrames;
    return map;
  }
}

enum ResourceType {
  Document,
  Stylesheet,
  Image,
  Media,
  Font,
  Script,
  TextTrack,
  XHR,
  Fetch,
  EventSource,
  WebSocket,
  Manifest,
  SignedExchange,
  Ping,
  CSPViolationReport,
  Preflight,
  Other
}

class InspectPageModule extends UIInspectorModule {
  MercuryContextController get context => devtoolsService.controller!.context;

  InspectPageModule(DevToolsService devtoolsService) : super(devtoolsService);

  @override
  String get name => 'Page';

  @override
  void receiveFromFrontend(int? id, String method, Map<String, dynamic>? params) async {
    switch (method) {
      case 'getResourceContent':
        String? url = params!['url'];
        sendToFrontend(id,
            JSONEncodableMap({'content': devtoolsService.controller?.getResourceContent(url), 'base64Encoded': false}));
        break;
      case 'reload':
        sendToFrontend(id, null);
        handleReloadPage();
        break;
      default:
        sendToFrontend(id, null);
    }
  }

  void handleReloadPage() async {
    try {
      await context.rootController.reload();
    } catch (e, stack) {
      print('Dart Error: $e\n$stack');
    }
  }
}
