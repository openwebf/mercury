cmake_minimum_required(VERSION 3.10.0)
set(CMAKE_OSX_DEPLOYMENT_TARGET 10.11)
project(Mercury)

set(CMAKE_OSX_DEPLOYMENT_TARGET 10.11)
# MSBuild are slower than Clang/GCC to support new CXX standards.
if(MSVC)
  set(CMAKE_CXX_STANDARD 20)
else()
  set(CMAKE_CXX_STANDARD 17)
endif()
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

if(MSVC)
  set(CMAKE_WINDOWS_EXPORT_ALL_SYMBOLS TRUE)
  set(BUILD_SHARED_LIBS TRUE)
endif()

if (${CMAKE_SYSTEM_NAME} MATCHES "Darwin")
  set(CMAKE_OSX_ARCHITECTURES "x86_64;arm64")
endif()

if(WIN32)
  set(PTHREADS_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/third_party/quickjs/compat/win32/pthreads")
  include_directories(${PTHREADS_ROOT}/include)
  link_directories(${PTHREADS_ROOT}/lib/x64)
endif()
find_package(Threads REQUIRED)

if(MSVC)
  add_compile_options(/MP)
endif()

if (${ENABLE_PROFILE})
  add_definitions(-DENABLE_PROFILE=1)
else ()
  add_definitions(-DENABLE_PROFILE=0)
endif ()

if(NOT MSVC)
  if (${CMAKE_BUILD_TYPE} STREQUAL "Release" OR ${CMAKE_BUILD_TYPE} STREQUAL "RelWithDebInfo")
    include(CheckIPOSupported)
    check_ipo_supported(RESULT supported OUTPUT error)
    if( supported )
      set(CMAKE_INTERPROCEDURAL_OPTIMIZATION TRUE)
      add_compile_options(-flto)
    endif()
  endif()
endif()

list(APPEND MERCURY_PUBLIC_HEADERS
        ${CMAKE_CURRENT_SOURCE_DIR}/include/mercury_bridge.h
)

set(QUICKJS_PUBLIC_HEADERS
  third_party/quickjs/cutils.h
  third_party/quickjs/libregexp.h
  third_party/quickjs/libregexp-opcode.h
  third_party/quickjs/libunicode.h
  third_party/quickjs/libunicode-table.h
  third_party/quickjs/list.h
  third_party/quickjs/quickjs.h
  third_party/quickjs/quickjs-atom.h
  third_party/quickjs/quickjs-opcode.h
)

if (${CMAKE_SYSTEM_NAME} STREQUAL "Linux")
  add_compile_options(-fPIC)
endif()

if (ENABLE_ASAN)
  add_compile_options(-fsanitize=address -fno-omit-frame-pointer)
  add_link_options(-fsanitize=address -fno-omit-frame-pointer)
endif ()

if (${CMAKE_BUILD_TYPE} STREQUAL "Debug")
  if (MSVC)
    set(CMAKE_CXX_FLAGS_RELEASE "/O1")
    set(CMAKE_C_FLAGS_RELEASE "/O1")
  else()
    # Avoid quickjs stackoverflow.
    add_compile_options(-O1)
  endif()
endif()

if (DEFINED PLATFORM)
  if (${PLATFORM} STREQUAL "OS")
    add_compile_options(-fno-aligned-allocation)
  endif()
endif()

list(APPEND BRIDGE_SOURCE
  mercury_bridge.cc
  foundation/logging.cc
  foundation/native_string.cc
  foundation/inspector_task_queue.cc
  foundation/task_queue.cc
  foundation/string_view.cc
  foundation/native_value.cc
  foundation/native_type.cc
  foundation/dart_readable.cc
  foundation/isolate_command_buffer.cc
  polyfill/dist/polyfill.cc
  ${CMAKE_CURRENT_LIST_DIR}/third_party/dart/include/dart_api_dl.c
  )

list(APPEND BRIDGE_INCLUDE
  ${CMAKE_CURRENT_LIST_DIR}/foundation
  ${CMAKE_CURRENT_LIST_DIR}/out
  ${CMAKE_CURRENT_LIST_DIR}
  ${CMAKE_CURRENT_LIST_DIR}/include
  ${CMAKE_CURRENT_LIST_DIR}/polyfill/dist
  ${CMAKE_CURRENT_LIST_DIR}/third_party/dart
  ${ADDITIONAL_INCLUDE_DIRS}
  )

if ($ENV{MERCURYJS_ENGINE} MATCHES "quickjs")
  add_compile_options(-DMERCURY_QUICK_JS_ENGINE=1)

  execute_process(
    COMMAND cat ${CMAKE_CURRENT_SOURCE_DIR}/third_party/quickjs/VERSION
    OUTPUT_VARIABLE QUICKJS_VERSION
  )

  add_library(modb STATIC
    third_party/modp_b64/modp_b64.cc
  )

  if (NOT MSVC)
    list(APPEND QUICK_JS_SOURCE third_party/quickjs/src/libbf.c)
  endif()

  list(APPEND QUICK_JS_SOURCE
    # third_party/quickjs/src/libbf.c
    third_party/quickjs/src/cutils.c
    third_party/quickjs/src/libregexp.c
    third_party/quickjs/src/libunicode.c
    third_party/quickjs/src/core/string.c
    third_party/quickjs/src/core/function.c
    third_party/quickjs/src/core/memory.c
    third_party/quickjs/src/core/bytecode.c
    third_party/quickjs/src/core/object.c
    third_party/quickjs/src/core/exception.c
    third_party/quickjs/src/core/gc.c
    third_party/quickjs/src/core/malloc.c
    third_party/quickjs/src/core/shape.c
    third_party/quickjs/src/core/parser.c
    third_party/quickjs/src/core/convertion.c
    third_party/quickjs/src/core/runtime.c
    third_party/quickjs/src/core/module.c
    third_party/quickjs/src/core/ic.c
    third_party/quickjs/src/core/builtins/js-array.c
    third_party/quickjs/src/core/builtins/js-async-function.c
    third_party/quickjs/src/core/builtins/js-async-generator.c
    third_party/quickjs/src/core/builtins/js-atomics.c
    third_party/quickjs/src/core/builtins/js-big-num.c
    third_party/quickjs/src/core/builtins/js-boolean.c
    third_party/quickjs/src/core/builtins/js-date.c
    third_party/quickjs/src/core/builtins/js-function.c
    third_party/quickjs/src/core/builtins/js-generator.c
    third_party/quickjs/src/core/builtins/js-json.c
    third_party/quickjs/src/core/builtins/js-map.c
    third_party/quickjs/src/core/builtins/js-math.c
    third_party/quickjs/src/core/builtins/js-number.c
    third_party/quickjs/src/core/builtins/js-object.c
    third_party/quickjs/src/core/builtins/js-closures.c
    third_party/quickjs/src/core/builtins/js-operator.c
    third_party/quickjs/src/core/builtins/js-promise.c
    third_party/quickjs/src/core/builtins/js-proxy.c
    third_party/quickjs/src/core/builtins/js-reflect.c
    third_party/quickjs/src/core/builtins/js-regexp.c
    third_party/quickjs/src/core/builtins/js-string.c
    third_party/quickjs/src/core/builtins/js-symbol.c
    third_party/quickjs/src/core/builtins/js-typed-array.c
  )
  if(${STATIC_QUICKJS})
    add_library(quickjs STATIC ${QUICK_JS_SOURCE})
  else()
    add_library(quickjs SHARED ${QUICK_JS_SOURCE})
  endif()

  if(WIN32)
    target_link_libraries(quickjs pthreadVC2)
    target_include_directories(quickjs PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/third_party/quickjs/compat/win32/atomic)
    target_compile_definitions(quickjs PUBLIC HAVE_STRUCT_TIMESPEC=1 _HAS_EXCEPTIONS=1)
  else()
    target_link_libraries(quickjs Threads::Threads)
  endif()

  set(MI_OVERRIDE OFF)
  if (NOT DEFINED USE_SYSTEM_MALLOC)
    add_compile_definitions(ENABLE_MI_MALLOC=1)
    add_subdirectory(${CMAKE_CURRENT_SOURCE_DIR}/third_party/quickjs/vendor/mimalloc)
    include_directories(${CMAKE_CURRENT_SOURCE_DIR}/third_party/quickjs/vendor/mimalloc/include)
    target_link_libraries(quickjs mimalloc-static)
  endif()

  target_include_directories(quickjs PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/third_party/quickjs/include)

  if (MSVC)
    target_include_directories(quickjs PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/third_party/quickjs/compat/win32/pthreads)
    target_include_directories(quickjs PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/third_party/quickjs/compat/win32/atomic)
  endif()

  list(APPEND BRIDGE_INCLUDE ${CMAKE_CURRENT_SOURCE_DIR}/third_party)
  list(APPEND BRIDGE_INCLUDE ${CMAKE_CURRENT_SOURCE_DIR}/third_party/modp_b64/include)
  list(APPEND BRIDGE_LINK_LIBS quickjs)
  list(APPEND BRIDGE_LINK_LIBS modb)

  list(APPEND BRIDGE_SOURCE
    # Binding files
    bindings/qjs/dictionary_base.cc
    bindings/qjs/js_based_event_listener.cc
    bindings/qjs/js_event_handler.cc
    bindings/qjs/js_event_listener.cc
    bindings/qjs/binding_initializer.cc
    bindings/qjs/member_installer.cc
    bindings/qjs/source_location.cc
    bindings/qjs/cppgc/gc_visitor.cc
    bindings/qjs/cppgc/mutation_scope.cc
    bindings/qjs/script_wrappable.cc
    bindings/qjs/native_string_utils.cc
    bindings/qjs/qjs_engine_patch.cc
    bindings/qjs/qjs_function.cc
    bindings/qjs/script_value.cc
    bindings/qjs/script_promise.cc
    bindings/qjs/script_promise_resolver.cc
    bindings/qjs/atomic_string.cc
    bindings/qjs/exception_state.cc
    bindings/qjs/exception_message.cc
    bindings/qjs/rejected_promises.cc
    bindings/qjs/union_base.cc
    # Core sources
    core/executing_context.cc
    core/script_state.cc
    core/mercury_isolate.cc
    core/dart_methods.cc
    core/dart_isolate_context.cc
    core/dart_context_data.cc
    core/executing_context_data.cc
    core/fileapi/blob.cc
    core/fileapi/blob_part.cc
    core/fileapi/blob_property_bag.cc
    core/module/console.cc
    core/module/timer/timer.cc
    core/module/timer/timer_coordinator.cc
    core/module/global_or_worker_scope.cc
    core/module/module_listener.cc
    core/module/module_listener_container.cc
    core/module/module_manager.cc
    core/module/module_callback.cc
    core/module/module_context_coordinator.cc
    core/module/global.cc
    core/event/registered_eventListener.cc
    core/event/event_listener_map.cc
    core/event/event.cc
    core/event/custom_event.cc
    core/event/event_target.cc
    core/event/event_listener_map.cc
    core/event/event_target_impl.cc
    core/binding_object.cc
    core/event/builtin/error_event.cc
    core/event/builtin/message_event.cc
    core/event/builtin/close_event.cc
    core/event/builtin/promise_rejection_event.cc
    )

  # Gen sources.
  list(APPEND BRIDGE_SOURCE
    out/names_installer.cc
    out/qjs_console.cc
    out/qjs_module_manager.cc
    out/qjs_global_or_worker_scope.cc
    out/qjs_global.cc
    out/qjs_blob.cc
    out/qjs_event.cc
    out/qjs_add_event_listener_options.cc
    out/qjs_event_listener_options.cc
    out/qjs_error_event.cc
    out/qjs_message_event.cc
    out/qjs_message_event_init.cc
    out/qjs_close_event.cc
    out/qjs_close_event_init.cc
    out/event_factory.cc
    out/qjs_custom_event.cc
    out/qjs_custom_event_init.cc
    out/qjs_error_event_init.cc
    out/qjs_event_init.cc
    out/qjs_event_target.cc
    out/event_type_names.cc
    out/built_in_string.cc
    out/binding_call_methods.cc
    out/qjs_promise_rejection_event.cc
    out/qjs_promise_rejection_event_init.cc
    out/defined_properties.cc
    out/qjs_unionevent_listener_options_boolean.cc
    out/qjs_unionadd_event_listener_options_boolean.cc
    )


  if (NOT MSVC)
  # Quickjs use __builtin_frame_address() to get stack pointer, we should add follow options to get it work with -O2
  # https://stackoverflow.com/questions/14735010/how-do-you-get-gccs-builtin-frame-address-to-work-with-o2
  add_compile_options(-fno-optimize-sibling-calls -fno-omit-frame-pointer)
  endif()
  target_compile_options(quickjs PUBLIC -DCONFIG_VERSION=${\"QUICKJS_VERSION\"})

endif ()

list(APPEND PUBLIC_HEADER
  include/mercury_bridge.h
)

add_library(mercuryjs SHARED ${BRIDGE_SOURCE})
add_library(mercury_static STATIC ${BRIDGE_SOURCE})

if(MSVC)
  target_compile_options(mercuryjs PRIVATE /JMC)
endif()

target_compile_definitions(mercuryjs PUBLIC -DFLUTTER_BACKEND=1)

if (${IS_ANDROID})
  find_library(log-lib log)

  if (${ANDROID_ABI} MATCHES "armeabi-v7a" OR ${ANDROID_ABI} MATCHES "x86")
    add_definitions(-DANDROID_32_BIT=1)
  endif()

  add_definitions(-DIS_ANDROID=1)
  list(APPEND BRIDGE_LINK_LIBS ${log-lib})
elseif(${IS_IOS})
  add_definitions(-DIS_IOS=1)
endif()


### mercury
target_include_directories(mercuryjs PRIVATE
  ${BRIDGE_INCLUDE}
  ${CMAKE_CURRENT_SOURCE_DIR} PUBLIC ./include)
target_link_libraries(mercuryjs PRIVATE ${BRIDGE_LINK_LIBS})

if ($ENV{MERCURYJS_ENGINE} MATCHES "quickjs" AND NOT MSVC)
  if (${CMAKE_BUILD_TYPE} STREQUAL "Release" OR ${CMAKE_BUILD_TYPE} STREQUAL "RelWithDebInfo")
    target_compile_options(mercuryjs PRIVATE -fno-exceptions -fvisibility=hidden -fno-rtti -fdata-sections -ffunction-sections)
    target_compile_options(quickjs PRIVATE -fno-exceptions -fno-rtti -fdata-sections -ffunction-sections)
  else ()
    ### remove dynamic_cast and exceptions
    target_compile_options(mercuryjs PRIVATE -fno-exceptions -fno-rtti)
  endif ()
endif ()

### mercuryStatic
target_include_directories(mercury_static PRIVATE
  ${BRIDGE_INCLUDE}
  ${CMAKE_CURRENT_SOURCE_DIR} PUBLIC ./include)
target_link_libraries(mercury_static ${BRIDGE_LINK_LIBS})

execute_process(
  COMMAND node get_app_ver.js
  WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}/scripts
  OUTPUT_VARIABLE APP_VER
)
string(REPLACE \n "" APP_VER ${APP_VER}) # Remove last \n
add_definitions(-DAPP_VERSION="${APP_VER}") # Read from dartfm version
execute_process(
  COMMAND git rev-parse --short HEAD
  WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
  OUTPUT_VARIABLE GIT_HEAD
)
string(REPLACE \n "" GIT_HEAD ${GIT_HEAD}) # Remove last \n
add_definitions(-DAPP_REV="${GIT_HEAD}") # Read from git head sha1

if (DEFINED ENV{LIBRARY_OUTPUT_DIR})
  set_target_properties(mercuryjs
    PROPERTIES
    LIBRARY_OUTPUT_DIRECTORY "$ENV{LIBRARY_OUTPUT_DIR}"
    RUNTIME_OUTPUT_DIRECTORY "$ENV{LIBRARY_OUTPUT_DIR}"
  )
  set_target_properties(mercury_static
    PROPERTIES ARCHIVE_OUTPUT_DIRECTORY "$ENV{LIBRARY_OUTPUT_DIR}")

  if ($ENV{MERCURYJS_ENGINE} MATCHES "quickjs")
    set_target_properties(quickjs
      PROPERTIES
        LIBRARY_OUTPUT_DIRECTORY "$ENV{LIBRARY_OUTPUT_DIR}"
        RUNTIME_OUTPUT_DIRECTORY "$ENV{LIBRARY_OUTPUT_DIR}"
    )
    if(MSVC)
      set(PTHREAD_LIB ${PTHREADS_ROOT}/dll/x64/pthreadVC2.dll)
      file(COPY ${PTHREAD_LIB} DESTINATION "$ENV{LIBRARY_OUTPUT_DIR}")
    endif()
  endif ()
elseif (IS_ANDROID)
  # android do nothing
endif ()

if (${CMAKE_SYSTEM_NAME} MATCHES "iOS")
  set(CMAKE_XCODE_ATTRIBUTE_CODE_SIGNING_REQUIRED "NO")
  set(CMAKE_XCODE_ATTRIBUTE_CODE_SIGN_IDENTITY "")

  set_target_properties(mercuryjs PROPERTIES
    OUTPUT_NAME mercury_bridge
    FRAMEWORK TRUE
    FRAMEWORK_VERSION C
    MACOSX_FRAMEWORK_IDENTIFIER com.openwebf.mercury-bridge
    MACOSX_FRAMEWORK_BUNDLE_VERSION 1.0
    MACOSX_FRAMEWORK_SHORT_VERSION_STRING 1.0
    PUBLIC_HEADER ${MERCURY_PUBLIC_HEADERS}
    )

  # If quickjs is static, there will be no quickjs.framework any more.
  if(NOT DEFINED STATIC_QUICKJS)
    set_target_properties(quickjs PROPERTIES
      OUTPUT_NAME quickjs
      FRAMEWORK TRUE
      FRAMEWORK_VERSION C
      MACOSX_FRAMEWORK_IDENTIFIER com.openwebf.quickjs
      MACOSX_FRAMEWORK_BUNDLE_VERSION 1.0
      MACOSX_FRAMEWORK_SHORT_VERSION_STRING 1.0
      PUBLIC_HEADER ${QUICKJS_PUBLIC_HEADERS}
      )
  endif()
endif ()
