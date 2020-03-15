 #### nextflow-fastp app ####
 
 # a shiny frontend for the nextflow-fastp pipeline
 # https://github.com/angelovangel/nextflow-fastp.git
 
 library(shiny)
 library(shinyFiles)
 library(shinyjs)
 library(shinyalert)
 library(processx)
 library(stringr)
 library(digest)
 library(yaml)
 library(shinyFeedback)
 library(pingr) # to check if server has internet
 
 # define reactive to track user counts
 users <- reactiveValues(count = 0)
 
 source("ncct_modal.R", local = FALSE)$value # don't share across sessions, who knows what could happen!
 source("ncct_make_yaml.R")
 
 
 #### ui ####
 ui <- function(x) {
   # I like to mix up R, JS and CSS
   navbarPage(title = tags$button("nextflow-fastp",
                               id = "fastpButton", # events can be listened to as input$cazytableButton in server
                               class = "action-button", #shiny needs this class def to work
                               title = "If you want to start over, just reload the page.",
                               onMouseOver = "this.style.color='orange'", # old school js
                               onMouseOut = "this.style.color='green'",
                               style = "color: green; font-weight: bold; border: none; background-color: inherit;"),
             
              windowTitle = "nextflow-fastp", 
              collapsible = TRUE,
    
    tabPanel("nextflow-fastp output",
            # attempts to use external progress bar
            includeCSS("css/custom.css"),
            useShinyFeedback(),
            useShinyjs(),
            useShinyalert(), 
            
            # snackbars begin
            snackbarWarning(id = "tower_snackbar", 
                            message = "Is TOWER_ACCESS_TOKEN available in Sys.getenv() ?"),
            snackbarSuccess("fastp_trimmed", 
                            message = "Default fastp parameters will be used"),
            # snackbars end
            
            shiny::uiOutput("mqc_report_button", inline = TRUE),
            
            shiny::div(id = "commands_pannel",
              shinyDirButton(id = "fastq_folder", 
                             label = "Select fastq folder", 
                             title = "Please select a folder with fastq files", 
                             icon = icon("folder-open")),
              actionButton("run", "Run nextflow-fastp pipeline", 
                         style = "color: green; font-weight: bold;", 
                         onMouseOver = "this.style.color = 'orange' ", 
                         onMouseOut = "this.style.color = 'green' ", 
                         icon = icon("play")),
              actionButton("reset", "Reset", 
                         style = "color: green; font-weight: bold;",
                         onMouseOver = "this.style.color = 'orange' ",
                         onMouseOut = "this.style.color = 'green' ", 
                         icon = icon("redo")),
            
            actionButton("more", "More options", 
                         icon = icon("cog"),
                         class = "rightAlign"),
            actionButton("landing_page", "Go to home page", 
                         icon = icon("home"),
                         class = "rightAlign", 
                         onclick ="window.open('http://google.com', '_blank')"),
            tags$div(id = "optional_inputs",
              absolutePanel(top = 140, right = 20,
                          textInput(inputId = "report_title", 
                                    label = "Title of MultiQC report", 
                                    value = "Summarized fastp report"),
                          tags$hr(),
                          selectizeInput("nxf_profile", 
                                         label = "Select nextflow profile", 
                                         choices = c("docker", "conda"), 
                                         selected = "docker", 
                                         multiple = FALSE),
                          tags$hr(),
                          actionButton("ncct", "Enter NCCT project info"),
                          tags$hr(),
                          checkboxInput("tower", "Use Nextflow Tower to monitor run", value = FALSE),
                          tags$hr(),
                          # the idea being - if trimmed are not needed - delete them (no changes in the nxf pipe)
                          checkboxInput("save_trimmed", "Save fastp-trimmed files?", value = FALSE),
                          tags$hr()
                          
              )
            )
          ),
            
            verbatimTextOutput("stdout")
            
    ),
    tabPanel("Help", 
             includeMarkdown("help.md"))
    
  )
 }
 #### server ####
  server <- function(input, output, session) {
    options(shiny.launch.browser = TRUE, shiny.error=recover)
    
    #----
    # reactive for optional params for nxf, so far only -with-tower, but others may be implemented here
    # set TOWER_ACCESS_TOKEN in ~/.Renviron
    optional_params <- reactiveValues(tower = "", mqc = "")
    
    # update user counts at each server call
    isolate({
      users$count <- users$count + 1
    })
    
    # observe changes in users$count and write to log, observers use eager eval
    observe({
      writeLines(as.character(users$count), con = "userlog")
    })
    
    # observer for optional inputs
    hide("optional_inputs")
    observeEvent(input$more, {
      shinyjs::toggle("optional_inputs")
    })
    
    # shinyFeeback observers
    # title too short?
    observeEvent(input$report_title, {
      feedbackWarning(inputId = "report_title", 
                      condition = nchar(input$report_title) <= 10, 
                      text = "Title too short?")
    })
    
    observe({
      if(input$tower) {
      showSnackbar("tower_snackbar")
      }
    })
    
    observe({
      if(input$save_trimmed) {
        showSnackbar("fastp_trimmed")
      }
    })
    
    #----
    # strategy for ncct modal and multiqc config file handling:
    # if input$ncct_ok is clicked, the modal inputs are fed into the ncct_make_yaml() function, which generates
    # a multiqc_config.yml file and saves it using tempfile()
    # initially, the reactive value mqc_config$rv is set to "", if input$ncct_ok then it is set to
    # c("--multiqc_config", mqc_config_temp) and this reactive is given as param to the nxf pipeline
    
    # observer to generate ncct modal
    observeEvent(input$ncct, {
      if(pingr::is_online()) {
        ncct_modal_entries <- yaml::yaml.load_file("https://gist.githubusercontent.com/angelovangel/d079296b184eba5b124c1d434276fa28/raw/ncct_modal_entries")
        showModal( ncct_modal(ncct_modal_entries) )
      } else {
        shinyalert("No internet!", 
                   text = "This feature requires internet connection", 
                   type = "warning")
      }
      
    })
    
    # generate yml file in case OK of modal was pressed
    # the yml file is generated in the app exec env, using temp()
    observeEvent(input$ncct_ok, {
      mqc_config_temp <- tempfile()
      optional_params$mqc <- c("--multiqc_config", mqc_config_temp) 
      ncct_make_yaml(customer = input$customer, 
                     project_id = input$project_id, 
                     ncct_contact = input$ncct_contact, 
                     project_type = input$project_type, 
                     lib_prep = input$lib_prep, 
                     indexing = input$indexing, 
                     seq_setup = input$seq_setup, 
                     ymlfile = mqc_config_temp)
      shinyalert(text = "Project info saved!", type = "info", timer = 1500, showConfirmButton = FALSE)
      removeModal()
    })
    
    
    # generate random hash for multiqc report temp file name
    mqc_hash <- sprintf("%s_%s.html", as.integer(Sys.time()), digest::digest(runif(1)) )
    
    # dir choose management --------------------------------------
    volumes <- c(Home = fs::path_home(), getVolumes()() )
    shinyDirChoose(input, "fastq_folder", 
                   roots = volumes, 
                   session = session, 
                   restrictions = system.file(package = "base")) 
    
    #-----------------------------------
    # show currently selected fastq folder (and count fastq files there)
    
    output$stdout <- renderPrint({
      if (is.integer(input$fastq_folder)) {
        cat("No fastq folder selected\n")
      } else {
        nfastq <<- length(list.files(path = parseDirPath(volumes, input$fastq_folder), pattern = "*fast(q|q.gz)$"))
        
        # setup of tower optional
        optional_params$tower <- if(input$tower) {
          "-with-tower"
        } else {
          ""
        }
        
        #shinyjs::hide("fastq_folder")
        cat(
          " Selected folder:\n",
          parseDirPath(volumes, input$fastq_folder), "\n",
          "------------------\n\n",
          
          
          "Number of fastq files found:\n",
          nfastq, "\n",
          "------------------\n\n",
          
          
          "Nextflow command to be executed:\n",
          "nextflow run angelovangel/fastp", "\\ \n",
          "--runfolder", 
          parseDirPath(volumes, input$fastq_folder), "\\ \n",
          "-profile", 
          input$nxf_profile, optional_params$tower, "\\ \n",
          optional_params$mqc, "\n",
          
          "------------------\n")
       }
    })

    #---
    # real call to nextflow-fastp-------
    #----      
    # setup progress bar and callback function to update it
    progress <- shiny::Progress$new(min = 0, max = 1, style = "old")
    
    
    # callback function, to be called from run() on each chunk of output
    cb_count <- function(chunk, process) {
      counts <- str_count(chunk, pattern = "process > fastp")
      #print(counts)
      val <- progress$getValue() * nfastq
      progress$inc(amount = counts/nfastq,
                   detail = paste0(floor(val), " of ", nfastq, " files"))


    }
    # using processx to better control stdout
    observeEvent(input$run, {
      if(is.integer(input$fastq_folder)) {
        shinyjs::html(id = "stdout", "\nPlease select a fastq folder first, then press 'Run'...\n", add = TRUE)
      } else {
        # set run button color to red?
        shinyjs::disable(id = "commands_pannel")
       
         # change label during run
        shinyjs::html(id = "run", html = "Running... please wait")
        progress$set(message = "Processed ", value = 0)
        on.exit(progress$close() )
        
      # Dean Attali's solution
      # https://stackoverflow.com/a/30490698/8040734
        withCallingHandlers({
          shinyjs::html(id = "stdout", "")
          p <- processx::run("nextflow", 
                      args = c("run" ,
                               "angelovangel/nextflow-fastp", # in case it is pulled before with nextflow pull and is in ~/.nextflow
                               # fs::path_abs("nextflow-fastp/main.nf"), # absolute path to avoid pulling from github
                               "--readsdir", 
                               parseDirPath(volumes, input$fastq_folder), 
                               "-profile", 
                               input$nxf_profile, 
                               optional_params$mqc,
                               optional_params$tower),
                      
                      wd = parseDirPath(volumes, input$fastq_folder),
                      #echo_cmd = TRUE, echo = TRUE,
                      stdout_line_callback = function(line, proc) {message(line)}, 
                      stdout_callback = cb_count,
                      stderr_to_stdout = TRUE, 
                      error_on_status = FALSE
                      )
          }, 
            message = function(m) {
              shinyjs::html(id = "stdout", html = m$message, add = TRUE); 
              runjs("document.getElementById('stdout').scrollTo(0,1e9);") # scroll the page to bottom with each message, 1e9 is just a big number
            }
        )
        if(p$status == 0) {
          # hide command pannel 
          shinyjs::hide("commands_pannel")
          
          # clean work dir in case run finished ok
          work_dir <- paste(parseDirPath(volumes, input$fastq_folder), "/work", sep = "")
          system2("rm", args = c("-rf", work_dir))
          cat("deleted", work_dir, "\n")
          
          # delete trimmed fastq files in case input$save_trimmed
          fastp_trimm_folder <- file.path(parseDirPath(volumes, input$fastq_folder), "results-fastp/fastp_trimmed")
          if(!input$save_trimmed) {
            system2("rm", args = c("-rf", fastp_trimm_folder))
            cat("deleted", fastp_trimm_folder, "\n")
          }
            
          # copy mqc to www/ to be able to open it, also use hash to enable multiple concurrent users
          mqc_report <- paste(parseDirPath(volumes, input$fastq_folder), 
                           "/results-fastp/multiqc_report.html", # make sure the nextflow-fastp pipeline writes to "results-fastp"
                           sep = "")
           
          system2("cp", args = c(mqc_report, paste("www/", mqc_hash, sep = "")) )
          
          
          # render the new action buttons to show report
          output$mqc_report_button <- renderUI({
            actionButton("mqc", label = "MultiQC report", 
                         icon = icon("th"), 
                         onclick = sprintf("window.open('%s', '_blank')", mqc_hash)
            )
          })
          
          #
          # build js callback string for shinyalert
          js_cb_string <- sprintf("function(x) { if (x == true) {window.open('%s') ;} } ", mqc_hash)
          
          shinyalert("Run finished!", type = "success", 
                   animation = "slide-from-bottom",
                   text = "Pipeline finished, check results folder", 
                   showCancelButton = TRUE, 
                   confirmButtonText = "Open report",
                   callbackJS = js_cb_string, 
                   #callbackR = function(x) { js$openmqc(mqc_url) }
                   )
        } else {
          shinyjs::html(id = "run", html = "Finished with errors")
          shinyjs::enable(id = "commands_pannel")
          shinyjs::disable(id = "run")
          shinyalert("Error!", type = "error", 
                     animation = "slide-from-bottom", 
                     text = "Pipeline finished with errors, press OK to reload the app and try again.", 
                     showCancelButton = TRUE, 
                     callbackJS = "function(x) { if (x == true) {history.go(0);} }"
                     )
        }
      }
      
    })
    
    #------------------------------------------------------------
    session$onSessionEnded(function() {
      # delete own mqc from www, it is meant to be temp only 
      system2("rm", args = c("-rf", paste("www/", mqc_hash, sep = "")) )
      
      #user management
      isolate({
        users$count <- users$count - 1
        writeLines(as.character(users$count), con = "userlog")
      })
      
    })
  
    #---
  # ask to start over if title or reset clicked
  #----                     
  observeEvent(input$fastpButton, {
    shinyalert(title = "",
               type = "warning",
               text = "Start again or stay on page?", 
               html = TRUE, 
               confirmButtonText = "Start again", 
               showCancelButton = TRUE, 
               callbackJS = "function(x) { if (x == true) {history.go(0);} }" # restart app by reloading page
               )
  })
  observeEvent(input$reset, {
    shinyalert(title = "",
               type = "warning",
               text = "Start again or stay on page?", 
               html = TRUE, 
               confirmButtonText = "Start again", 
               showCancelButton = TRUE, 
               # actually, session$reload() as an R callback should also work
               callbackJS = "function(x) { if (x == true) {history.go(0);} }" # restart app by reloading page
      )
    })
   
    
 }
 
 shinyApp(ui, server)
 