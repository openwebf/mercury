const exec = require("child_process").execSync;
const fs = require("fs");
const PATH = require("path");
const os = require('os');

function symbolicToRealFile(path) {
  let realPath = PATH.join(path, "../", fs.readlinkSync(path));
  moveFile(path, realPath);
}

function txtToRealFile(path) {
  let realPath = PATH.join(path, '../', fs.readFileSync(path, {encoding: 'utf-8'}));
  moveFile(path, realPath.trim(), true);
}

function moveFile(path, realPath, replaceDll = false) {
  if (fs.lstatSync(realPath).isDirectory()) {
    exec(`rm ${path}`);
    exec(`cp -r ${realPath} ${path}`);
  } else {
    let buffer = fs.readFileSync(realPath);
    fs.rmSync(path);
    if (replaceDll) {
      fs.writeFileSync(path.replace('.txt', '.dll'), buffer);
    } else {
      fs.writeFileSync(path, buffer);
    }
  }
}

const krakenDir = PATH.join(__dirname, "../mercury");

const symbolFiles = [
  "android/jniLibs/arm64-v8a/libc++_shared.so",
  "android/jniLibs/arm64-v8a/libmercuryjs.so",
  "android/jniLibs/arm64-v8a/libquickjs.so",
  "android/jniLibs/armeabi-v7a/libc++_shared.so",
  "android/jniLibs/armeabi-v7a/libmercuryjs.so",
  "android/jniLibs/armeabi-v7a/libquickjs.so",
  "android/jniLibs/x86/libc++_shared.so",
  "android/jniLibs/x86/libmercuryjs.so",
  "android/jniLibs/x86/libquickjs.so",
  "ios/Frameworks/mercury_bridge.xcframework",
  "ios/Frameworks/quickjs.xcframework",
  "linux/libmercuryjs.so",
  "linux/libquickjs.so",
  "macos/libmercuryjs.dylib",
  "macos/libquickjs.dylib",
];

const txtFiles = [
  'windows/pthreadVC2.txt',
  'windows/quickjs.txt',
  'windows/mercuryjs.txt'
];

for (let file of symbolFiles) {
  symbolicToRealFile(PATH.join(krakenDir, file));
}

for (let file of txtFiles) {
  txtToRealFile(PATH.join(krakenDir, file));
}

