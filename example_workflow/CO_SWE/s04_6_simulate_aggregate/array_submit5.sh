#!/bin/bash

#SBATCH --ntasks=1
#SBATCH	--cpus-per-task=3
#SBATCH	--time=04:00:00
#SBATCH --qos=normal
#SBATCH --partition=amilan
#SBATCH	--job-name=agg_50m_data
#SBATCH --output=snotel_master_%a.out
#SBATCH --array=1-100

module purge
module load matlab/R2023b

COMMAND=$(sed -n "${SLURM_ARRAY_TASK_ID}p" lb_cmd_file5)
eval "$COMMAND"
