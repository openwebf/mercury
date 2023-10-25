// Generated from template:
//   code_generator/src/json/templates/names_installer.h.tmpl


#ifndef <%= _.snakeCase(name).toUpperCase() %>_H_
#define <%= _.snakeCase(name).toUpperCase() %>_H_

#include "bindings/qjs/atomic_string.h"

namespace mercury {
namespace <%= name %> {

void Init(JSContext* ctx);
void Dispose();

}

} // mercury

#endif  // #define <%= _.snakeCase(name).toUpperCase() %>
