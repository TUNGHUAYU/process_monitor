# reference https://man7.org/linux/man-pages/man5/proc.5.html

# << define function >>

function USAGE(){
    echo "usage process_monitor.sh [-t, --time <time>][-p, --period <period>][-h, --help]"
    echo ""
    echo "<time>    : total time for monitoring process state   (uint:hr) (default: 1hr)"
    echo "<period>  : sampling rate                             (uint:min)(default: 1min)"
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
                            if [[ ${arg} -le 0 ]]; then
                                echo "error: illegal <time> value"
                                USAGE
                                exit 2
                            else 
                                time=${arg}
                            fi
                            target_arg=""
				            ;;

                        period)
                            if [[ ${arg} -le 0 ]]; then
                                echo "error: illegal <period> value"
                                USAGE
                                exit 2
                            else 
                                period=${arg}
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

function FUNC_get_cmdline(){
	
	local proc_path=$1
	local cmdline_path="${proc_path}/cmdline"
	
	if [[ ! -e ${cmdline_path} ]];then
		echo "not_found"
	elif [[ ! -r ${cmdline_path} ]]; then
		echo "permission_denied"
	else
        cat ${cmdline_path} | \
        awk \
        '
        BEGIN{
            FS='\0'
        }
        {
            for(i=1; i<=NF; i++){ 
                printf("%s ", $i);
            } 
        }
        '
	fi

}

function FUNC_get_exe(){
	
	local proc_path=$1
	local exe_path="${proc_path}/exe"
	
	if [[ ! -e ${exe_path} ]];then
		echo "not_found"
	elif [[ ! -r ${exe_path} ]]; then 
		echo "permission_denied"
	else 
		echo $(ls -l ${exe_path} | awk 'NF==11{print $(NF-2) $(NF-1) $(NF)} NF==9{print $NF" -> (null)"}')
	fi
}

function FUNC_get_nbr_fds(){
	
	local proc_path=$1
	local fd_path="${proc_path}/fd"

	if [[ ! -e ${fd_path} ]];then
		echo "not_found"
	elif [[ ! -r ${fd_path} ]]; then 
		echo "permission_denied"
	else 
		echo $(ls ${fd_path} | wc -w)
	fi

}

function FUNC_get_nbr_tasks(){

	local proc_path=$1
	local task_path="${proc_path}/task"

	if [[ ! -e ${task_path} ]];then
		echo "not_found"
	elif [[ ! -r ${task_path} ]]; then 
		echo "permission_denied"
	else 
		echo $(ls ${task_path} | wc -w)
	fi

}


# << parse argument >>

if [[ $# -ne 0 ]]; then
	FUNC_parse_argument $@
fi

# << variable setting >>

sh_pid="$$"
time=${time:-1}
period=${period:-1}
output_dir=${output_dir:-"./output"}

# <<< main >>>

# calculate total times that shot the process state
total_count=$(expr ${time} \* 60 / ${period})
residual=$(expr ${time} \* 60 % ${period})

if [[ $residual -ne 0 ]];then
    total_count=$(expr ${total_count} + 1)
fi

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
printf "%s,%s\n"  "pid"         "${sh_pid}"
printf "%s,%s,\n" "time"        "${time} hr"
printf "%s,%s,\n" "period"      "${period} min"
printf "%s,%s,\n" "total count" "${total_count} times"
} > ${output_dir}/log.txt

# show information
count=0
while  [ ${count} -lt ${total_count} ]
do
    # 
    sleep 1
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
		
	    # create/append pid file 
	    if [[ ! -f ${output_dir}/${pid}.csv ]];then
	    	
	    	# get process information
	        cmdline="$(FUNC_get_cmdline ${proc})"
           	exe="$(FUNC_get_exe ${proc})"
           	 	
           	# create a blank csv file
	    	touch "${output_dir}/${pid}.csv"
	    	
	    	# append header to csv file
	    	{
	    	printf "%s,%s,\n" "pid" ${pid} 
	    	printf "%s,%s,\n" "exe" ${exe}
	    	printf "%s,%s,\n" "cmd"	"${cmdline}"		
	    	printf "%s,%s,%s,%s,\n" "date" "time" "count/total_count" "nbr_of_fds" 
	    	printf "%s,%s,%s,%s,\n" "$(date +"%D")" "$(date +"%R:%S")" "${count}/${total_count}" "${nbr_fds}" 
	    	} >> "${output_dir}/${pid}.csv"
	    else
	    	# append cotent to csv file
	    	printf "%s,%s,%s,%s,\n" "$(date +"%D")" "$(date +"%R:%S")" "${count}/${total_count}" "${nbr_fds}" >> "${output_dir}/${pid}.csv"
	    fi
		
    done 

done 2> "${output_dir}/error.txt" &
