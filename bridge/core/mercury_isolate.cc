/*
 * Copyright (C) 2019-2022 The Kraken authors. All rights reserved.
 * Copyright (C) 2022-present The WebF authors. All rights reserved.
 */
#include <atomic>
#include <unordered_map>

#include "bindings/qjs/atomic_string.h"
#include "bindings/qjs/binding_initializer.h"
#include "core/dart_methods.h"
#include "core/module/global.h"
#include "event_factory.h"
#include "foundation/logging.h"
#include "foundation/native_value_converter.h"
#include "mercury_isolate.h"
#include "polyfill.h"

namespace mercury {

ConsoleMessageHandler MercuryIsolate::consoleMessageHandler{nullptr};

MercuryIsolate::MercuryIsolate(DartIsolateContext* dart_isolate_context, int32_t contextId, const JSExceptionHandler& handler)
    : contextId(contextId), ownerThreadId(std::this_thread::get_id()) {
  context_ = new ExecutingContext(
      dart_isolate_context, contextId,
      [](ExecutingContext* context, const char* message) {
        if (context->dartMethodPtr()->onJsError != nullptr) {
          context->dartMethodPtr()->onJsError(context->contextId(), message);
        }
        MERCURY_LOG(ERROR) << message << std::endl;
      },
      this);
}

NativeValue* MercuryIsolate::invokeModuleEvent(SharedNativeString* native_module_name,
                                         const char* eventType,
                                         void* ptr,
                                         NativeValue* extra) {
  if (!context_->IsContextValid())
    return nullptr;

  MemberMutationScope scope{context_};

  JSContext* ctx = context_->ctx();
  Event* event = nullptr;
  if (ptr != nullptr) {
    std::string type = std::string(eventType);
    auto* raw_event = static_cast<RawEvent*>(ptr);
    event = EventFactory::Create(context_, AtomicString(ctx, type), raw_event);
    delete raw_event;
  }

  ScriptValue extraObject = ScriptValue(ctx, const_cast<const NativeValue&>(*extra));
  AtomicString module_name = AtomicString(
      ctx, std::unique_ptr<AutoFreeNativeString>(reinterpret_cast<AutoFreeNativeString*>(native_module_name)));
  auto listener = context_->ModuleListeners()->listener(module_name);

  if (listener == nullptr) {
    return nullptr;
  }

  ScriptValue arguments[] = {event != nullptr ? event->ToValue() : ScriptValue::Empty(ctx), extraObject};
  ScriptValue result = listener->value()->Invoke(ctx, ScriptValue::Empty(ctx), 2, arguments);
  if (result.IsException()) {
    context_->HandleException(&result);
    return nullptr;
  }

  ExceptionState exception_state;
  auto* return_value = static_cast<NativeValue*>(malloc(sizeof(NativeValue)));
  NativeValue tmp = result.ToNative(ctx, exception_state);
  if (exception_state.HasException()) {
    context_->HandleException(exception_state);
    return nullptr;
  }

  memcpy(return_value, &tmp, sizeof(NativeValue));
  return return_value;
}

bool MercuryIsolate::evaluateScript(const SharedNativeString* script,
                              uint8_t** parsed_bytecodes,
                              uint64_t* bytecode_len,
                              const char* url,
                              int startLine) {
  if (!context_->IsContextValid())
    return false;
  return context_->EvaluateJavaScript(script->string(), script->length(), parsed_bytecodes, bytecode_len, url,
                                      startLine);
}

bool MercuryIsolate::evaluateScript(const uint16_t* script,
                              size_t length,
                              uint8_t** parsed_bytecodes,
                              uint64_t* bytecode_len,
                              const char* url,
                              int startLine) {
  if (!context_->IsContextValid())
    return false;
  return context_->EvaluateJavaScript(script, length, parsed_bytecodes, bytecode_len, url, startLine);
}

void MercuryIsolate::evaluateScript(const char* script, size_t length, const char* url, int startLine) {
  if (!context_->IsContextValid())
    return;
  context_->EvaluateJavaScript(script, length, url, startLine);
}

uint8_t* MercuryIsolate::dumpByteCode(const char* script, size_t length, const char* url, size_t* byteLength) {
  if (!context_->IsContextValid())
    return nullptr;
  return context_->DumpByteCode(script, length, url, byteLength);
}

bool MercuryIsolate::evaluateByteCode(uint8_t* bytes, size_t byteLength) {
  if (!context_->IsContextValid())
    return false;
  return context_->EvaluateByteCode(bytes, byteLength);
}

std::thread::id MercuryIsolate::currentThread() const {
  return ownerThreadId;
}

MercuryIsolate::~MercuryIsolate() {
#if IS_TEST
  if (disposeCallback != nullptr) {
    disposeCallback(this);
  }
#endif
  delete context_;
}

void MercuryIsolate::reportError(const char* errmsg) {
  handler_(context_, errmsg);
}

}  // namespace mercury
