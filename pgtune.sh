#!/usr/bin/env bash

function _version()
{
    cat ./VERSION
    echo ""
    exit
}

function _usage()
{
    echo -e "Build project folders\n"
	echo -e "Usage:"
	echo -e "  bash $0 [OPTIONS...]\n"
	echo -e "Options:"
	echo -e "  -o, --output=file\t\t\tStore data in file (If not set show in stdout)"
    echo -e "  -v, --version\t\t\t\tShow version information and exit"
	echo -e "  -h, --help\t\t\t\tShow help"
	echo ""
	echo -e "      --db-version=version\t\tPostgres database version [REQUIRE]"
	echo -e "      --db-type=type\t\t\tPostgres database type (web|oltp|dw|desktop|mixed) [REQUIRE]"
	echo -e "      --os-type=type\t\t\tOperation system type (linux|windows) [REQUIRE]"
	echo -e "      --max-connection=connection\tNumber of connections"
	echo -e "      --memory=memory\t\t\tTotal memory (RAM) [REQUIRE]"
	echo -e "      --cpu=cpu\t\t\t\tNumber of CPUs"
	echo -e "      --hd-type=cpu\t\t\tData storage (ssd|san|hdd) [REQUIRE]"
	echo ""

    exit
}


if [[ $# -eq 0 ]]; then
    _usage
fi

POSITIONAL=()
while [[ $# -gt 0 ]]; do
    key="$1"

    case ${key} in
        # Output file
        #############
        -o|--output)
            declare -r I_OUTPUT="$2"
            shift
            shift
        ;;
        -o=*|--output=*)
            declare -r I_OUTPUT="${key#*=}"
            shift
        ;;

        # Output file
        #############
        -r|--replace)
            declare -r I_REPLACE="$2"
            shift
            shift
        ;;
        -r=*|--replace=*)
            declare -r I_REPLACE="${key#*=}"
            shift
        ;;

        # Input database version
        ########################
        --db-version)
            declare -r I_DB_VERSION="$2"
            shift
            shift
        ;;
        --db-version=*)
            declare -r I_DB_VERSION="${key#*=}"
            shift
        ;;

        # Input database type
        #####################
        --db-type)
            declare -r I_DB_TYPE="$2"
            shift
            shift
        ;;
        --db-type=*)
            declare -r I_DB_TYPE="${key#*=}"
            shift
        ;;

        # Input os type
        ###############
        --os-type)
            declare -r I_OS_TYPE="$2"
            shift
            shift
        ;;
        --os-type=*)
            declare -r I_OS_TYPE="${key#*=}"
            shift
        ;;

        # Input max connection
        ######################
        --max-connection)
            declare -r I_MAX_CONNECTION="$2"
            shift
            shift
        ;;
        --max-connection=*)
            declare -r I_MAX_CONNECTION="${key#*=}"
            shift
        ;;

        # Input total memory
        ####################
        --memory)
            declare -r I_MEMORY="$2"
            shift
            shift
        ;;
        --memory=*)
            declare -r I_MEMORY="${key#*=}"
            shift
        ;;

        # Input hd type
        ###############
        --cpu)
            declare -r I_CPU="$2"
            shift
            shift
        ;;
        --cpu=*)
            declare -r I_CPU="${key#*=}"
            shift
        ;;

        # Input hd type
        ###############
        --hd-type)
            declare -r I_HD_TYPE="$2"
            shift
            shift
        ;;
        --hd-type=*)
            declare -r I_HD_TYPE="${key#*=}"
            shift
        ;;

        -v|--version)
            _version
            shift
        ;;

        -h|--help)
            _usage
            shift
        ;;

        *)
            _usage
            shift
        ;;
    esac
done
set -- "${POSITIONAL[@]}"

if [[ -z ${I_DB_VERSION} ]]; then
    echo "[ERR] Please add database version"
    exit 1
fi

if [[ -z ${I_DB_TYPE} ]]; then
    echo "[ERR] Please add database type (web|oltp|dw|desktop|mixed)"
    exit 1
elif [[ ! ${I_DB_TYPE} =~ ^(web|oltp|dw|desktop|mixed)$ ]]; then
    echo "[ERR] Database type not match with one of type (web|oltp|dw|desktop|mixed)"
    exit 1
