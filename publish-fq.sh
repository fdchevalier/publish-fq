#!/bin/bash
# Title: publish-fq.sh
# Version: 0.1
# Author: Frédéric CHEVALIER <fcheval@txbiomed.org>
# Created in: 2016-11-05
# Modified in: 2017-04-18
# License : GPL v3



#======#
# Aims #
#======#

aim="Publish fastq files the \"old Casava way\" (by samples or by projects)."



#==========#
# Versions #
#==========#

# v0.1 - 2017-04-18: Flow cell ID automatically set / samplesheet file copy / auto clean
# v0.0 - 2016-11-05: creation

version=$(grep -i -m 1 "version" "$0" | cut -d ":" -f 2 | sed "s/^ *//g")



#===========#
# Functions #
#===========#

# Usage message
function usage {
    echo -e "
    \e[32m ${0##*/} \e[00m -d|--dir bcl2fq_dir -s|--ss samplesheet -o|--dest destination_dir -p|--pjt -l|--spl -e|--em user_list -h|--help

Aim: $aim

Version: $version

Options:
    -d, --dir       path to the output directory of bcl2fq containing the fastq files, the reports and stats folders
    -s, --ss        path to the samplesheet
    -o, --dest      path to the destination directory [default: MYPATH]
    -p, --pjt       by project publishing \e[31m[Incompatible with -l]\e[00m
    -l, --spl       by sample publishing \e[31m[Incompatible with -p]\e[00m [default]
    -e, --em        list of user to which send an email when publishing is done
                        The list must be space separated (eg, -e brad janet) [default: janet]
    -h, --help      this message
    "
}


# Info message
function info {
    if [[ -t 1 ]]
    then
        echo -e "\e[32mInfo:\e[00m $1"
    else
        echo -e "Info: $1"
    fi
}


# Warning message
function warning {
    if [[ -t 1 ]]
    then
        echo -e "\e[33mWarning:\e[00m $1"
    else
        echo -e "Warning: $1"
    fi
}


# Error message
## usage: error "message" exit_code
## exit code optional (no exit allowing downstream steps)
function error {
    if [[ -t 1 ]]
    then
        echo -e "\e[31mError:\e[00m $1"
    else
        echo -e "Error: $1"
    fi

    if [[ -n $2 ]]
    then
        exit $2
    fi
}


# Dependency test
function test_dep {
    which $1 &> /dev/null
    if [[ $? != 0 ]]
    then
        error "Package $1 is needed. Exiting..." 1
    fi
}


# Progress bar
## Usage: ProgressBar $mystep $myend
function ProgressBar {
    if [[ -t 1 ]]
    then
        # Process data
        let _progress=(${1}*100/${2}*100)/100
        let _done=(${_progress}*4)/10
        let _left=40-$_done
        # Build progressbar string lengths
        _fill=$(printf "%${_done}s")
        _empty=$(printf "%${_left}s")

        # Build progressbar strings and print the ProgressBar line
        # Output example:
        # Progress : [========================================] 100%
        printf "\r\e[32mProgress:\e[00m [${_fill// /=}${_empty// / }] ${_progress}%%"

        [[ ${_progress} == 100 ]] && echo ""
    fi
}


# Clean up function for trap command
## Usage: clean_up file1 file2 ...
function clean_up {
    rm -rf $@
    exit 1
}



#==============#
# Dependencies #
#==============#

test_dep perl



#===========#
# Variables #
#===========#
#set -x
# Options
while [[ $# -gt 0 ]]
do
    case $1 in
        -d|--dir    ) dir_fq="$2" ; shift 2 ;;
        -s|--ss     ) samplesheet="$2" ; shift 2 ;;
        -o|--dest   ) dir_out="${2}" ; shift 2 ;;
        -p|--pjt    ) pjt="project" ; shift ;;
        -l|--spl    ) spl="sampple" ; shift ;;
        -e|--em     ) myemails="$2" ; shift 2
                        while [[ ! -z "$1" && $(echo "$1"\ | grep -qv "^-" ; echo $?) == 0 ]]
                        do
                            myemails="$myemails $1"
                            shift
                        done ;;
        -h|--help   ) usage ; exit 0 ;;
        *           ) error "Invalid option: $1\n$(usage)" 1 ;;
    esac
