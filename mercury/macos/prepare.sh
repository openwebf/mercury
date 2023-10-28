read_version() {
  VERSION_STR=$(cat mercury_js.podspec | grep s.version | awk '{print $3}')
  END_POS=$(echo ${#VERSION_STR} - 2 | bc)
  export VERSION=${VERSION_STR:1:$END_POS}
}

ROOT=$(pwd)

if [ -L "libmercury_js.dylib" ]; then
  rm libmercury_js.dylib
  ln -s $ROOT/../../bridge/build/macos/lib/x86_64/libmercury_js.dylib
fi

if [ -L "libquickjs.dylib" ]; then
  rm libquickjs.dylib
  ln -s $ROOT/../../bridge/build/macos/lib/x86_64/libquickjs.dylib
fi
