read_version() {
  VERSION_STR=$(cat mercury.podspec | grep s.version | awk '{print $3}')
  END_POS=$(echo ${#VERSION_STR} - 2 | bc)
  export VERSION=${VERSION_STR:1:$END_POS}
}

ROOT=$(pwd)

if [ -L "libmercury.dylib" ]; then
  rm libmercury.dylib
  ln -s $ROOT/../../bridge/build/macos/lib/x86_64/libmercury.dylib
fi

if [ -L "libquickjs.dylib" ]; then
  rm libquickjs.dylib
  ln -s $ROOT/../../bridge/build/macos/lib/x86_64/libquickjs.dylib
fi
