/*
 * Copyright (C) 2019-2022 The Kraken authors. All rights reserved.
 * Copyright (C) 2022-present The WebF authors. All rights reserved.
 */
#ifndef BRIDGE_CORE_DOM_EVENTS_REGISTERED_EVENTLISTENER_H_
#define BRIDGE_CORE_DOM_EVENTS_REGISTERED_EVENTLISTENER_H_

#include "event_listener.h"
#include "foundation/macros.h"

namespace mercury {

class AddEventListenerOptions;
class EventListenerOptions;

// RegisteredEventListener represents 'event listener' defined in the DOM
// standard. https://dom.spec.whatwg.org/#concept-event-listener
class RegisteredEventListener final {
  MERCURY_DISALLOW_NEW()
 public:
  RegisteredEventListener();
  RegisteredEventListener(const std::shared_ptr<EventListener>& listener,
                          std::shared_ptr<AddEventListenerOptions> options);
  RegisteredEventListener(const RegisteredEventListener& that);
  RegisteredEventListener& operator=(const RegisteredEventListener& that);

  const std::shared_ptr<EventListener> Callback() const { return callback_; }
  void SetCallback(const std::shared_ptr<EventListener>& listener);

  void SetCallback(EventListener* listener);

  bool Passive() const { return passive_; }

  bool Once() const { return once_; }

  bool Capture() const { return use_capture_; }

  bool BlockedEventWarningEmitted() const { return blocked_event_warning_emitted_; }

  void SetBlockedEventWarningEmitted() { blocked_event_warning_emitted_ = true; }

  bool Matches(const std::shared_ptr<EventListener>& listener,
               const std::shared_ptr<EventListenerOptions>& options) const;

  bool ShouldFire(const Event&) const;

  void Trace(GCVisitor* visitor) const;

 private:
  std::shared_ptr<EventListener> callback_;
  unsigned use_capture_ : 1;
  unsigned passive_ : 1;
  unsigned once_ : 1;
  unsigned blocked_event_warning_emitted_ : 1;

 private:
};

bool operator==(const RegisteredEventListener&, const RegisteredEventListener&);

}  // namespace mercury

#endif  // BRIDGE_CORE_DOM_EVENTS_REGISTERED_EVENTLISTENER_H_
