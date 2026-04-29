#!/bin/bash

#SBATCH --ntasks=1
#SBATCH	--cpus-per-task=3
#SBATCH	--time=06:00:00
#SBATCH --qos=blanca-geol
#SBATCH	--job-name=gen_mults
#SBATCH --output=mults_master_%a.out
#SBATCH --array=1-25

module purge
module load matlab/R2023b

COMMAND=$(sed -n "${SLURM_ARRAY_TASK_ID}p" lb_cmd_file)
eval "$COMMAND"