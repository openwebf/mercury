/*
 * Copyright (C) 2019-2022 The Kraken authors. All rights reserved.
 * Copyright (C) 2022-present The WebF authors. All rights reserved.
 */
#include "timer_coordinator.h"
#include "core/dart_methods.h"
#include "core/executing_context.h"
#include "timer.h"

#if UNIT_TEST
#include "mercury_test_env.h"
#endif

namespace mercury {

void TimerCoordinator::installNewTimer(ExecutingContext* context,
                                          int32_t timer_id,
                                          std::shared_ptr<Timer> timer) {
  active_timers_[timer_id] = timer;
}

void TimerCoordinator::removeTimeoutById(int32_t timer_id) {
  if (active_timers_.count(timer_id) == 0)
    return;
  auto timer = active_timers_[timer_id];
  timer->Terminate();
  terminated_timers[timer_id] = timer;
  active_timers_.erase(timer_id);
}

void TimerCoordinator::forceStopTimeoutById(int32_t timer_id) {
  if (active_timers_.count(timer_id) == 0) {
    return;
  }
  auto timer = active_timers_[timer_id];

  if (timer->status() == Timer::TimerStatus::kExecuting) {
    timer->SetStatus(Timer::TimerStatus::kCanceled);
  } else if (timer->status() == Timer::TimerStatus::kPending ||
             (timer->kind() == Timer::TimerKind::kMultiple && timer->status() == Timer::TimerStatus::kFinished)) {
    removeTimeoutById(timer->timerId());
  }
}

std::shared_ptr<Timer> TimerCoordinator::getTimerById(int32_t timer_id) {
  if (active_timers_.count(timer_id) == 0)
    return nullptr;
  return active_timers_[timer_id];
}

}  // namespace mercury
