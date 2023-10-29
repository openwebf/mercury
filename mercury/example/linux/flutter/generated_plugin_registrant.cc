//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <mercuryjs/mercuryjs_plugin.h>

void fl_register_plugins(FlPluginRegistry* registry) {
  g_autoptr(FlPluginRegistrar) mercuryjs_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "MercuryjsPlugin");
  mercuryjs_plugin_register_with_registrar(mercuryjs_registrar);
}