fi

if [[ -z ${I_OS_TYPE} ]]; then
    echo "[ERR] Please add operation system type (linux|windows)"
    exit 1
elif [[ ! ${I_OS_TYPE} =~ ^(linux|windows)$ ]]; then
    echo "[ERR] Operation system type not match with one of type (linux|windows)"
    exit 1
fi

if [[ -z ${I_MEMORY} ]]; then
    echo "[ERR] Please add total memory"
    exit 1
elif [[ ! ${I_MEMORY} =~ ^([0-9]+)(MB|GB)$ ]]; then
    echo "[ERR] Memory type not match with one of type (MB|GB)"
    exit 1
fi

if [[ -z ${I_HD_TYPE} ]]; then
    echo "[ERR] Please add data storage type (ssd|san|hdd)"
    exit 1
elif [[ ! ${I_HD_TYPE} =~ ^(ssd|san|hdd)$ ]]; then
    echo "[ERR] Data storage type not match with one of type (ssd|san|hdd)"
    exit 1
fi

if [[ -z ${I_CPU} ]]; then
    cpu_num=0
else
    cpu_num=${I_CPU}
fi

declare -r SIZE_KB=1024
declare -r SIZE_MB=1048576
declare -r SIZE_GB=1073741824
declare -r SIZE_TB=1099511627776

declare -r KB_UNIT_MAP_MB=1024
declare -r KB_UNIT_MAP_GB=1048576

declare -r GET_MEMORY_SIZE="SIZE_${I_MEMORY: -2}"
declare -r MEMORY_IN_BYTES=$(( ${I_MEMORY:0:-2} * !GET_MEMORY_SIZE ))
declare -r MEMORY_IN_KB=$(( MEMORY_IN_BYTES / SIZE_KB ))

output_list=("max_connection" "shared_buffers" "effective_cache_size" "maintenance_work_mem" "checkpoint_completion_target" "wal_buffers" "default_statistics_target" "random_page_cost" "effective_io_concurrency" "work_mem" "checkpoint_segments" "min_wal_size" "max_wal_size" "max_worker_processes" "max_parallel_workers_per_gather" "max_parallel_workers")

for out in "${output_list[@]}"; do
    read "o_$out" <<< "0"
done

function formatValue()
{
    local output;

    if [[ $(awk 'BEGIN { print ('"${1}"' < 999) ? "y" : "n" }') = "y" ]]; then
        output="${1}"
    elif [[ $(( ${1} % KB_UNIT_MAP_GB )) -eq 0 ]]; then
        output="$(( ${1} / KB_UNIT_MAP_GB ))GB"
    elif [[ $(( ${1} % KB_UNIT_MAP_MB )) -eq 0 ]]; then
        output="$(( ${1} / KB_UNIT_MAP_MB ))MB"
    else
        output="${1}kB"
    fi

    echo "${output}"
}

function getMaxConnection ()
{
    local max_connection=0
    if [[ -z ${I_MAX_CONNECTION} ]]; then
        case ${I_DB_TYPE} in
            web)
                max_connection=200
            ;;
            oltp)
                max_connection=300
            ;;
            dw)
                max_connection=20
            ;;
            desktop)
                max_connection=10
            ;;
            mixed)
                max_connection=100
            ;;
        esac
    else
        max_connection=${I_MAX_CONNECTION}
    fi

    o_max_connection=${max_connection}
}

function getSharedBuffers()
{
    local shared_buffers=0
    case ${I_DB_TYPE} in
        web|oltp|dw|mixed)
            shared_buffers=$(( MEMORY_IN_KB / 4 ))
        ;;
        desktop)
            shared_buffers=$(( MEMORY_IN_KB / 16 ))
        ;;
    esac

    local shared_buffers_win=$(( 512 * SIZE_MB / SIZE_KB ))
    if [[ ${I_OS_TYPE} = "windows" ]] && [[ ${shared_buffers} -gt ${shared_buffers_win} ]]; then
        shared_buffers=${shared_buffers_win}
    fi

    o_shared_buffers=${shared_buffers}
}

