ROOT=$(pwd)/Frameworks
cd $ROOT

if [ -L "mercuryjs_bridge.xcframework" ]; then
  rm mercuryjs_bridge.xcframework
  ln -s $ROOT/../../../bridge/build/ios/framework/mercuryjs_bridge.xcframework
fi

if [ -L "quickjs.xcframework" ]; then
  rm quickjs.xcframework
  ln -s $ROOT/../../../bridge/build/ios/framework/quickjs.xcframework
fi
