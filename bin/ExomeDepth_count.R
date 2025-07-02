#!/usr/bin/env Rscript

############################################################################################
### ExomeDepth - counting step                                                           ###
############################################################################################

### load libs ###
# library("optparse")
library("methods") # to load the function "as"
library("ExomeDepth")
ExomeDepthVersion <- packageDescription("ExomeDepth")$Version
print(paste0("...loaded ExomeDepth version: ", ExomeDepthVersion))


## pass options ###
args = commandArgs(trailingOnly = TRUE)
print_usage <- function() {
    cat("Usage: ExomeDepth_count.R <samplename> <bamfile> <baifile> <exon_target> <prefix>\n")
}
if (length(commandArgs(trailingOnly = TRUE)) != 5) {
    print_usage()
    q("no", status = 1) # Terminate the script with an error status
}

cat("samplename: ", args[1], "\n")
cat("bam file: ", args[2], "\n")
cat("bam index file: ", args[3], "\n")
cat("exon target file: ", args[4], "\n")
cat("prefix: ", args[5], "\n")

### load exon data ###
exons <- read.table(file=args[4],sep="\t",header = F)
colnames(exons) <- c("chromosome","start","end","name")

### load all exon info ####
exons.GRanges <- GenomicRanges::GRanges(seqnames = exons$chromosome,
        IRanges::IRanges(start=exons$start,end=exons$end),
        names = exons$name
        )

### Getting the input data from BAM file ###
bam <- unlist(args[2])

cat("Sample names:", "\n")
sampleName <- unlist(args[1])
sampleName

### ExomeDepth sometimes spectacularly fails to find the BAM index, for no clear reason ###
## so help it out by testing a few likely filenames

### read.count ~exomeCopy package ###
## ouput = GenomicRages object that stores the read count data form the BAM file ###
cat("\nCalling ExomeDepth to compute counts...\n")
ExomeCount <- getBamCounts(bed.frame = exons,
                            bam.files = bam, #vector of BAM path strings
                            include.chr = TRUE
                            #referenceFasta = fasta #only useful if one wants to obtain the GC content
                            #min.mapq =20 #default minimum mapping quality to include a read
                            #read.width =300 #default maximum distance between the side of the target region and the middle of the paired reads to include the paired read into that region
                            )
cat("\nCounting done...\n")
colnames(ExomeCount)
## convert GRanges class (S4 object) into a data.frame, which is the input format for ExomeDepth
ExomeCount.dafr <- as(ExomeCount[,  colnames(ExomeCount)], 'data.frame')
cat("\nConversion done...\n")
print(head(ExomeCount.dafr))
## remove the annoying chr letters
ExomeCount.dafr$chromosome <- gsub(as.character(ExomeCount.dafr$chromosome),
                                        pattern = 'chr',
                                        replacement = '')
cat("\nChr's removed...\n")
## rename sample names in colnames
header_first_part<-c("chromosome", "start", "end", "exon")
colnames(ExomeCount.dafr)<-c(header_first_part, sampleName)
colnames(ExomeCount.dafr)
print(head(ExomeCount.dafr))
cat("Successfully calculated counts.\n")

###  save counts as a text file and rda object ###
cat("Saving the counts \n")
countspath = paste(args[5],".txt",sep="")
write.table(ExomeCount.dafr,countspath,sep="\t",col.names=TRUE,row.names=FALSE,quote=FALSE)

cat("\n\n---Finished---\n")