done


# Check the existence of obligatory options
if [[ -z "$dir_fq" ]]
then
    error "The -d option is required. Exiting...\n$(usage)" 1
elif [[ -z "$samplesheet" ]]
then
    error "The -s option is required. Exiting...\n$(usage)" 1
fi

if [[ -n $pjt && -n $spl ]]
then
    error "The -p and -l options cannot be used at the same time. Exiting..." 1
elif [[ -z $pjt && -z $spl ]]
then
    #pjt="project"
    spl="sample"
fi

[[ -n $spl ]] && myout_type="sample" || myout_type="project"


# Set default value for output directory
[[ -z "$dir_out" ]] && dir_out=MYPATH

# Append domain extension for emails
if [[ -n "$myemails" ]]
then
    myemails=$(echo $myemails | sed "s/ /@txbiomed.org /g; s/$/@txbiomed.org/g")
fi

# Set counter
count=1



#============#
# Processing #
#============#

info "The fastq files will be published by $myout_type."

# List fastq files
list_fq=$(find "$dir_fq" -type f -name *.fastq*)

# Get flowcell ID and output directory
FC_ID=$(grep -m 1 -i "flowcell" "$dir_fq/Reports/html/index.html" | perl -pe "s,.*src=.(.*?)/.*,\1,")
dir_out="${dir_out%%/}/${FC_ID}"

if [[ -z $FC_ID ]]
then
    error "Flowcell ID not set. It the Reports directory present? Exiting..." 1
else
    info "Flowcell ID $FC_ID"
fi

# Check if dir_out exists
[[ -d "$dir_out" ]] && error "Output directory $dir_out exists already. Exiting... " 1


#------------------#
# Samplesheet info #
#------------------#

# Identify the first line of the [Data] section
data_ln=$(grep -in "^\[data\]" "$samplesheet" | cut -d ":" -f 1)

# Extract the data section
data_sec=$(tail -n +${data_ln} "$samplesheet")

# Extract the header line
header_ln=$(echo "$data_sec" | grep -ni "index" | cut -d ":" -f 1)

# Extract index and lane column number
index_cln=$(echo "$data_sec" | sed -n "${header_ln}p" | sed "s/,/\n/g" | grep -ni "index" | cut -d ":" -f 1)
lane_cln=$(echo "$data_sec" | sed -n "${header_ln}p" | sed "s/,/\n/g" | grep -ni "lane" | cut -d ":" -f 1)
sample_cln=$(echo "$data_sec" | sed -n "${header_ln}p" | sed "s/,/\n/g" | grep -ni "sample_id" | cut -d ":" -f 1)
project_cln=$(echo "$data_sec" | sed -n "${header_ln}p" | sed "s/,/\n/g" | grep -ni "project" | cut -d ":" -f 1)

# Check for uniqueness of each column
[[ $(echo $index_cln | tr " " "\n" | wc -l) != 1 ]] && error "Index column cannot be identified properly (none or more than one). Exiting..." 1
[[ $(echo $lane_cln | tr " " "\n" | wc -l) != 1 ]] && error "Lane column cannot be identified properly (none or more than one). Exiting..." 1
[[ $(echo $sample_cln | tr " " "\n" | wc -l) != 1 ]] && error "Sample_ID column cannot be identified properly (none or more than one). Exiting..." 1
[[ $(echo $project_cln | tr " " "\n" | wc -l) != 1 ]] && error "Project column cannot be identified properly (none or more than one). Exiting..." 1

# Refine data section to remove header lines
((header_ln++))
data_sec=$(echo "$data_sec" | tail -n +${header_ln})


