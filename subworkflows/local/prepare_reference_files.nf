include {
    UNZIPFILES as UNCOMPRESS_HOST_FASTA_GENOME;
    UNZIPFILES as UNCOMPRESS_PATHOGEN_FASTA_GENOME;
    UNZIPFILES as UNCOMPRESS_HOST_GFF;
    UNZIPFILES as UNCOMPRESS_HOST_TRNA_GFF;
    UNZIPFILES as UNCOMPRESS_PATHOGEN_GFF;
    UNZIPFILES as UNCOMPRESS_HOST_TRANSCRIPTOME;
    UNZIPFILES as UNCOMPRESS_PATHOGEN_TRANSCRIPTOME
} from '../../modules/nf-core/unzipfiles/main'

include {
    REPLACE_ATTRIBUTE_GFF_STAR_SALMON as REPLACE_ATTRIBUTE_GFF_STAR_SALMON_HOST;
    REPLACE_ATTRIBUTE_GFF_STAR_SALMON as REPLACE_ATTRIBUTE_GFF_STAR_SALMON_TRNA_FILE;
    REPLACE_ATTRIBUTE_GFF_STAR_SALMON as REPLACE_ATTRIBUTE_GFF_STAR_SALMON_PATHOGEN;
} from '../../modules/local/replace_attribute'

include {
    REPLACE_GENE_FEATURE_GFF_SALMON as REPLACE_GENE_FEATURE_GFF_PATHOGEN_SALMON;
    REPLACE_GENE_FEATURE_GFF_SALMON as REPLACE_GENE_FEATURE_GFF_HOST_SALMON;
 } from '../../modules/local/replace_gene_feature'

inclue {
  REPLACE_GENE_FEATURE_GFF_HTSEQ as REPLACE_GENE_FEATURE_GFF_HOST_HTSEQ;
  REPLACE_GENE_FEATURE_GFF_HTSEQ as REPLACE_GENE_FEATURE_GFF_PATHOGEN_HTSEQ;
} from '../../modules/local/replace_gene_feature_htseq'

include {
    COMBINE_FILES as COMBINE_HOST_GENOME_TRNA_GFF_STAR_SALMON;
    COMBINE_FILES as COMBINE_PATHOGEN_HOST_GFF_FILES_HTSEQ;
    COMBINE_FILES as COMBINE_FILES_PATHOGEN_HOST_GFF;
    COMBINE_FILES as COMBINE_FILES_FASTA;
    COMBINE_FILES as COMBINE_FILES_TRANSCRIPTOME_FILES;
    COMBINE_FILES as COMBINE_HOST_GFF_FILES
}  from '../../modules/local/combine_files'


include { PREPARE_HOST_TRANSCRIPTOME      } from './prepare_host_transcriptome'
include { PREPARE_PATHOGEN_TRANSCRIPTOME  } from './prepare_pathogen_transcriptome'

include {
    EXTRACT_ANNOTATIONS as EXTRACT_ANNOTATIONS_HOST_HTSEQ;
    EXTRACT_ANNOTATIONS as EXTRACT_ANNOTATIONS_HOST_SALMON;
    EXTRACT_ANNOTATIONS as EXTRACT_ANNOTATIONS_PATHOGEN_HTSEQ;
    EXTRACT_ANNOTATIONS as EXTRACT_ANNOTATIONS_PATHOGEN_SALMON
} from '../../modules/local/extract_annotations'


