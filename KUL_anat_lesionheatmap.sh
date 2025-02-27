#!/bin/bash
# Bash shell script to create a lesion heat map after KUL_anat_segment_tumor
#
# Requires ants
#
# @ Stefan Sunaert - UZ/KUL - stefan.sunaert@uzleuven.be
# 01/05/2022
version="0.1"

kul_main_dir=$(dirname "$0")
script=$(basename "$0")
source $kul_main_dir/KUL_main_functions.sh
# $cwd & $log_dir is made in main_functions

fix_im="$kul_main_dir/atlasses/Ganzetti2014/mni_icbm152_t1_tal_nlin_sym_09a.nii"

# FUNCTIONS --------------

# function Usage
function Usage {

cat <<USAGE

`basename $0` create a lesion heat map after KUL_anat_segment_tumor
    and running the anatomical workflow of fmriprep (for MNI normalisation)

Usage:

  `basename $0` <OPT_ARGS>

Example:

  `basename $0` -p JohnDoe

Required arguments:

     -p:  names of participants to include in heatmap (put them between "")

    OR

     -a:  run on all in BIDS folder

Optional arguments:

     -c:  use the VBG output instead of native lesioned brains for MNI registration
     -n:  number of cpu to use (default 15)
     -v:  show output from commands (0=silent, 1=normal, 2=verbose; default=1)

USAGE

	exit 1
}


# CHECK COMMAND LINE OPTIONS -------------
#
# Set defaults
silent=1 # default if option -v is not given
ants_verbose=1
ncpu=15
verbose_level=1
run_all=0
use_vbg=0 

# Set required options
p_flag=0
d_flag=0

if [ "$#" -lt 1 ]; then
	Usage >&2
	exit 1

else

	while getopts "p:a:n:v:c" OPT; do

		case $OPT in
		p) #participant
			participants=($OPTARG)
            p_flag=1
		;;
        a) #all
			run_all=$OPTARG
		;;
        c) #use_vbg
			use_vbg=1
		;;
        n) #ncpu
			ncpu=$OPTARG
		;;
        v) #verbose
            verbose_level=$OPTARG
		;;
        \?)
			echo "Invalid option: -$OPTARG" >&2
			echo
			Usage >&2
			exit 1
		;;
		:)
			echo "Option -$OPTARG requires an argument." >&2
			echo
			Usage >&2
			exit 1
		;;
		esac

	done

fi

# check for required options
if [ $p_flag -eq 0 ] ; then
    echo
    echo "Option -p is required: give the BIDS name of the participant." >&2
    echo
    exit 2
fi

KUL_LOG_DIR="KUL_LOG/${script}/sub-${participant}"
mkdir -p $KUL_LOG_DIR

# MRTRIX and others verbose or not?
if [ $verbose_level -lt 2 ] ; then
	export MRTRIX_QUIET=1
    silent=1
    str_silent=" > /dev/null 2>&1" 
    ants_verbose=0
elif [ $verbose_level -eq 2 ] ; then
    silent=0
    str_silent="" 
    ants_verbose=1
fi


# --- MAIN ---

# STEP 1 - SETUP
heat1=""
heat2=""
heat3=""
heat4=""

