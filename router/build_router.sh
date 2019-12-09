if [ ! -n "$1" ]; then
  echo 'Platform(Linux, stdio, macOS or Xilinx) should be given.'
else
  if [ ! -d "build" ]; then
    mkdir build
  fi
  cd build
  cmake .. -DBACKEND=$1
  make router
fi