workflow PREPARE_REFERENCE_FILES{
  take:
    fasta_host
    gff_host
    gff_host_tRNA
    fasta_pathogen
    gff_pathogen

  main:
    ch_transcriptome = Channel.empty()
    ch_host_transcriptome = Channel.empty()
    ch_pathogen_transcriptome = Channel.empty()

    ch_gene_feature_pat = Channel
	    .value(params.gene_feature_gff_to_create_transcriptome_pathogen)
	    .collect()
    //
    // uncompress fasta files and gff files
    //

    ch_fasta_host = Channel.value(file(params.fasta_host, checkIfExists: true))
    ch_gff_host = Channel.value(file(params.gff_host, checkIfExists: true))
    ch_gff_host_tRNA = Channel.value(file(params.gff_host_tRNA, checkIfExists: true)) 
    ch_gff_pathogen = Channel.value(file(params.gff_pathogen, checkIfExists: true))
    ch_fasta_pathogen = Channel.value(file(params.fasta_pathogen, checkIfExists: true)) 

    if (params.fasta_pathogen.endsWith('.gz') || params.fasta_pathogen.endsWith('.zip')){
        ch_fasta_pathogen_unzipped = UNCOMPRESS_PATHOGEN_FASTA_GENOME(ch_fasta_pathogen)
    } else {
        ch_fasta_pathogen_unzipped = ch_fasta_pathogen
    }

    if (params.gff_pathogen.endsWith('.gz') || params.gff_pathogen.endsWith('.zip')){
        ch_gff_pathogen_unzipped = UNCOMPRESS_PATHOGEN_GFF(ch_gff_pathogen)
    } else {
        ch_gff_pathogen_unzipped = ch_gff_pathogen
    }

    if (params.fasta_host.endsWith('.gz') || params.fasta_host.endsWith('.zip')){
        ch_fasta_host_unzipped = UNCOMPRESS_HOST_FASTA_GENOME(ch_fasta_host)
    } else {
        ch_fasta_host_unzipped = ch_fasta_host
    }

    if (params.gff_host.endsWith('.gz') || params.gff_host.endsWith('.zip')){
        ch_gff_host_unzipped = UNCOMPRESS_HOST_GFF(ch_gff_host)
    } else {
        ch_gff_host_unzipped = ch_gff_host
    }

    if (params.gff_host_tRNA.endsWith('.gz') || params.gff_host_tRNA.endsWith('.zip')){
        ch_gff_host_tRNA_unzipped = UNCOMPRESS_HOST_TRNA_GFF(ch_gff_host_tRNA)
    } else {
        ch_gff_host_tRNA_unzipped = ch_gff_host_tRNA
    }

    //
    // combine pathogen and host fasta and gff files
    //

    COMBINE_FILES_FASTA(ch_fasta_pathogen_unzipped, ch_fasta_host_unzipped, 'host_pathogen.fasta' )

    //TODO add if statement if(params.gff_host_tRNA); if(params.run_htseq_uniquely_mapped)
    COMBINE_HOST_GFF_FILES(ch_gff_host_unzipped,ch_gff_host_tRNA_unzipped, "host_genome_with_tRNA.gff3")

    //
    // execute steps specific for mapping-quantification modes
    //

    if(params.run_salmon_selective_alignment | params.run_salmon_alignment_based_mode) {
      if(params.transcript_fasta_host){
          ch_host_transcriptome  = params.transcript_fasta_host ? Channel.value(file(params.transcript_fasta_host, checkIfExists: true )) : Channel.empty()

          if (params.transcript_fasta_host.endsWith('.gz') || params.transcript_fasta_host.endsWith('.zip')){
                  UNCOMPRESS_HOST_TRANSCRIPTOME(ch_host_transcriptome)
                  ch_transcript_host_unzipped = UNCOMPRESS_HOST_TRANSCRIPTOME.out.files
          } else {
                  ch_transcript_host_unzipped = ch_host_transcriptome
          }

      } else {
            
      PREPARE_HOST_TRANSCRIPTOME(
        ch_fasta_host_unzipped,
        ch_gff_host_unzipped,
        ch_gff_host_tRNA_unzipped
      )

      ch_transcript_host_unzipped = PREPARE_HOST_TRANSCRIPTOME.out.transcriptome

    }

      if(params.transcript_fasta_pathogen){
          ch_pathogen_transcriptome  = params.transcript_fasta_pathogen ? Channel.value(file( params.transcript_fasta_pathogen, checkIfExists: true )) : Channel.empty()
          
            if (params.transcript_fasta_pathogen.endsWith('.gz') || params.transcript_fasta_pathogen.endsWith('.zip')){
                    UNCOMPRESS_PATHOGEN_TRANSCRIPTOME(ch_pathogen_transcriptome)
                    ch_transcript_pathogen_unzipped = UNCOMPRESS_PATHOGEN_TRANSCRIPTOME.out.files
            } else {
                    ch_transcript_pathogen_unzipped = ch_pathogen_transcriptome
            }
        
        } else {
          PREPARE_PATHOGEN_TRANSCRIPTOME(
            ch_fasta_pathogen_unzipped,
            ch_gff_pathogen_unzipped
          )
          ch_transcript_pathogen_unzipped = PREPARE_PATHOGEN_TRANSCRIPTOME.out.transcriptome
     }




      // combine pathogen and host transcriptome
   //   transciptiome_transcriptome_to_combine = ch_host_transcriptome.mix(
   //     ch_pathogen_transcriptome
   //   ).collect()

      COMBINE_FILES_TRANSCRIPTOME_FILES(
        ch_transcript_host_unzipped,ch_transcript_pathogen_unzipped,'host_pathogen.transcript.fasta'
      )
      ch_transcriptome = COMBINE_FILES_TRANSCRIPTOME_FILES.out



    REPLACE_ATTRIBUTE_GFF_STAR_SALMON_PATHOGEN(
           ch_gff_pathogen_unzipped,
           params.gene_attribute_gff_to_create_transcriptome_pathogen,
           'parent')

    REPLACE_ATTRIBUTE_GFF_STAR_SALMON_HOST(
          ch_gff_host_unzipped,
          'Parent',
          'parent'
      )

    if(params.run_htseq_uniquely_mapped) {
      REPLACE_GENE_FEATURE_GFF_HOST_HTSEQ;
      REPLACE_GENE_FEATURE_GFF_PATHOGEN_HTSEQ;
    }

    if(params.gff_host_tRNA){
        REPLACE_ATTRIBUTE_GFF_STAR_SALMON_TRNA_FILE(
          ch_gff_host_tRNA_unzipped,
          params.gene_attribute_gff_to_create_transcriptome_host,
          'parent'
        )

        COMBINE_HOST_GENOME_TRNA_GFF_STAR_SALMON(
                REPLACE_ATTRIBUTE_GFF_STAR_SALMON_HOST.out,
                REPLACE_ATTRIBUTE_GFF_STAR_SALMON_TRNA_FILE.out,"host_genome_with_tRNA.gff3")
    }

    ch_gff_host_genome_salmon_alignment = params.gff_host_tRNA ? COMBINE_HOST_GENOME_TRNA_GFF_STAR_SALMON.out : REPLACE_ATTRIBUTE_GFF_STAR_SALMON_HOST.out

    REPLACE_GENE_FEATURE_GFF_HOST_SALMON(
                ch_gff_host_genome_salmon_alignment,
                params.gene_feature_gff_to_create_transcriptome_host
            )


    REPLACE_GENE_FEATURE_GFF_PATHOGEN_SALMON(
                REPLACE_ATTRIBUTE_GFF_STAR_SALMON_PATHOGEN.out,
                ch_gene_feature_pat
            )

    COMBINE_FILES_PATHOGEN_HOST_GFF(
                REPLACE_GENE_FEATURE_GFF_PATHOGEN_SALMON.out,
                REPLACE_GENE_FEATURE_GFF_HOST_SALMON.out,
                "host_pathogen_star_alignment_mode.gff"
            )


    EXTRACT_ANNOTATIONS_PATHOGEN_SALMON (
            REPLACE_ATTRIBUTE_GFF_STAR_SALMON_PATHOGEN.out,
            ch_gene_feature_pat,
            "parent",
            params.pathogen_organism,
            'salmon'
        )

    EXTRACT_ANNOTATIONS_HOST_SALMON (
            REPLACE_GENE_FEATURE_GFF_HOST_SALMON.out,
            'quant',
            'parent',
            params.host_organism,
            'salmon'
        )

    if(params.run_star | params.run_salmon_alignment_based_mode) {
    }
	  if(params.mapping_statistics) {
        EXTRACT_REFERENCE_NAME_STAR_HOST()
        EXTRACT_REFERENCE_NAME_STAR_PATHOGEN()

    }

    emit:
      genome_fasta = COMBINE_FILES_FASTA.out
      transcript_fasta = ch_transcriptome
      transcript_fasta_host = ch_transcript_host_unzipped
      transcript_fasta_pathogen = ch_transcript_pathogen_unzipped
      host_pathoge_gff = COMBINE_FILES_PATHOGEN_HOST_GFF.out
      annotations_host_salmon = EXTRACT_ANNOTATIONS_HOST_SALMON.out.annotations
      annotations_pathogen_salmon = EXTRACT_ANNOTATIONS_PATHOGEN_SALMON.out.annotations
      annotations_host_htseq = EXTRACT_ANNOTATIONS_HOST_HTSEQ.out.annotations
      annotations_pathogen_htsqe = EXTRACT_ANNOTATIONS_PATHOGEN_HTSEQ.out.annotations
      reference_pathogen_name = EXTRACT_REFERENCE_NAME_STAR_HOST.out
      reference_host_name = EXTRACT_REFERENCE_NAME_STAR_PATHOGEN.out

    }

