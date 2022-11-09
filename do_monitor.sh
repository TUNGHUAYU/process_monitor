# reference https://man7.org/linux/man-pages/man5/proc.5.html

# << define function >>

function USAGE(){

    echo "usage $(basename $0) [-t, --time <time>][-p, --period <period>][-h, --help]"
    echo ""
    echo "<time>    : time frame      (uint:s,m,h,d) (default: 1h)"
    echo "<period>  : sampling period (uint:s,m,h,d) (default: 1m)"
}

function FUNC_parse_argument(){

	for arg in $@
	do
		case "${arg}" in
			-h | --help)
				USAGE
				exit 0
				;;

            -t | --time)
                target_arg="time"
                ;;

            -p | --period)
                target_arg="period" 
                ;;
                
			*)
                if [[ -z ${target_arg} ]]; then
                    echo "error: wrong syntax"
                    USAGE
                    exit 1
                else
                    case "${target_arg}" in
                        time)
                            if [[ "${arg}" =~ ^[1-9]+[0-9]*[smhd] ]]; then
                                time=${arg}
                            else 
                                echo "error: ${arg} is illegal <time> value"
                                USAGE
                                exit 2
                            fi
                            target_arg=""
				            ;;

                        period)
                            if [[ "${arg}" =~ ^[1-9]+[0-9]*[smhd] ]]; then
                                period=${arg}
                            else 
								echo "error: ${arg} illegal <period> value"
                                USAGE
                                exit 2
                            fi
                            target_arg=""
                            ;;
                        *)
                            echo "error: wrong syntax"
                            USAGE
                            exit 1
                    esac
                fi
		esac
	done
}

function FUNC_get_total_count(){

	# define local variables
	local time="$1"
	local period="$2"
	local time_sec
	local period_sec
	
	# transform to sec unit
	time_sec=$( 
	echo ${time} | \
	awk -F"[smhd]" \
	'
	/s/{ print $(1) }
	/m/{ print $(1)*60 }
	/h/{ print $(1)*60*60 }
	/d/{ print $(1)*60*60*24 }
	' 
	)
	
	period_sec=$( 
	echo ${period} | \
	awk -F"[smhd]" \
	'
	/s/{ print $(1) }
	/m/{ print $(1)*60 }
	/h/{ print $(1)*60*60 }
	/d/{ print $(1)*60*60*24 }
	' 
	)
	
	# check if time is bigger than period
	echo "time sec ${time_sec}"
	echo "period sec ${period_sec}"
	if [[ ${time_sec} -lt ${period_sec} ]]; then
		echo "time <${time}> should be bigger than period <${period}>"
		USAGE
		exit 3
	fi
	
	# calculate total_count
	total_count=$(expr ${time_sec} / ${period_sec})
	residual=$(expr ${time_sec} % ${period_sec})

	if [[ $residual -ne 0 ]];then
		total_count=$(expr ${total_count} + 1)
	fi

}


function FUNC_get_cmdline(){
	
	local proc_path=$1
	local cmdline_path="${proc_path}/cmdline"
	
	if [[ ! -e ${cmdline_path} ]];then
		echo "not exist"
	elif [[ ! -r ${cmdline_path} ]]; then
		echo "unreadable"
	else
        cat ${cmdline_path} | tr "\0" " "
	fi

}

function FUNC_get_exe(){
	
	local proc_path=$1
	local exe_path="${proc_path}/exe"
	
	if [[ ! -e ${exe_path} ]];then
		echo "not exist"
	elif [[ ! -r ${exe_path} ]]; then 
		echo "unreadable"
	else 
		echo $(ls -l ${exe_path} | awk 'NF==11{print $(NF-2) $(NF-1) $(NF)} NF==9{print $NF" -> (null)"}')
	fi
}

function FUNC_get_nbr_fds(){
	
	local proc_path=$1
	local fd_path="${proc_path}/fd"

	if [[ ! -e ${fd_path} ]];then
		echo "not exist"
	elif [[ ! -r ${fd_path} ]]; then 
		echo "unreadable"
	else 
		echo $(ls ${fd_path} | wc -w)
	fi

}

function FUNC_get_nbr_tasks(){

	local proc_path=$1
	local task_path="${proc_path}/task"

	if [[ ! -e ${task_path} ]];then
		echo "not exist"
	elif [[ ! -r ${task_path} ]]; then 
		echo "unreadable"
	else 
		echo $(ls ${task_path} | wc -w)
	fi

}

