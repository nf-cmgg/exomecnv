// MERGE COUNT FILES
process EXOMEDEPTH_COUNT_MERGE {
    publishDir "$params.outdir/exomedepth/counts", mode: 'copy'

    input:
    tuple val(meta), path(files)

    output:
    tuple val(meta), path("${meta.id}_${meta.chr}.txt")

    script:
    """
    for file in $files; do
        if [ -f ${meta.id}_${meta.chr}.txt ]; then
		paste ${meta.id}_${meta.chr}.txt <(awk '{print \$5}' \$file) > temp_auto.txt
		mv temp_auto.txt ${meta.id}_${meta.chr}.txt
		else
		cp \$file ${meta.id}_${meta.chr}.txt
        fi
    done
    """
}
