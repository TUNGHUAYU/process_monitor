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
        rm -r ${output_dir}
        echo "remove ${output_dir}"
    fi
fi

mkdir ${output_dir}
echo "create ${output_dir}"

touch "${output_dir}/monitor_fds.csv"
echo "touch "${output_dir}/monitor_fds.csv""

printf "%s,%s\n" "pid" "exe" > "${output_dir}/monitor_fds.csv" 

# print header
format="%-10s: %s\n"
printf "${format}" "Begin"  "$(date +"%Y/%m/%d %R")"
printf "${format}" "Period" "${period}"

# show information
count=0
while  [ ${count} -lt 1 ]
do
    # 
    sleep 1
    echo "count = $count"
	count=$(expr ${count} + 1)

    # get information
    for proc in $(ls -d /proc/[0-9]*)
    do
    	# filter out unavaliable process
    	if [[ ! -e ${proc} ]]; then
    		continue
    	fi
    	
    	pid_array="${pid_array} ${proc##*/}"
    	cmdline_array="${cmdline_array} $(FUNC_get_cmdline ${proc})"
        exe_array="${exe_array} $(FUNC_get_exe ${proc})"
    	nbr_fds_array="${nbr_fds_array} $(FUNC_get_nbr_fds ${proc})"
    	nbr_tasks_array="${nbr_tasks_array} $(FUNC_get_nbr_tasks ${proc})"

    done 

    
    awk \
    -v pid_array="${pid_array}" \
    -v exe_array="${exe_array}" \
    -v nbr_fds_array="${nbr_fds_array}" \
    '
	function my_asorti(arr, n){
		
		# define indeces and _arr
		for( i=1; i<=n; i++ ){
			indeces[i]=i
			_arr[i]=arr[i]
		}
		
		# do bubble sort
		for( i=1; i<=n-1; i++ ){
			for( j=1; j<=n-i; j++){
				if ( _arr[j] > _arr[j+1] ){
				
					temp = indeces[j]
					indeces[j] = indeces[j+1]
					indeces[j+1] = temp
					
					temp = _arr[j]
					_arr[j] = _arr[j+1]
					_arr[j+1] = temp
				}
			}
		}
		
		return indeces
	}
	
    BEGIN{
        FS=","
        n = split(pid_array, pid_arr, " ")
        n = split(exe_array, exe_arr, " ")
        n = split(nbr_fds_array, nbr_fds_arr, " ")
    }

    NR==1{
        
        if ( NF == 2 ){
           header = sprintf("%s,%s\n", $0, 0)
        } else {
           header = sprintf("%s,%s\n", $0, $NF + 1)
        }
		
    }

    NR>1{
        idx = NR - 1 
        line[idx] = $0
    }

    END{
        print header
			
		format="%s"
		
		i=1
		while ( i < NF+1 ){
			format=sprintf("%s,%s", format, "%s");
			i = i + 1
		}
		format=sprintf("%s\n", format);
		
		i=1
		while ( i <= n ){
			printf(format, pid_arr[i], exe_arr[i], nbr_fds_arr[i])
			i = i+1
		}
		
    }
    ' "${output_dir}/monitor_fds.csv" #> "${output_dir}/monitor_fds.csv.temp"
    #cp "${output_dir}/monitor_fds.csv.temp" "${output_dir}/monitor_fds.csv"

    # reset array
    unset pid_array
    unset cmdline_array
    unset exe_array
    unset nbr_fds_array
    unset nbr_tasks_array

done