function getEffectiveCacheSize()
{
    local effective_cache_size=0
    case ${I_DB_TYPE} in
        web|oltp|dw|mixed)
            effective_cache_size=$(( MEMORY_IN_KB * 3 / 4 ))
        ;;
        desktop)
            effective_cache_size=$(( MEMORY_IN_KB / 4 ))
        ;;
    esac

    o_effective_cache_size=${effective_cache_size}
}

function getMaintenanceWorkMem()
{
    local maintenance_work_mem=0
    case ${I_DB_TYPE} in
        web|oltp|desktop|mixed)
            maintenance_work_mem=$(( MEMORY_IN_KB / 16 ))
        ;;
        dw)
            maintenance_work_mem=$(( MEMORY_IN_KB / 8 ))
        ;;
    esac

    local memory_limit=$(( 2 * SIZE_GB / SIZE_KB ))
    if [[ ${maintenance_work_mem} -gt ${memory_limit} ]]; then
        maintenance_work_mem=${memory_limit}
    fi

    o_maintenance_work_mem=${maintenance_work_mem}
}

function getCheckpointCompletionTarget()
{
    case ${I_DB_TYPE} in
        web)
            o_checkpoint_completion_target=0.7
        ;;
        oltp)
            o_checkpoint_completion_target=0.9
        ;;
        dw)
            o_checkpoint_completion_target=0.9
        ;;
        desktop)
            o_checkpoint_completion_target=0.5
        ;;
        mixed)
            o_checkpoint_completion_target=0.9
        ;;
    esac
}

function getWalBuffers()
{
    local wal_buffers=$(( 3 * o_shared_buffers / 100 ))
    local max_wal_buffer=$(( 16 * SIZE_MB / SIZE_KB ))

    if [[ ${wal_buffers} -gt ${max_wal_buffer} ]]; then
        wal_buffers=${max_wal_buffer}
    fi

    local wal_buffer_near=$(( 14 * SIZE_MB / SIZE_KB ))
    if [[ ${wal_buffers} -gt ${wal_buffer_near} ]] && [[ ${wal_buffers} -lt ${max_wal_buffer} ]]; then
        wal_buffers=${max_wal_buffer}
    fi

    if [[ ${wal_buffers} -lt 32 ]]; then
        wal_buffers=32
    fi

    o_wal_buffers=${wal_buffers}
}

function getDefaultStatisticsTarget()
{
    case ${I_DB_TYPE} in
        web)
            o_default_statistics_target=100
        ;;
        oltp)
            o_default_statistics_target=100
        ;;
        dw)
            o_default_statistics_target=500
        ;;
        desktop)
            o_default_statistics_target=100
        ;;
        mixed)
            o_default_statistics_target=100
        ;;
    esac
}

function getRandomPageCost()
{
    case ${I_HD_TYPE} in
        ssd)
            o_random_page_cost=1.1
        ;;
        san)
            o_random_page_cost=1.1
        ;;
        hdd)
            o_random_page_cost=4
        ;;
    esac
}

function getEffectiveIoConcurrency()
{
    if [[ ${I_OS_TYPE} = "windows" ]]; then
        return
    else
        case ${I_HD_TYPE} in
            ssd)
                o_effective_io_concurrency=200
            ;;
            san)
                o_effective_io_concurrency=300
            ;;
            hdd)
                o_effective_io_concurrency=2
            ;;
        esac
    fi
}

function getParallelSettings()
{
    if [[ $(awk 'BEGIN { print ('"${I_DB_VERSION}"' < 9.5) ? "y" : "n" }') = "y" ]] || [[ ${cpu_num} -lt 2 ]]; then
        return
    fi

    o_max_worker_processes=${cpu_num}

    if [[ $(awk 'BEGIN { print ('"${I_DB_VERSION}"' >= 9.6) ? "y" : "n" }') = "y" ]]; then
        o_max_parallel_workers_per_gather=$(( cpu_num / 2 ))
    fi

    if [[ $(awk 'BEGIN { print ('"${I_DB_VERSION}"' >= 10) ? "y" : "n" }') = "y" ]]; then
        o_max_parallel_workers=${cpu_num}
    fi
}

