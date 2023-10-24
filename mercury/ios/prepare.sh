ROOT=$(pwd)/Frameworks
cd $ROOT

if [ -L "mercury_bridge.xcframework" ]; then
  rm mercury_bridge.xcframework
  ln -s $ROOT/../../../bridge/build/ios/framework/mercury_bridge.xcframework
fi

if [ -L "quickjs.xcframework" ]; then
  rm quickjs.xcframework
  ln -s $ROOT/../../../bridge/build/ios/framework/quickjs.xcframework
fi
