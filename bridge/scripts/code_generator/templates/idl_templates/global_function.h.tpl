#include "core/<%= blob.implement %>.h"

namespace mercury {

class ExecutingContext;

class QJS<%= className %> final {
 public:
  static void Install(ExecutingContext* context);
 private:
  static void InstallGlobalFunctions(ExecutingContext* context);
};

}
