version 1.0

task extract {

    input {
        File query_variants
        File? query_samples
        Array [File] imputed_vcf
        String prefix
    }
    
    command <<<
        for vcf in ~{sep=' ' imputed_vcf}; do
            ln -s $vcf $(basename $vcf)
            # If the index file does not exist, create it
            if [ ! -f $vcf.csi ]; then
                bcftools index -c $vcf
            fi
        done
        # Get unique chromosome names
        CHROMOSOMES=$(awk '{print $1}' ~{query_variants} | sort | uniq)
        # Split the query_variants file per chromosome
        VCF_FILES=""
        for chr in $CHROMOSOMES; do
            awk -v chr=$chr '$1 == chr' ~{query_variants} > ${chr}_query_subset_variants_list.txt
            if [ -f ${chr}_query_subset_variants_list.txt ] && [ -f ~{query_samples} ]; then
                bcftools view --regions-file ${chr}_query_subset_variants_list.txt --samples-file ~{query_samples} ${chr}.dose.vcf.gz > ~{prefix}_${chr}_query_subset.vcf
            else
                bcftools view --regions-file ${chr}_query_subset_variants_list.txt ${chr}.dose.vcf.gz > ~{prefix}_${chr}_query_subset.vcf
            fi
            VCF_FILES="${VCF_FILES} ~{prefix}_${chr}_query_subset.vcf"
        done
        bcftools concat ${VCF_FILES} -o ~{prefix}_concatenated_query_subset.vcf
        # extract snp INFO
        python3 /home/anand/Documents/aspire-files/data-oxford/terra.bio/get-variant-info/scripts/extract_snp_info.py --vcf ~{prefix}_concatenated_query_subset.vcf --out ~{prefix}_query_subset_extracted_snps_info.tsv
        # extract FORMAT fields
        python3 /home/anand/Documents/aspire-files/data-oxford/terra.bio/get-variant-info/scripts/extract_vcf_info.py --vcf ~{prefix}_concatenated_query_subset.vcf --out ~{prefix}_extracted_snps_bg_genotype.csv --extract GT
        python3 /home/anand/Documents/aspire-files/data-oxford/terra.bio/get-variant-info/scripts/extract_vcf_info.py --vcf ~{prefix}_concatenated_query_subset.vcf --out ~{prefix}_extracted_snps_dosage.csv --extract DS
        python3 /home/anand/Documents/aspire-files/data-oxford/terra.bio/get-variant-info/scripts/extract_vcf_info.py --vcf ~{prefix}_concatenated_query_subset.vcf --out ~{prefix}_extracted_snps_bg_prob.csv --extract GP
    >>>
    
    output {
        File snp_info = prefix + "_query_subset_extracted_snps_info.tsv"
        File gt_info = prefix + "_extracted_snps_bg_genotype.csv"
        File ds_info = prefix + "_extracted_snps_dosage.csv"
        File gp_info = prefix + "_extracted_snps_bg_prob.csv"
    }
}