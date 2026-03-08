// test/_test_all.dart
// Main test runner - imports all test files
// Note: Integration tests require database setup and are excluded
// Run integration tests separately with: dart test test/integration/

import 'auth/password_utils_test.dart' as password_utils_test;
import 'auth/rule_engine_test.dart' as rule_engine_test;
import 'database/models_test.dart' as models_test;
import 'helpers/formatting_test.dart' as formatting_test;

void main() {
  password_utils_test.main();
  rule_engine_test.main();
  models_test.main();
  formatting_test.main();
}
