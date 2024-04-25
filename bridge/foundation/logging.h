/*
 * Copyright (C) 2019-2022 The Kraken authors. All rights reserved.
 * Copyright (C) 2022-present The WebF authors. All rights reserved.
 */

#ifndef FOUNDATION_LOGGING_H_
#define FOUNDATION_LOGGING_H_

#include <cstdint>

#include <sstream>
#include <string>

#define MERCURY_LOG_STREAM(severity) ::mercury::LogMessage(::mercury::severity, __FILE__, __LINE__, nullptr).stream()

#define MERCURY_LAZY_STREAM(stream, condition) !(condition) ? (void)0 : ::mercury::LogMessageVoidify() & (stream)

#define MERCURY_EAT_STREAM_PARAMETERS(ignored) \
  true || (ignored) ? (void)0 : ::LogMessageVoidify() & ::LogMessage(::LOG_FATAL, 0, 0, nullptr).stream()

#define MERCURY_LOG(severity) MERCURY_LAZY_STREAM(MERCURY_LOG_STREAM(severity), true)

#define MERCURY_CHECK(condition) \
  MERCURY_LAZY_STREAM(::mercury::LogMessage(::mercury::FATAL, __FILE__, __LINE__, #condition).stream(), !(condition))

namespace mercury {

class ExecutingContext;

typedef int LogSeverity;

// Default log levels. Negative values can be used for verbose log levels.
constexpr LogSeverity VERBOSE = 0;
constexpr LogSeverity INFO = 1;
constexpr LogSeverity WARN = 2;
constexpr LogSeverity DEBUG = 3;
constexpr LogSeverity ERROR = 4;
constexpr LogSeverity NUM_SEVERITIES = 5;
constexpr LogSeverity FATAL = 6;

enum MessageLevel : uint8_t {
  Log = 1,
  Warning = 2,
  Error = 3,
  Debug = 4,
  Info = 5,
};

class LogMessageVoidify {
 public:
  void operator&(std::ostream&) {}
};

class LogMessage {
 public:
  LogMessage(LogSeverity severity, const char* file, int line, const char* condition);
  ~LogMessage();

  std::ostream& stream() { return stream_; }

 private:
  std::ostringstream stream_;
  const LogSeverity severity_;
  const char* file_;
  const int line_;
};

void printLog(ExecutingContext* context, std::stringstream& stream, std::string level, void* ctx);

}  // namespace mercury

#endif  // FOUNDATION_LOGGING_H_
