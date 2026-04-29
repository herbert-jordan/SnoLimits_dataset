#!/bin/bash

#SBATCH --ntasks=1
#SBATCH	--cpus-per-task=1
#SBATCH	--time=4:00:00
#SBATCH --qos=normal
#SBATCH --partition=amilan
#SBATCH	--job-name=gen_test_data
#SBATCH --output=test_data_master_%a.out
#SBATCH --array=1-154

module purge
module load matlab/R2023b

COMMAND=$(sed -n "${SLURM_ARRAY_TASK_ID}p" lb_cmd_file)
eval "$COMMAND"