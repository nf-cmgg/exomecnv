// MERGE COUNT FILES
process EXOMEDEPTH_COUNT_MERGE {
    publishDir "$params.outdir/exomedepth/counts", mode: 'copy'

    input:
    tuple val(meta), path(files)

    output:
    tuple val(meta), path("${prefix}.txt")

    script:
    prefix = task.ext.prefix ?: "${meta.id}_${meta.chr}"
    """
    for file in $files; do
        if [ -f ${prefix}.txt ]; then
            paste ${prefix}.txt <(awk '{print \$5}' \$file) > temp_auto.txt
            mv temp_auto.txt ${prefix}.txt
            else
            cp \$file ${prefix}.txt
        fi
    done
    """
}
