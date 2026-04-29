#!/bin/bash

#SBATCH --ntasks=1
#SBATCH	--cpus-per-task=8
#SBATCH	--time=2:00:00
#SBATCH --qos=blanca-geol
#SBATCH	--job-name=gen_models
#SBATCH --output=ML_gen_master_%a.out
#SBATCH --array=1-155

module purge
module load matlab

COMMAND=$(sed -n "${SLURM_ARRAY_TASK_ID}p" lb_cmd_file)
eval "$COMMAND"