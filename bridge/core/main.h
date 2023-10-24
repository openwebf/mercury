/*
 * Copyright (C) 2019-2022 The Kraken authors. All rights reserved.
 * Copyright (C) 2022-present The WebF authors. All rights reserved.
 */

#ifndef MERCURY_JS_QJS_BRIDGE_H_
#define MERCURY_JS_QJS_BRIDGE_H_

#include <quickjs/quickjs.h>
#include <atomic>
#include <deque>
#include <thread>
#include <vector>

#include "core/executing_context.h"
#include "foundation/native_string.h"

namespace mercury {

class MercuryPage;
class DartContext;

using JSBridgeDisposeCallback = void (*)(MercuryPage* bridge);
using ConsoleMessageHandler = std::function<void(void* ctx, const std::string& message, int logLevel)>;

/// MercuryPage is class which manage all js objects create by <Mercury> flutter widget.
/// Every <Mercury> flutter widgets have a corresponding MercuryPage, and all objects created by JavaScript are stored here,
/// and there is no data sharing between objects between different MercuryPages.
/// It's safe to allocate many MercuryPages at the same times on one thread, but not safe for multi-threads, only one
/// thread can enter to MercuryPage at the same time.
class MercuryPage final {
 public:
  static ConsoleMessageHandler consoleMessageHandler;
  MercuryPage() = delete;
  MercuryPage(DartIsolateContext* dart_isolate_context, int32_t jsContext, const JSExceptionHandler& handler);
  ~MercuryPage();

  // Bytecodes which registered by mercury plugins.
  static std::unordered_map<std::string, NativeByteCode> pluginByteCode;

  // evaluate JavaScript source codes in standard mode.
  bool evaluateScript(const SharedNativeString* script,
                      uint8_t** parsed_bytecodes,
                      uint64_t* bytecode_len,
                      const char* url,
                      int startLine);
  bool evaluateScript(const uint16_t* script,
                      size_t length,
                      uint8_t** parsed_bytecodes,
                      uint64_t* bytecode_len,
                      const char* url,
                      int startLine);
  bool parseHTML(const char* code, size_t length);
  void evaluateScript(const char* script, size_t length, const char* url, int startLine);
  uint8_t* dumpByteCode(const char* script, size_t length, const char* url, size_t* byteLength);
  bool evaluateByteCode(uint8_t* bytes, size_t byteLength);

  std::thread::id currentThread() const;

  [[nodiscard]] ExecutingContext* GetExecutingContext() const { return context_; }

  NativeValue* invokeModuleEvent(SharedNativeString* moduleName,
                                 const char* eventType,
                                 void* event,
                                 NativeValue* extra);
  void reportError(const char* errmsg);

  int32_t contextId;
#if IS_TEST
  // the owner pointer which take JSBridge as property.
  void* owner;
  JSBridgeDisposeCallback disposeCallback{nullptr};
#endif
 private:
  const std::thread::id ownerThreadId;
  // FIXME: we must to use raw pointer instead of unique_ptr because we needs to access context_ when dispose page.
  // TODO: Raw pointer is dangerous and just works but it's fragile. We needs refactor this for more stable and
  // maintainable.
  ExecutingContext* context_;
  JSExceptionHandler handler_;
};

}  // namespace mercury

#endif  // MERCURY_JS_QJS_BRIDGE_H_
