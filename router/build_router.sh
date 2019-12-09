if [ ! -d "build" ]; then
  mkdir build
fi
cd build
cmake .. -DBACKEND=$1
make router_hal
make router