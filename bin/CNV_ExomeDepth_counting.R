############################################################################################
### ExomeDepth - counting step                                                           ###
############################################################################################

### load libs ###
library("optparse") 
library("methods") # to load the function "as"
library("ExomeDepth")
ExomeDepthVersion <- packageDescription("ExomeDepth")$Version
print(paste0("...loaded ExomeDepth version: ", ExomeDepthVersion))

## pass options ###
option_list = list(
    make_option(c("--bamfile"), type="character", default=NULL, 
              help="full paths of BAM file", metavar="character"),
    make_option(c("--exon_target"), type="character", default=NULL, 
              help="path to bed file of exon target", metavar="character"),
    make_option(c("--prefix"), type="character", default=NULL, 
              help="prefix for output name, chrX or autosomal", metavar="character")
); 
opt_parser = OptionParser(option_list=option_list);
opt = parse_args(opt_parser);

if (is.null(opt$bamfile)){
  print_help(opt_parser)
  stop("Not all the input arguments are provided", call.=FALSE)
}
if (is.null(opt$exon_target)){
  print_help(opt_parser)
  stop("Not all the input arguments are provided", call.=FALSE)
}
if (is.null(opt$prefix)){
  print_help(opt_parser)
  stop("Not all the input arguments are provided", call.=FALSE)
}

cat("bam file: ", opt$bamfile, "\n")
cat("exon target file: ", opt$exon_target, "\n")
cat("prefix: ", opt$prefix, "\n")

### load exon data ###
exons <- read.table(file=opt$exon_target,sep="\t",header = F)
colnames(exons) <- c("chromosome","start","end","name")

### load all exon info ####
exons.GRanges <- GenomicRanges::GRanges(seqnames = exons$chromosome,
        IRanges::IRanges(start=exons$start,end=exons$end),
        names = exons$name
        )

### Getting the input data from BAM file ###
bam <- unlist(opt$bamfile )

sampleName <- unlist(strsplit(unlist(strsplit(bam, ".bam")),split=".//"))

cat("Sample names:", "\n")
sampleName2<-gsub("^.*/","",sampleName)
sampleName2

### ExomeDepth sometimes spectacularly fails to find the BAM index, for no clear reason ###
## so help it out by testing a few likely filenames
bamindex = bam

stardotbai = gsub(".bam$",".bai",bam)
stardotbamdotbai = gsub(".bam$",".bam.bai",bam)
if (file.exists(stardotbai)) {
  bamindexe = stardotbai
} else if (file.exists(stardotbamdotbai)) {
  bamindexe = stardotbamdotbai
}
else {
  cat(paste("Cannot find a .bai index for BAM: ",bam,"\n",sep=""),file=stderr())
  cat("stopping execution....",file=stderr())
  stop()
}

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
## convert GRanges class (S4 object) into a data.frame, which is the input format for ExomeDepth
ExomeCount.dafr <- as(ExomeCount[,  colnames(ExomeCount)], 'data.frame') 
## remove the annoying chr letters
ExomeCount.dafr$space <- gsub(as.character(ExomeCount.dafr$space),
                                        pattern = 'chr', 
                                        replacement = '')
## rename sample names in colnames
header_first_part<-c("space", "start", "end", "width", "names")
colnames(ExomeCount.dafr)<-c(header_first_part, sampleName2)
colnames(ExomeCount.dafr)
print(head(ExomeCount.dafr))
cat("Successfully calculated counts.\n")

###  save counts as a text file and rda object ###
cat("Saving the counts \n")
countspath = paste("counts_",sampleName2,"_",opt$prefix,".txt",sep="")
write.table(ExomeCount.dafr,countspath,sep="\t",col.names=TRUE,row.names=FALSE,quote=FALSE)  

cat("\n\n---Finished---\n")

