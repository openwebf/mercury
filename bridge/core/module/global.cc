/*
 * Copyright (C) 2019-2022 The Kraken authors. All rights reserved.
 * Copyright (C) 2022-present The WebF authors. All rights reserved.
 */

#include "global.h"
#include <modp_b64/modp_b64.h>
#include "binding_call_methods.h"
#include "bindings/qjs/cppgc/garbage_collected.h"
#include "core/event/builtin/message_event.h"
#include "core/executing_context.h"
#include "event_type_names.h"
#include "built_in_string.h"
#include "foundation/native_value_converter.h"
#include "foundation/isolate_command_buffer.h"

namespace mercury {

Global::Global(ExecutingContext* context) : EventTargetWithInlineData(context, built_in_string::kglobalThis) {
  context->isolateCommandBuffer()->addCommand(IsolateCommand::kCreateGlobal, nullptr, (void*)bindingObject(), nullptr);
}

// https://infra.spec.whatwg.org/#ascii-whitespace
// Matches the definition of IsHTMLSpace in html_parser_idioms.h.
template <typename CharType>
bool IsAsciiWhitespace(CharType character) {
  return character <= ' ' &&
         (character == ' ' || character == '\n' || character == '\t' || character == '\r' || character == '\f');
}

AtomicString Global::btoa(const AtomicString& source, ExceptionState& exception_state) {
  if (source.IsEmpty())
    return AtomicString::Empty();
  size_t encode_len = modp_b64_encode_data_len(source.length());
  std::vector<char> buffer;
  buffer.resize(encode_len);

  const size_t output_size = modp_b64_encode_data(reinterpret_cast<char*>(buffer.data()),
                                                  reinterpret_cast<const char*>(source.Character8()), source.length());
  assert(output_size == encode_len);

  return {ctx(), buffer.data(), buffer.size()};
}

// Invokes modp_b64 without stripping whitespace.
bool Base64DecodeRaw(const AtomicString& in, std::vector<uint8_t>& out, ModpDecodePolicy policy) {
  size_t decode_len = modp_b64_decode_len(in.length());
  out.resize(decode_len);

  const size_t output_size = modp_b64_decode(reinterpret_cast<char*>(out.data()),
                                             reinterpret_cast<const char*>(in.Character8()), in.length(), policy);
  if (output_size == MODP_B64_ERROR)
    return false;
  out.resize(output_size);
  return true;
}

bool Base64Decode(JSContext* ctx, AtomicString in, std::vector<uint8_t>& out, ModpDecodePolicy policy) {
  switch (policy) {
    case ModpDecodePolicy::kForgiving: {
      // https://infra.spec.whatwg.org/#forgiving-base64-decode
      // Step 1 is to remove all whitespace. However, checking for whitespace
      // slows down the "happy" path. Since any whitespace will fail normal
      // decoding from modp_b64_decode, just try again if we detect a failure.
      // This shouldn't be much slower for whitespace inputs.
      //
      // TODO(csharrison): Most callers use String inputs so ToString() should
      // be fast. Still, we should add a RemoveCharacters method to StringView
      // to avoid a double allocation for non-String-backed StringViews.
      return Base64DecodeRaw(in, out, policy) ||
             Base64DecodeRaw(in.RemoveCharacters(ctx, &IsAsciiWhitespace), out, policy);
    }
    case ModpDecodePolicy::kNoPaddingValidation: {
      return Base64DecodeRaw(in, out, policy);
    }
    case ModpDecodePolicy::kStrict:
      return false;
  }
}

AtomicString Global::atob(const AtomicString& source, ExceptionState& exception_state) {
  if (source.IsEmpty())
    return AtomicString::Empty();
  if (!source.ContainsOnlyLatin1OrEmpty()) {
    exception_state.ThrowException(ctx(), ErrorType::TypeError,
                                   "The string to be decoded contains \"\n"
                                   "        \"characters outside of the Latin1 range.");
    return AtomicString::Empty();
  }

  std::vector<uint8_t> buffer;
  if (!Base64Decode(ctx(), source, buffer, ModpDecodePolicy::kForgiving)) {
    exception_state.ThrowException(ctx(), ErrorType::TypeError, "The string to be decoded is not correctly encoded.");
    return AtomicString::Empty();
  }

  JSValue str = JS_NewRawUTF8String(ctx(), buffer.data(), buffer.size());
  AtomicString result = {ctx(), str};
  JS_FreeValue(ctx(), str);
  return result;
}

Global* Global::open(ExceptionState& exception_state) {
  return this;
}

Global* Global::open(const AtomicString& url, ExceptionState& exception_state) {
  const NativeValue args[] = {
      NativeValueConverter<NativeTypeString>::ToNativeValue(ctx(), url),
  };
  InvokeBindingMethod(binding_call_methods::kopen, 1, args, exception_state);
  return this;
}

void Global::postMessage(const ScriptValue& message, ExceptionState& exception_state) {
  auto event_init = MessageEventInit::Create();
  event_init->setData(message);
  auto* message_event =
      MessageEvent::Create(GetExecutingContext(), event_type_names::kmessage, event_init, exception_state);
  dispatchEvent(message_event, exception_state);
}

void Global::postMessage(const ScriptValue& message,
                         const AtomicString& target_origin,
                         ExceptionState& exception_state) {
  auto event_init = MessageEventInit::Create();
  event_init->setData(message);
  event_init->setOrigin(target_origin);
  auto* message_event =
      MessageEvent::Create(GetExecutingContext(), event_type_names::kmessage, event_init, exception_state);
  dispatchEvent(message_event, exception_state);
}

bool Global::IsGlobalOrWorkerScope() const {
  return true;
}

void Global::Trace(GCVisitor* visitor) const {
  EventTargetWithInlineData::Trace(visitor);
}

JSValue Global::ToQuickJS() const {
  return JS_GetGlobalObject(ctx());
}

}  // namespace mercury
