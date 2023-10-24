//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <mercury/mercury_plugin.h>

void fl_register_plugins(FlPluginRegistry* registry) {
  g_autoptr(FlPluginRegistrar) mercury_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "MercuryPlugin");
  mercury_plugin_register_with_registrar(mercury_registrar);
}
