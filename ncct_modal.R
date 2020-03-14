# function defining the ncct modal
# 'entries' is a  list which is obtained from a yaml file, maintained at the gist below 
# !!! reads the choices from
# https://gist.github.com/angelovangel/d079296b184eba5b124c1d434276fa28
# each time it is called

require(yaml)

ncct_modal <- function(entries) {
  
  modalDialog(size = "m", 
              footer = tagList(modalButton("Cancel"), actionButton("ncct_ok", "OK")),
    textInput("customer", "Customer name", width = '90%', 
              placeholder = "Enter name of PI"),
    textInput("project_id", "Project ID", width = '90%', 
              placeholder = "Enter project ID"),
    
    # all selectize inputs get their choices from the gist yaml
    selectizeInput("ncct_contact", "Contact at NCCT", width = '90%', 
                   choices = entries$ncct_contact
                   ),
    
    selectizeInput("project_type", "Type of project", width = '90%', 
                   choices = entries$project_type
                   ),
    
    selectizeInput("lib_prep", "Library prep kit", width = '90%', 
                   choices = entries$lib_prep
                   ),
    
    selectizeInput("indexing", "Index kit", width = '90%', 
                   choices = entries$indexing
                   ),
    
    selectizeInput("seq_setup", "Sequencing setup", width = '90%', 
                   choices = entries$seq_setup
                   )
  )
}