function getWorkMem()
{
    getParallelSettings

    local parallel_for_work_mem=1;
    if [[ ${o_max_worker_processes} -gt 0 ]]; then
        parallel_for_work_mem=$(( o_max_worker_processes / 2 ))
    fi

    local work_mem=$(( $(( MEMORY_IN_KB - o_shared_buffers )) / $(( o_max_connection * 3 )) / parallel_for_work_mem ))

    case ${I_DB_TYPE} in
        web)
            o_work_mem=${work_mem}
        ;;
        oltp)
            o_work_mem=${work_mem}
        ;;
        dw)
            o_work_mem=$(( work_mem / 2 ))
        ;;
        desktop)
            o_work_mem=$(( work_mem / 6 ))
        ;;
        mixed)
            o_work_mem=$(( work_mem / 2 ))
        ;;
    esac

    if [[ ${o_work_mem} -lt 64 ]]; then
        o_work_mem=64
    fi
}

function getCheckpointSegments()
{
    case ${I_DB_TYPE} in
        web)
            if [[ $(awk 'BEGIN { print ('"${I_DB_VERSION}"' < 9.5) ? "y" : "n" }') = "y" ]]; then
                o_checkpoint_segments=32
            else
                o_min_wal_size=$(( 1024 * SIZE_MB / SIZE_KB ))
                o_max_wal_size=$(( 2048 * SIZE_MB / SIZE_KB ))
            fi
        ;;
        oltp)
            if [[ $(awk 'BEGIN { print ('"${I_DB_VERSION}"' < 9.5) ? "y" : "n" }') = "y" ]]; then
                o_checkpoint_segments=64
            else
                o_min_wal_size=$(( 2048 * SIZE_MB / SIZE_KB ))
                o_max_wal_size=$(( 4096 * SIZE_MB / SIZE_KB ))
            fi
        ;;
        dw)
            if [[ $(awk 'BEGIN { print ('"${I_DB_VERSION}"' < 9.5) ? "y" : "n" }') = "y" ]]; then
                o_checkpoint_segments=128
            else
                o_min_wal_size=$(( 4096 * SIZE_MB / SIZE_KB ))
                o_max_wal_size=$(( 8192 * SIZE_MB / SIZE_KB ))
            fi
        ;;
        desktop)
            if [[ $(awk 'BEGIN { print ('"${I_DB_VERSION}"' < 9.5) ? "y" : "n" }') = "y" ]]; then
                o_checkpoint_segments=3
            else
                o_min_wal_size=$(( 100 * SIZE_MB / SIZE_KB ))
                o_max_wal_size=$(( 1024 * SIZE_MB / SIZE_KB ))
            fi
        ;;
        mixed)
            if [[ $(awk 'BEGIN { print ('"${I_DB_VERSION}"' < 9.5) ? "y" : "n" }') = "y" ]]; then
                o_checkpoint_segments=32
            else
                o_min_wal_size=$(( 1024 * SIZE_MB / SIZE_KB ))
                o_max_wal_size=$(( 2048 * SIZE_MB / SIZE_KB ))
            fi
        ;;
    esac
}

getMaxConnection
getSharedBuffers
getEffectiveCacheSize
getMaintenanceWorkMem
getCheckpointCompletionTarget
getWalBuffers
getDefaultStatisticsTarget
getRandomPageCost
getEffectiveIoConcurrency
getWorkMem
getCheckpointSegments

if [[ -n ${I_OUTPUT} ]] && [[ -z ${I_REPLACE} ]]; then
    truncate -s 0 "${I_OUTPUT}"
fi

for out in "${output_list[@]}"; do
    tmp="o_${out}"
    if [[ $(awk 'BEGIN { print ('"${!tmp}"' > 0) ? "y" : "n" }') = "y" ]]; then
        if [[ -n ${I_OUTPUT} ]] && [[ -z ${I_REPLACE} ]]; then
            echo "${out} = $(formatValue "${!tmp}")" >> "${I_OUTPUT}"
#        elif [[ -n ${I_OUTPUT} ]] && [[ -n ${I_REPLACE} ]]; then
#            echo 1
        else
            echo "${out} = $(formatValue "${!tmp}")"
        fi
    fi
done