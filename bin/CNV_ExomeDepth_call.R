#!/usr/bin/env Rscript

############################################################################################
### ExomeDepth - CNV calling                                               							 ###
############################################################################################

### load libs ###
library("methods") # to load the function "as"
library("ExomeDepth")
ExomeDepthVersion <- packageDescription("ExomeDepth")$Version
print(paste0("...loaded ExomeDepth version: ", ExomeDepthVersion))

args = commandArgs(trailingOnly = TRUE)
print_usage <- function() {
    cat("Usage: CNV_ExomeDepth_call.R <samplename_test> <countfile> <exon_target> <prefix> <sample_ids> <families_ids>\n")
}
if (length(commandArgs(trailingOnly = TRUE)) != 6) {
    print_usage()
    q("no", status = 1) # Terminate the script with an error status
}

cnv_call_header = c("start.p", "end.p", "type", "nexons", "start", "end", "chromosome", "id", "BF", "reads.expected", "reads.observed", "reads.ratio", "exons")
sampleName <- unlist(args[1]) #sample id
countfile <- unlist(args[2]) #count matrix
exon_target <- unlist(args[3]) #exon target bed file
prefix <- unlist(args[4]) #prefix for output name
sampleNames <- unlist(strsplit(args[5] , ","))
families <- unlist(strsplit(args[6] , ",")) #familie ids for samples

cat("samplename: ", sampleName, "\n")
cat("count file: ", countfile, "\n")
cat("exon target file: ", exon_target, "\n")
cat("prefix: ", prefix, "\n")
cat("sample ids pool: ", sampleNames, "\n")
cat("family ids for samples: ", families, "\n")

### load exon data ###
exons <- read.table(file=exon_target,sep="\t",header = F)
colnames(exons) <- c("chromosome","start","end","name")
# head(exons)

### load all exon info ####
exons.GRanges <- GenomicRanges::GRanges(seqnames = exons$chromosome,
        IRanges::IRanges(start=exons$start,end=exons$end),
        names = exons$name
        )

# ### read counts ###
cat("\nRead counting matrix\n")
ExomeCount.dafr <- read.table(file=countfile,sep="\t",header = TRUE)
# print(head(ExomeCount.dafr))
# colnames(ExomeCount.dafr)

### Call CNVs ###
## build the most appropiate reference set: aggregated reference set
## key idea: build optimized set of exomens that are well correlated with that exome

## prepare the main matrix of read count data
countmat = as.matrix(ExomeCount.dafr[,5:dim(ExomeCount.dafr)[2]]) # remove cols 1-4 metadata
nsamples <- ncol(countmat)
# print(head(countmat))

## check if test sample is part of count matrix
if (is.element(sampleName, colnames(countmat))){
    print(paste(sampleName, "is part of the count matrix"))
} else{
    stop(paste("An error occurred:", sampleName, "is NOT part of the count matrix\n\n"))
}

for (i in 1:nsamples) {

    ## select sample-id
    sample = colnames(countmat)[i]

    # print(paste(sample,i,families[sample_index]))
    # print(sampleNames[families != families[sample_index]])

    ## only CNV calling for input test sample
    if (sample == sampleName) {

        sample_index <- which(sampleNames == sample)

        ## perform CNV calling for the test sample
        cat("\n*** CNV calling for",sample,"***\n")

        ## build reference set (pool = all other samples of run)
        cat("\nSelecting reference samples from pool:\n")
        print(unlist(sampleNames[families != families[sample_index]]))
        cat("\n")
        reference_list = select.reference.set(
            test.counts = countmat[,i],
            reference.count = countmat[,sampleNames[families != families[sample_index]]],
            bin.length=(ExomeCount.dafr$end-ExomeCount.dafr$start)/1000,
            n.bins.reduced = 10000)
        cat("\nOptimized reference set: ", reference_list[[1]], "\n")

        ## construct the reference set (all other samples of run)
        reference_set = apply(
            X = as.matrix(ExomeCount.dafr[, reference_list$reference.choice, drop = FALSE]), #drop = FALSE: in case the reference set contains a singlle sample, it will makes sure that the subsetted object is a data frame, not a numeric vector
            MAR=1, FUN=sum)

        ## CNV calling - beta-binomial model applied to the full set of exons - longest step
        cat("\nCreating the ExomeDepth object\n")
        all_exons = new('ExomeDepth',
                        test=countmat[,i],
                        reference=reference_set,
                        formula = 'cbind(test,reference) ~ 1')
        ## call CNV by running the underlying hidden Markov model
        ## the correlation between reference and test set should be >0.97
        ## if not: consider the output as less reliable
        cat("\nCall CNVs\n")
        all_exons = CallCNVs(x = all_exons,
                            transition.probability=10^-4,
                            chromosome=ExomeCount.dafr$chromosome,
                            start=ExomeCount.dafr$start,
                            end=ExomeCount.dafr$end,
                            name=ExomeCount.dafr$exon)
        if (all(dim(all_exons@CNV.calls) != c(0,0))) {#if CNVs found
            ## annotation CNV calls with exon info
            cat("\nAnnotate with exon info\n")
            all_exons = AnnotateExtra(x = all_exons,
                                reference.annotation = exons.GRanges,
                                min.overlap = 0.0001,
                                column.name= 'exons')
            ## output file
            ## ranking the CNV calls by confidence level
            ## the BF column = Bayes factor = quantifies the statistical support for each CNV (=log10 of the likelyhood ratio of data for the CNV call divided by the null (normal copy number).
            ## The higher BF, the more confident about the presence of a CNV; this is especially true for obvious large calls; for short exons: BF are bound to be unconvincing
            output.cnv.file = paste(sample,"_CNVs_ExomeDepth_",prefix,".txt",sep='')
            cat("\nOutput file:",output.cnv.file ,"\n")
            write.table(all_exons@CNV.calls[order ( all_exons@CNV.calls$BF, decreasing = TRUE),], file=output.cnv.file,
                sep='\t', row.names=FALSE, col.names=TRUE, quote=FALSE)
        }
        else {#no CNVs found
            output.cnv.file = paste(sample,"_CNVs_ExomeDepth_",prefix,".txt",sep='')
            cat("\nNo", prefix, "CNVs found\n")
            cat("\nOutput file:",output.cnv.file ,"\n")
            note = paste( cnv_call_header , collapse = "\t")
            write(note, file=output.cnv.file)
        }
        cat("\nDone\n")
    }
}
cat("\n\n---Finished---\n")
