#!/bin/bash

printenv

SCRIPT_NAME=$0
echo "Running CLI ${SCRIPT_NAME} $@"



# The or_die function run the passed command line and
# exits the program in case of non zero error code
function or_die () {
    "$@"
    local status=$?

    if [[ $status != 0 ]] ; then
        echo ERROR $status command: $@
        exit $status
    fi
}

function usage () {
>&2 cat << EOF
Usage: $0
  --build-exe-only
      Request for the build of geos only.
  --cmake-build-type ...
      One of Debug, Release, RelWithDebInfo and MinSizeRel. Forwarded to CMAKE_BUILD_TYPE.
  --build-generator generator_name
      Build system generator. One of "Eclipse CDT4 - Unix Makefiles", "Ninja, "Unix Makefiles" and "Xcode".
  --code-coverage
      run a code build and test.
  --data-basename output.tar.gz
      If some data needs to be extracted from the build, the argument will define the tarball. Has to be a `tar.gz`.
  --exchange-dir /path/to/exchange
      Folder to share data with outside of the container.
  --host-config host-config/my_config.cmake
      The host-config. Path is relative to the root of the repository.
  --install-dir-basename GEOS-e42ffc1
      GEOS installation basename.
  --no-install-schema
      Do not install the xsd schema.
  --no-run-unit-tests
      Do not run the unit tests (but they will be built).
  --nproc N
      Number of cores to use for the build.
  --repository /path/to/repository
      Internal mountpoint where the geos repository will be available. 
  --run-integrated-tests
      Run the integrated tests. Then bundle and send the results to the cloud.
  --sccache-credentials credentials.json
      Basename of the json credentials file to connect to the sccache cloud cache.
  --test-code-style
  --test-documentation
  -h | --help
EOF
exit 1
}

# First working in the root of the cloned repository.
# Then we'll move to the build dir.
or_die cd $(dirname $0)/..


# Parsing using getopt
args=$(or_die getopt -a -o h --long build-exe-only,cmake-build-type:,build-generator:,code-coverage,data-basename:,exchange-dir:,host-config:,install-dir-basename:,no-install-schema,no-run-unit-tests,nproc:,repository:,run-integrated-tests,sccache-credentials:,test-code-style,test-documentation,help -- "$@")

# Variables with default values
BUILD_EXE_ONLY=false
BUILD_GENERATOR=""
GEOS_INSTALL_SCHEMA=true
HOST_CONFIG="host-configs/environment.cmake"
RUN_UNIT_TESTS=true
RUN_INTEGRATED_TESTS=false
UPLOAD_TEST_BASELINES=false
TEST_CODE_STYLE=false
TEST_DOCUMENTATION=false
CODE_COVERAGE=false
NPROC="$(nproc)"

eval set -- "${args}"
err=0
while :
do
  case $1 in
    --build-exe-only)
      BUILD_EXE_ONLY=true
      RUN_UNIT_TESTS=false
      shift;;
    --cmake-build-type)      CMAKE_BUILD_TYPE=$2;        shift 2;;
    --build-generator)
        if [[ -z "$2" || "Unix Makefiles" == "$2" ]] ; then
            BUILD_GENERATOR=""
        elif [[ "Eclipse CDT4 - Unix Makefiles" == "$2" ]] ; then
            BUILD_GENERATOR="--eclipse"
        elif [[ "Ninja" == "$2" ]] ; then
            BUILD_GENERATOR="--ninja"
        elif [[ "Xcode" == "$2" ]] ; then
            BUILD_GENERATOR="--xcode"
        else
            echo "Unexpected generator $2 passed to '--build-generator' option."
            err=1
        fi
        echo "Build generator is $BUILD_GENERATOR"
        shift 2;;
    --data-basename)
      DATA_BASENAME=$2
      DATA_BASENAME_WE=${DATA_BASENAME%%.*}
      DATA_BASENAME_EXT=${DATA_BASENAME#*.}
      if [[ ${DATA_BASENAME_EXT} != "tar.gz" ]] ; then
          echo "The script ${SCRIPT_NAME} can only pack data into a '.tar.gz' file."
          exit 1
      fi
      unset DATA_BASENAME DATA_BASENAME_EXT
      shift 2;;
    --exchange-dir)          DATA_EXCHANGE_DIR=$2;       shift 2;;
    --host-config)           HOST_CONFIG=$2;             shift 2;;
    --install-dir-basename)  GEOS_DIR=${GEOSX_TPL_DIR}/../$2; shift 2;;
    --no-install-schema)     GEOS_INSTALL_SCHEMA=false; shift;;
    --no-run-unit-tests)     RUN_UNIT_TESTS=false;       shift;;
    --nproc)                 NPROC=$2;                   shift 2;;
    --repository)            GEOS_SRC_DIR=$2;            shift 2;;
    --run-integrated-tests)  RUN_INTEGRATED_TESTS=true;  shift;;
    --upload-test-baselines) UPLOAD_TEST_BASELINES=true; shift;;
    --code-coverage)         CODE_COVERAGE=true;         shift;;
    --sccache-credentials)   SCCACHE_CREDS=$2;           shift 2;;
    --test-code-style)       TEST_CODE_STYLE=true;       shift;;
    --test-documentation)    TEST_DOCUMENTATION=true;    shift;;
    -h | --help)             usage;                      shift;;
    # -- means the end of the arguments; drop this, and break out of the while loop
    --) shift; break;;
    *) >&2 echo Unsupported option: $1
       usage;;
  esac
done


exit $err
