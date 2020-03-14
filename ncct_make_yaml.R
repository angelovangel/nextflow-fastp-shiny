# generate multiqc_config.yaml file from modal inputs
# entries match inputs from ncct_modal.R
# passed as arg to nextflow-bcl (--multiqc_config file.yaml)

require(yaml)

ncct_make_yaml <- function(customer = "", 
                           project_id = "", 
                           ncct_contact = "", 
                           project_type = "", 
                           lib_prep = "", 
                           indexing = "", 
                           seq_setup = "", 
                           ymlfile = "temp.yml") {
  write_yaml(indent.mapping.sequence = TRUE, 
             indent = 2, 
             file = ymlfile,
    list(
      intro_text = FALSE,
      report_header_info = list(
        list("Customer" = customer),
        list("Project" = project_id),
        list("NCCT contact" = ncct_contact),
        list("Project type" = project_type),
        list("Library prep kit" = lib_prep),
        list("Index kit" = indexing),
        list("Sequencing setup" = seq_setup)
      )
    )
  )
}