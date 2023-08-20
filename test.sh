if [[ $1 == "" ]]; then
  echo "No platform specified"
  exit 1
fi

ARGS=""
if [[ $1 == "terminal" ]]; then
  ARGS="${ARGS} -Dterminal-full-pixel=true"
fi

zig build -Dexe-type=cli -Dplatform=$1 $ARGS || exit

INFO='\033[0;36m'
CLEAR='\033[0m'

scale=10
frate=840 # fast tests
tests=tests/bin/*.ch8

info() {
  printf "${INFO}$1${CLEAR}\n"
}

test_info() {
  echo "running $1"
  [[ "$1" =~ .*3.* ]] && info "Check if all checkmarks are present"
  [[ "$1" =~ .*4.* ]] && info "Check if all checkmarks are present"
}

for test in tests/bin/*.ch8
do
  test_info $test
  ./zig-out/bin/chip8 $test $scale $frate
done
