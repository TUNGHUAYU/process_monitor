# === function implementation ===

function USAGE(){
	echo ""
    echo "usage: $(basename $0) [-n, --nth_proc <n-th process>] [-h, --help]"
	echo "<n-th process>: the first n biggest process of memory occupied"
	echo ""
	echo "e.g."
	echo "sh $(basename $0) 		# display first 3 biggest process of memory occupied"
	echo "sh $(basename $0) -n 10 	# display first n=10 biggest process of memory occupied"
}

function FUNC_parse_argument(){

    # check number of argument
    if [[ $# -lt 0 && $# -gt 2 ]]; then
        USAGE
        exit 1
    fi

    # parse argument
    for arg in $@
    do
        case "${arg}" in 
            -h | --help )
                USAGE
                exit 0
                ;;
            -n | --nth_proc )
                target_arg="nth_proc"
                ;;
        esac

        if [[ ${target_arg} == "nth_proc" ]]; 
        then
            number=${arg}
        fi

    done

}

# === main process ===

# parse argument
FUNC_parse_argument $@

# get the external argument
number=${number:-3}


# list all processes including "status" file to "list.txt"
{

# print header 
printf "%-30s %-9s %-20s\n" "name" "pid" "vmrss"
printf "%61s\n" ""

for status in /proc/[0-9]*/status
do
			
	if [[ ! -e ${status} ]];then
		continue
	fi
			
	awk \
	'
	{
			if ( $0 ~ /^Name/ ){
					name = $2
			}

			if ( $0 ~ /^Pid/ ) {
					pid = $2
			}

			if ( $0 ~ /^VmRSS/ ){
					vmrss = $2
			}
	}
	END{
		for( i=0; i<=n; i++ ){
			if ( vmrss ~ /^[0-9]+$/ ){
				printf "%-30s %-9s %-20s\n", name, pid, vmrss
			}
		}
	}
	' ${status}
done

} > list.txt 



# parse "list.txt" and sort descending order
{

awk \
'
BEGIN{
	n=1
}
NR > 2{
	name[n] = $1
	pid[n]  = $2
	vmrss[n] = $3

	n = n + 1
}
END{
	
	len = length(vmrss)

	for ( i=1; i<=len; i++ ){
		idx[i] = i
		arr[i] = vmrss[i]
	}

	for ( i=1; i<=len-1; i++ ){
		for ( j=1; j<=len-i; j++ ){
			if ( arr[j] < arr[j+1]){
				tmp = arr[j]
				arr[j] = arr[j+1]
				arr[j+1] = tmp
				
				tmp = idx[j]
				idx[j] = idx[j+1]
				idx[j+1] = tmp
			}
		}
	}
	
	for ( i=1; i<=len; i++ ){
		printf "%-30s %-9s %-20s\n", name[ idx[i] ], pid[ idx[i] ], vmrss[ idx[i] ]
	}
}
' list.txt

} > proc_vmrss_rank.txt

# display first n-th rows
printf "%-30s %-9s %-20s\n" "name" "pid" "vmrss"
cat proc_vmrss_rank.txt | head -n ${number}

# remove "list.txt"
rm list.txt
rm proc_vmrss_rank.txt