function FUNC_get_vmrss(){

	local proc_path=$1
	local status_path="${proc_path}/status"

	if [[ ! -e ${status_path} ]];then
		echo "not exist"
	elif [[ ! -r ${status_path} ]]; then 
		echo "unreadable"
	else 
		echo $(cat ${status_path} | awk '/^VmRSS/{ print $2 }')
	fi

}

# << parse argument >>

if [[ $# -ne 0 ]]; then
	FUNC_parse_argument $@
fi

# << variable setting >>

time=${time:-"1h"}
period=${period:-"1m"}
output_dir=${output_dir:-"/tmp/process_monitor_outputs"}

# <<< main >>>

# calculate total times that shot the process state
FUNC_get_total_count ${time} ${period}

# create a output folder
if [[ -d ${output_dir} ]]; then
    read -p "Directory ${output_dir}/ exist! Overwrite? (y/n) " ans
    if [[ ${ans} == "y" ]] || [[ ${ans} == "yes" ]];then
        rm -rf ${output_dir}
        echo "remove ${output_dir}"
    fi
fi

mkdir ${output_dir}
echo "create ${output_dir}"

touch ${output_dir}/log.txt 
echo "touch ${output_dir}/log.txt"

{
printf "%s,%s,\n" "time"        "${time}"
printf "%s,%s,\n" "period"      "${period}"
printf "%s,%s,\n" "total count" "${total_count} times"
} > ${output_dir}/log.txt

# show information
{
count=0
while  [ ${count} -lt ${total_count} ]
do
    # 
    count=$(expr ${count} + 1)
    {
    printf "%s,%s\n" "count" "${count}/${total_count}"
    } >> ${output_dir}/log.txt

    # get information
    for proc in $(ls -d /proc/[0-9]*)
    do
    	# filter out unavaliable process
    	if [[ ! -e ${proc} ]]; then
    		continue
    	fi
	
	# get process information     	
	pid="${proc##*/}"
	nbr_fds="$(FUNC_get_nbr_fds ${proc})"
	nbr_tasks="$(FUNC_get_nbr_tasks ${proc})"
	vmrss="$(FUNC_get_vmrss ${proc})"
		
	# create/append pid file 
	if [[ ! -f ${output_dir}/${pid}.csv ]];then
	    	
	    # get process information
		exe="$(FUNC_get_exe ${proc})"
	    cmdline="$(FUNC_get_cmdline ${proc})"
		
		# check exe 
		if [[ "${exe}" == "not exist" ]]; then
			continue
		elif [[ "${exe}" == "unreadable" ]]; then
			continue
		fi
		
		# check cmdline and filter "sleep"
		if [[ "${cmdline}" == "not exist" ]]; then
			continue
		elif [[ "${cmdline}" == "unreadable" ]]; then
			continue
		elif [[ "${cmdline}" =~ ^sleep ]]; then
			continue
		fi
		
		# create a blank csv file
	    touch "${output_dir}/${pid}.csv"
	    	
	    # append header to csv file
	    {
	        printf "%s,%s,\n" "pid" "${pid}"
	    	printf "%s,%s,\n" "exe" "${exe}"
	    	printf "%s,%s,\n" "cmd"	"${cmdline}"		
	    	printf "%s,%s,\n" "total count"	"${total_count}"
	    	printf "%s,%s,%s,%s,%s,%s,\n" "date" "time" "count" "nbr_of_fds" "nbr_of_tasks" "vmrss" 
	    	printf "%s,%s,%s,%s,%s,%s,\n" "$(date +"%D")" "$(date +"%R:%S")" "${count}" "${nbr_fds}" "${nbr_tasks}" "${vmrss}"
	    } >> "${output_dir}/${pid}.csv"
	else
	    # append cotent to csv file
		{
		printf "%s,%s,%s,%s,%s,%s,\n" "$(date +"%D")" "$(date +"%R:%S")" "${count}" "${nbr_fds}" "${nbr_tasks}" "${vmrss}"
		} >> "${output_dir}/${pid}.csv"
	fi
		
    done 

    # sleep
    sleep "${period}"

done 

do_analyze.sh

} 2> "${output_dir}/error.txt" &


bg_pid=$!

{
echo ${bg_pid}
} > ${output_dir}/pid.txt
