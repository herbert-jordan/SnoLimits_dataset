#!/bin/bash
#SBATCH --ntasks=1
#SBATCH --time=00:05:00
#SBATCH --qos=normal
#SBATCH --partition=amilan
#SBATCH --job-name=pipeline_456

JOB4=$(sbatch --parsable array_submit4.sh)
echo "Submitted job 4: $JOB4"

JOB5=$(sbatch --parsable --dependency=afterok:$JOB4 array_submit5.sh)
echo "Submitted job 5: $JOB5"

JOB6=$(sbatch --parsable --dependency=afterok:$JOB5 array_submit6.sh)
echo "Submitted job 6: $JOB6"