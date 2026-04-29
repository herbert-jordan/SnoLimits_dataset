#!/bin/bash

#SBATCH --ntasks=1
#SBATCH	--cpus-per-task=4
#SBATCH	--time=12:00:00
#SBATCH --qos=normal
#SBATCH --partition=amilan
#SBATCH	--job-name=gen_training_data
#SBATCH --output=snotel_master_%a.out
#SBATCH --array=1-250

module purge
module load matlab/R2023b

COMMAND=$(sed -n "${SLURM_ARRAY_TASK_ID}p" lb_cmd_file)
eval "$COMMAND"