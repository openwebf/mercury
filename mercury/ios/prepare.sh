ROOT=$(pwd)/Frameworks
cd $ROOT

if [ -L "mercury_js_bridge.xcframework" ]; then
  rm mercury_js_bridge.xcframework
  ln -s $ROOT/../../../bridge/build/ios/framework/mercury_js_bridge.xcframework
fi

if [ -L "quickjs.xcframework" ]; then
  rm quickjs.xcframework
  ln -s $ROOT/../../../bridge/build/ios/framework/quickjs.xcframework
fi
