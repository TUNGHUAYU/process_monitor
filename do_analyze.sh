# << define function >>

function USAGE(){
    echo "usage do_analyze.sh"
}

function FUNC_parse_argument(){

	for arg in $@
	do
		case "${arg}" in
			-h | --help)
				USAGE
				exit 0
				;;
		esac
	done
}

function FUNC_sort(){
    
    if [[ $# -ne 1 ]]; then
        return 1
    fi

    local src
    local dst
    
    src=$1
    dst=$(echo $src | tr " " "\n" | sort -n | tr "\n" " ")
    
    echo $dst
}


function FUNC_generate_fd_output(){

	# local variables
	local number=${1}
    local input_path=${2}
    local output_path=${3}
	
	# generate header
	if [[ ! -e ${output_path} ]]; then
		# generate format and number array for header
		format="%s,%s,%s,%s" # No. pid exe cmdline
		num_arr=""

		local count=1
		while [ ${count} -le ${total_count} ]
		do
			num_arr="${num_arr} $count"
			format="${format},%s"
			count=$(expr $count + 1)
		done
		
		format="${format}\n"
		
		# print header and redirect to output_path
		printf "${format}" "No." "pid" "exe" "cmdline" ${num_arr} > ${output_path}
	fi

	# cotent generation
    {

		awk -v number=${number} \
		'
		BEGIN{ FS = ","}
		$1=="pid"{ pid=$2; }
		$1=="exe"{ exe=$2; }
		$1=="cmd"{ cmd=$2; }
		
		$1=="total count"{ total_count=$2; }
		(NR>5){
			count = $3
			date[ count ] = $1
			time[ count ] = $2
			nbr_fds[ count ] = $4
			nbr_tasks[ count ] = $5
			vmrss[ count ] = $6
		}
		
		END{
			printf("%s,", number)
			printf("%s,", pid)
			printf("%s,", exe)
			printf("%s,", cmd)
			i=1
			while( i <= total_count ){
				if ( i in nbr_fds ){
					printf("%s,", nbr_fds[i])
				} else {
					printf("%s,", "-")
				}
				i++
			}
			print ""
		}
		' ${input_path}

    } >> ${output_path}

}


function FUNC_generate_vmrss_output(){

	# local variables
	local number=${1}
    local input_path=${2}
    local output_path=${3}
	
	# generate header
	if [[ ! -e ${output_path} ]]; then
		# generate format and number array for header
		format="%s,%s,%s,%s" # No. pid exe cmdline
		num_arr=""

		local count=1
		while [ ${count} -le ${total_count} ]
		do
			num_arr="${num_arr} $count"
			format="${format},%s"
			count=$(expr $count + 1)
		done
		
		format="${format}\n"
		
		# print header and redirect to output_path
		printf "${format}" "No." "pid" "exe" "cmdline" ${num_arr} > ${output_path}
	fi

	# cotent generation
    {

		awk -v number=${number} \
		'
		BEGIN{ FS = ","}
		$1=="pid"{ pid=$2; }
		$1=="exe"{ exe=$2; }
		$1=="cmd"{ cmd=$2; }
		
		$1=="total count"{ total_count=$2; }
		(NR>5){
			count = $3
			date[ count ] = $1
			time[ count ] = $2
			nbr_fds[ count ] = $4
			nbr_tasks[ count ] = $5
			vmrss[ count ] = $6
		}
		
		END{
			printf("%s,", number)
			printf("%s,", pid)
			printf("%s,", exe)
			printf("%s,", cmd)
			i=1
			while( i <= total_count ){
				if ( i in vmrss ){
					printf("%s,", vmrss[i])
				} else {
					printf("%s,", "-")
				}
				i++
			}
			print ""
		}
		' ${input_path}

    } >> ${output_path}

}

# << main >>
if [[ $# -ne 0 ]];then
    FUNC_parse_argument $@
fi


# define directory path
work_dir="/tmp/process_monitor_outputs"
report_dir="${work_dir}/report"

# make folder and related file
if [[ -d ${report_dir} ]];then
    read -p "${report_dir} already existed. overwrite?(y/n) " ans
    if [[ ${ans} == "y" ]] || [[ ${ans} == "yes" ]]; then
        echo "rm -rf ${report_dir}"
        rm -rf ${report_dir}
    fi
fi

echo "mkdir ${report_dir}"
mkdir ${report_dir}

# get monitor output for each process
# sort file name by ascending value
files=$(ls ${work_dir}/[0-9]*.csv)
files=${files//${work_dir}\//}   # replace all "${work_dir}/" to ""
sorted_files="$(FUNC_sort "${files}")"

# get the total count info
total_count=$(cat ${work_dir}/log.txt | awk \
'
BEGIN{
    FS=","
}
{
    if ( $1 == "total count" ){
        split($0, a, "[ ,]");
        print a[3]
    }
}
'
)

# output information
i=1
for file in ${sorted_files}
do
    file_path="${work_dir}/${file}"

    FUNC_generate_fd_output ${i} ${file_path} "${report_dir}/monitor_fd_list.csv"
	FUNC_generate_vmrss_output ${i} ${file_path} "${report_dir}/monitor_vmrss_list.csv"
	
	i=$(expr $i + 1)
done
