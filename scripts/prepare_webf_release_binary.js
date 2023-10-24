require('./tasks');
const chalk = require('chalk');
const { series } = require('gulp');
const os = require('os');

let buildTasks = [
  'sdk-clean',
  'compile-polyfill',
  'generate-bindings-code',
  'build-android-mercury-lib',
];

if (os.platform() == 'win32') {
  // TODO: add windows support
  buildTasks.push(
    'build-window-mercury-lib'
  );
} else if (os.platform() == 'darwin') {
  buildTasks.push(
    'macos-dylib-clean',
    'build-darwin-mercury-lib',
    'ios-framework-clean',
    'build-ios-mercury-lib',
  );
} else if (os.platform() == 'linux') {
  buildTasks.push(
    'build-linux-mercury-lib'
  )
}

series(buildTasks)((err) => {
  if (err) {
    console.log(err);
  } else {
    console.log(chalk.green('Success.'));
  }
});
