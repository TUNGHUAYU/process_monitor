# reference https://man7.org/linux/man-pages/man5/proc.5.html

# << define function >>

function USAGE(){
    echo "usage"
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
                    echo "syntax error"
                    USAGE
                    exit 1
                else
                    case "${target_arg}" in
                        time)
                            time=${arg}
                            target_arg=""
				            ;;

                        period)
                            period=${arg}
                            target_arg=""
                            ;;
                        *)
                            echo "syntax error"
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
		echo $(cat ${cmdline_path} | tr -d '\0')
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

time=${time:-1}
period=${period:-1}
output_dir=${output_dir:-"./output"}

# <<< main >>>

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
printf "%s,%s,\n" "time" "${time}"
printf "%s,%s,\n" "period" "${period}"
} > ${output_dir}/log.txt

# show information
count=0
while  [ ${count} -lt 10 ]
do
    # 
    sleep 1
    {
    echo "count = $count"
    } >> ${output_dir}/log.txt
    count=$(expr ${count} + 1)

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
		printf "%s,%s,\n" "cmd"	${cmdline}		
		printf "%s,%s,%s,\n" "date" "time" "nbr_of_fds" 
		} >> "${output_dir}/${pid}.csv"
	else
		# append cotent to csv file
		printf "%s,%s,%s,\n" "$(date +"%D")" "$(date +"%R:%S")" "${nbr_fds}" >> "${output_dir}/${pid}.csv"
	fi
		
    done 

done