for participant in ${participants[@]}; do

    echo "Registering $participant to MNI"

    # register to MNI
    wd=$cwd/BIDS/derivatives/KUL_compute/sub-${participant}/KUL_anat_register_mni
    lesion1_test="RESULTS/sub-${participant}/Lesionmap/sub-${participant}_lesion_and_cavity_corr1.nii.gz"
    if [ -f $lesion1_test ]; then 
        lesion1=$lesion1_test
        lesion1_label=lesion_and_cavity_corr1
    else
        lesion1="RESULTS/sub-${participant}/Lesion/sub-${participant}_lesion_and_cavity.nii.gz"
        lesion1_label=lesion_and_cavity
    fi

    lesion1a_test="RESULTS/sub-${participant}/Lesionmap/sub-${participant}_lesion_and_cavity_corr2.nii.gz"
    if [ -f $lesion1a_test ]; then 
        lesion1a=$lesion1a_test
        lesion1a_label=lesion_and_cavity_corr2
    else
        lesion1a=$lesion1
        lesion1a_label=$lesion1_label
    fi

    lesion2_test="RESULTS/sub-${participant}/Lesion/sub-${participant}_hdglio_lesion_perilesional_tissue_corr1.nii.gz"
    if [ -f $lesion2_test ]; then 
        lesion2=$lesion2_test
        lesion2_label=hdglio_lesion_perilesional_tissue_corr1
    else
        lesion2="RESULTS/sub-${participant}/Lesion/sub-${participant}_hdglio_lesion_perilesional_tissue.nii.gz"
        lesion2_label=hdglio_lesion_perilesional_tissue
    fi

    lesion3_test="RESULTS/sub-${participant}/Lesion/sub-${participant}_hdglio_lesion_total_corr1.nii.gz"
    if [ -f $lesion3_test ]; then 
        lesion3=$lesion3_test
        lesion3_label=hdglio_lesion_total_corr1
    else
        lesion3="RESULTS/sub-${participant}/Lesion/sub-${participant}_hdglio_lesion_total.nii.gz"
        lesion3_label=hdglio_lesion_total
    fi

    lesion4_test="RESULTS/sub-${participant}/Lesion/sub-${participant}_resseg_cavity_only_corr1.nii.gz"
    if [ -f $lesion4_test ]; then 
        lesion4=$lesion4_test
        lesion4_label=resseg_cavity_only_corr1
    else
        lesion4="RESULTS/sub-${participant}/Lesion/sub-${participant}_resseg_cavity_only.nii.gz"
        lesion4_label=resseg_cavity_only
    fi

    if [ $use_vbg -eq 1 ]; then
        T1w=VBG_out/output_VBG/sub-${participant}/sub-${participant}_T1_nat_filled.nii.gz
    else
        T1w=BIDS/sub-${participant}/ses-study/anat/sub-${participant}_ses-study_T1w.nii.gz
    fi

    KUL_anat_register.sh \
        -t /usr/local/KUL_apps/KUL_NIS/atlasses/Ganzetti2014/mni_icbm152_t1_tal_nlin_sym_09a.nii \
        -s $T1w \
        -d $wd \
        -w -m 1 -i 2 \
        -o "$lesion1 $lesion1a $lesion2 $lesion3 $lesion4"

    map_d="BIDS/derivatives/KUL_compute/sub-${participant}/KUL_anat_register_mni/"
    map1="$map_d/sub-${participant}_${lesion1_label}_reg2_mni_icbm152_t1_tal_nlin_sym_09a.nii.gz"
    map1a="$map_d/sub-${participant}_${lesion1a_label}_reg2_mni_icbm152_t1_tal_nlin_sym_09a.nii.gz"
    map2="$map_d/sub-${participant}_${lesion2_label}_reg2_mni_icbm152_t1_tal_nlin_sym_09a.nii.gz"
    map3="$map_d/sub-${participant}_${lesion3_label}_reg2_mni_icbm152_t1_tal_nlin_sym_09a.nii.gz"
    map4="$map_d/sub-${participant}_${lesion4_label}_reg2_mni_icbm152_t1_tal_nlin_sym_09a.nii.gz"
    
    if [ -f $map1 ]; then 
        heat1="$heat1 $map1 "
    fi
    if [ -f $map1a ]; then 
        heat1a="$heat1a $map1a "
    fi
    if [ -f $map2 ]; then 
        heat2="$heat2 $map2 "
    fi
    if [ -f $map3 ]; then 
        heat3="$heat3 $map3 "
    fi
    if [ -f $map4 ]; then 
        heat4="$heat4 $map4 "
    fi

done

kulderivativesdir=BIDS/derivatives/KUL_compute/KUL_anat_lesionheatmap
mkdir -p $kulderivativesdir
mrmath $heat1 sum $kulderivativesdir/lesionheatmap_lesion_and_cavity1.nii.gz -force
echo $heat1a
mrmath $heat1a sum $kulderivativesdir/lesionheatmap_lesion_and_cavity2.nii.gz -force
mrmath $heat2 sum $kulderivativesdir/lesionheatmap_hdglio_lesion_perilesional_tissue.nii.gz -force
mrmath $heat3 sum $kulderivativesdir/lesionheatmap_hdglio_lesion_total.nii.gz -force
mrmath $heat4 sum $kulderivativesdir/lesionheatmap_resseg_cavity_only.nii.gz -force


echo "Finished"
