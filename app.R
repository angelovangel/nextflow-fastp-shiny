 #### nextflow-fastp app ####
 
 # a shiny frontend for the nextflow-fastp pipeline
 # https://github.com/angelovangel/nextflow-fastp.git
 
 library(shiny)
 library(shinyFiles)
 library(shinyjs)
 library(shinyalert)
 library(processx)
 library(parallel)
 library(stringr)
 library(digest)
 library(yaml)
 library(shinypop)
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
            #useShinyFeedback(),
            useShinyjs(),
            useShinyalert(), 
            use_notiflix_notify(position = "left-bottom", width = "380px"),
            
            shiny::uiOutput("mqc_report_button", inline = TRUE),
            shiny::uiOutput("nxf_report_button", inline = TRUE),
            shiny::uiOutput("outputFilesLocation", inline = TRUE),
            
            shiny::div(id = "commands_pannel",
              shinyDirButton(id = "fastq_folder", 
                             label = "Select fastq folder", 
                             style = "color: green; font-weight: bold;", 
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
                          
                          textInput(inputId = "fqpattern", 
                                    label = "Fastq reads pattern", 
                                    value = "*R{1,2}_001.fastq.gz"),
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
    ncores <- parallel::detectCores() # use for info only
    
    nx_notify_success(paste("Hello ", Sys.getenv("LOGNAME"), 
                            "! There are ", ncores, " cores available.", sep = "")
                      )
    
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
    
    observe({
      if(input$tower) {
        # setup of tower optional
        optional_params$tower <- "-with-tower"
        #shiny::showNotification("Make sure TOWER_ACCESS_TOKEN is in your environment")
      } else {
        optional_params$tower <- ""
      }
    })
    # 
    observe({
      if(input$save_trimmed) {
        nx_notify_success("fastp-trimmed files will be saved")
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
      nx_notify_success(text = "Project info saved!")
      removeModal()
    })
    
    
    # generate random hashes for multiqc report and nxf temp file names
    mqc_hash <- sprintf("%s_%s.html", as.integer(Sys.time()), digest::digest(runif(1)) )
    nxf_hash <- sprintf("%s_%s.html", as.integer(Sys.time()), digest::digest(runif(1)) )
    
    # dir choose management --------------------------------------
    volumes <- c(Home = fs::path_home(), getVolumes()() )
    shinyDirChoose(input, "fastq_folder", 
                   roots = volumes, 
                   session = session, 
                   restrictions = system.file(package = "base")) 
    
    #-----------------------------------
    # The main work of setting args for the nxf call is done here
    # in case the reactive vals are "", then they are not used by nxf
    #-----------------------------------
    
    output$stdout <- renderPrint({
      
      # show currently selected fastq folder (and count fastq files there)
      if (is.integer(input$fastq_folder)) {
        cat("No fastq folder selected\n")
      } else {
      # hard set fastq folder
        selectedFolder <<- parseDirPath(volumes, input$fastq_folder)
        nfastq <<- length(list.files(path = selectedFolder, pattern = "*fast(q|q.gz)$"))
        
        if(nfastq > 0) {
          nx_notify_success(paste(nfastq, "files found"))
        } else {
          nx_notify_warning("No fastq files found in folder!\nSelect another or check fastq name pattern")
        }
        
        
        # set mxf args here, use in cat as well as in real processx call
        nxf_args <<- c("run" ,"angelovangel/nextflow-fastp",
                       "--readsdir", selectedFolder, 
                       "--fqpattern", input$fqpattern,
                       "-profile", input$nxf_profile, 
                       optional_params$tower,
                       "-with-report", paste(selectedFolder, "/results-fastp/nxf_workflow_report.html", sep = ""),
                       optional_params$mqc)
        
        cat(
          " Selected folder:\n",
          selectedFolder, "\n",
          "------------------\n\n",
          
          
          "Number of fastq files found:\n",
          nfastq, "\n",
          "------------------\n\n")
        
        cat(" Nextflow command to be executed:\n\n",
            "nextflow", nxf_args)
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
        nx_notify_error("Please select a fastq folder first!")
      
      } else if (nfastq == 0) {
        nx_notify_error("No fastq files found in folder!\nSelect another folder or check fastq name pattern")
      
      } else {
        # set run button color to red?
        shinyjs::disable(id = "commands_pannel")
        nx_notify_success("Looks good, starting run...")
         # change label during run
        shinyjs::html(id = "run", html = "Running... please wait")
        progress$set(message = "Processed ", value = 0)
        on.exit(progress$close() )
        
      # Dean Attali's solution
      # https://stackoverflow.com/a/30490698/8040734
        withCallingHandlers({
          shinyjs::html(id = "stdout", "")
          p <- processx::run("nextflow", 
                      args = nxf_args,
                      wd = selectedFolder,
                      #echo_cmd = TRUE, echo = TRUE,
                      stdout_line_callback = function(line, proc) { message(line) }, 
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
          work_dir <- paste(selectedFolder, "/work", sep = "")
          
          rmwork <- system2("rm", args = c("-rf", work_dir))
          if(rmwork == 0) {
            nx_notify_success("Temp work directory deleted")
            cat("deleted", work_dir, "\n")
          } else {
            nx_notify_warning("Could not delete temp work directory!")
          }
          
          # delete trimmed fastq files in case input$save_trimmed
          fastp_trimm_folder <- file.path(selectedFolder, "results-fastp/fastp_trimmed")
          if(!input$save_trimmed) {
            system2("rm", args = c("-rf", fastp_trimm_folder))
            cat("deleted", fastp_trimm_folder, "\n")
          }
            
          # copy mqc and nxf reports to www/ to be able to open, also use hash to enable multiple concurrent users
          mqc_report <- paste(selectedFolder, 
                           "/results-fastp/multiqc_report.html", # make sure the nextflow-fastp pipeline writes to "results-fastp"
                           sep = "")
          nxf_report <- paste(selectedFolder, 
                              "/results-fastp/nxf_workflow_report.html", sep = "")
           
          system2("cp", args = c(mqc_report, paste("www/", mqc_hash, sep = "")) )
          system2("cp", args = c(nxf_report, paste("www/", nxf_hash, sep = "")) )
          
          
          # render the new action buttons to show report
          output$mqc_report_button <- renderUI({
            actionButton("mqc", label = "MultiQC report", 
                         icon = icon("th"), 
                         onclick = sprintf("window.open('%s', '_blank')", mqc_hash)
            )
          })
          # render the new nxf report button
          output$nxf_report_button <- renderUI({
            actionButton("nxf", label = "Nextflow execution report", 
                         icon = icon("th"), 
                         onclick = sprintf("window.open('%s', '_blank')", nxf_hash)
            )
          })
          
          # render outputFilesLocation
          output$outputFilesLocation <- renderUI({
            actionButton("outLoc", label = paste("Where are the results?"), 
                         icon = icon("th"), 
                         onclick = sprintf("window.alert('%s')", paste(selectedFolder,"/results-fastp/")
                                           )
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
      system2("rm", args = c("-rf", paste("www/", nxf_hash, sep = "")) )
      
      #user management
      isolate({
        users$count <- users$count - 1
        writeLines(as.character(users$count), con = "userlog")
      })
      #stopApp()
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
 