#----------------#
# By lane/sample #
#----------------#
#set -x
if [[ -n $spl ]]
then

    # Get index list
    mysamples=$(echo "$data_sec" | cut -d "," -f $sample_cln | sort | uniq)
    mysamples_lg=$(echo "$mysamples" | wc -l)

    # Treat each sample
    for i in $(echo "$data_sec" | cut -d "," -f $sample_cln | sort | uniq)
    do
        # Get all lines corresponding to the sample (if split in several lanes for instance)
        sample_sec=$(echo "$data_sec" | awk -v sample_cln=$sample_cln -v i=$i -F "," '$sample_cln == i {print $0}')

        for j in $(echo "$sample_sec" | cut -d "," -f $lane_cln)
        do
            # Create dir_out/Lane_sample
            mkdir -p "$dir_out/Lane${j}_${i}"

            # Move any fastq corresponding to lane and sample in this directory (for test do touch only)
            mv -t "$dir_out/Lane${j}_${i}" $(echo "$list_fq" | grep "${i}_.*_L00${j}")
            #eval touch "$dir_out/Lane${j}_${i}/{$(echo "$list_fq" | grep "${i}_.*_L00${j}" | sed "s,.*/,,g" | tr "\n" ",")}"
        done

        ProgressBar $count $mysamples_lg

        ((count++))
    done
    
    # Copy sample sheet in the output directory
    cp -a "$samplesheet" "$dir_out/$(basename "$samplesheet")"

fi


#------------#
# By project #
#------------#

if [[ -n $pjt ]]
then

    # Get index list
    myindexes=$(echo "$data_sec" | cut -d "," -f $index_cln | sort | uniq)
    myindexes_lg=$(echo "$myindexes" | wc -l)

    # Treat each index (ie, Project)
    for i in $myindexes
    do
        # Get all lines corresponding to the indexes (if split in several lanes for instance)
        sample_sec=$(echo "$data_sec" | awk -v index_cln=$index_cln -v i=$i -F "," '$index_cln == i {print $0}')

        for j in $(echo "$sample_sec" | cut -d "," -f $sample_cln)
        do
            # Create dir_out/Lane_sample
            mkdir -p "$dir_out/Project_${count}/Sample_${j}"

            # List lanes corresponding to the sample
            lane_lst=$(echo "$sample_sec" | awk -v sample_cln=$sample_cln -v lane_cln=$lane_cln -v j=$j -F "," '$sample_cln == j {print $lane_cln}')

            for k in $lane_lst
            do
                # Move any fastq corresponding to lane and sample in this directory (for test do touch only)
                #mv -t "$dir_out/Lane${j}_${i}" $(echo "$list_fq" | grep "${i}_.*_L00${j}")
                eval touch "$dir_out/Project_${count}/Sample_${j}/{$(echo "$list_fq" | grep "${j}_.*_L00${k}" | sed "s,.*/,,g" | tr "\n" ",")}"
            done
        done

        ProgressBar $count $myindexes_lg

        ((count++))
    done
    
    # Copy sample sheet in the output directory
    cp -a "$samplesheet" "$dir_out/$(basename "$samplesheet")"

fi


#--------------------------#
# Export Reports and Stats #
#--------------------------#

if [[ ! -e "$dir_fq/Reports" ]]
then
    warning "Reports folder not found."
elif [[ ! -e "$dir_fq/Stats" ]]
then
    warning "Stats folder not found."
else
    tar -czf "$dir_out/Reports & Stats.tar.gz" -C "$dir_fq" "Reports" "Stats"
fi


#-------#
# Email #
#-------#

email_tmpl="$(dirname "$0")/email_template"

if [[ -n "$myemails" && ! -s "$email_tmpl" ]]
then
    error "Email template $email_tmpl does not exist or is empty. Skipping email step..."
elif [[ -n "$myemails" ]]
then
    for i in $myemails
    do
        eval "cat <<< \"$(<"$email_tmpl")\"" | mail -s "Sequencing data available" -c janet@txbiomed.org $i
    done
fi


#----------#
# Clean up #
#----------#

clean_up "$dir_fq"

exit 0
