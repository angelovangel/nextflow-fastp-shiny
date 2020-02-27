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
 #library(shinycssloaders)
 
 
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
            includeCSS("css/customProgress.css"),
            useShinyjs(),
            useShinyalert(),
            
            shinyDirButton(id = "fastq_folder", label = "Select fastq folder", title = "Please select a fastq folder"),
            actionButton("run", "Run nextflow-fastp pipeline", 
                         style = "color: green; font-weight: bold;", 
                         onMouseOver = "this.style.color = 'orange' ", 
                         onMouseOut = "this.style.color = 'green' "),
            actionButton("reset", "Reset", 
                         style = "color: green; font-weight: bold;",
                         onMouseOver = "this.style.color = 'orange' ",
                         onMouseOut = "this.style.color = 'green' "),
              
            verbatimTextOutput("stdout")
    ),
    tabPanel("Help", 
             includeMarkdown("help.md"))
    
  )
 }
 #### server ####
  server <- function(input, output, session) {
    options(shiny.launch.browser = TRUE, shiny.error=recover)
    
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
        shinyjs::hide("fastq_folder")
        cat(
          parseDirPath(volumes, input$fastq_folder), "\n", 
          nfastq, " fastq files found", sep = ""
        )
       }
    })

    #---
    # real call to nextflow-fastp-------
    #----      
    # setup progress bar and callback function to update it
    progress <- shiny::Progress$new(min = 0, max = 1, style = "old")
    
    
    # callback function, to be called from run() on each chunk of output
    cb_count <- function(chunk, process) {
      counts <- str_count(chunk, pattern = "fastp on")
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
        shinyjs::toggleState(id = "fastpButton")
        shinyjs::disable(id = "run")
        progress$set(message = "Processing... ", value = 0)
        on.exit(progress$close() )
        
      # Dean Attali's solution
        withCallingHandlers({
          shinyjs::html(id = "stdout", "")
          p <- processx::run("nextflow", 
                      args = c("run" ,
                               "nextflow-fastp", # in case it is pulled before with nextflow pull and is in ~/.nextflow
                               # fs::path_abs("nextflow-fastp/main.nf"), # absolute path to avoid pulling from github
                               "--readsdir", 
                               parseDirPath(volumes, input$fastq_folder)), 
                      wd = parseDirPath(volumes, input$fastq_folder),
                      #echo_cmd = TRUE, echo = TRUE,
                      stdout_line_callback = function(line, proc) {message(line)}, 
                      stdout_callback = cb_count,
                      stderr_to_stdout = TRUE, 
                      error_on_status = FALSE
                      )
          }, 
          message = function(m) {shinyjs::html(id = "stdout", html = m$message, add = TRUE)}
        )
        if(p$status == 0) {
          
          # clean scratch dir in case run finished ok
          scratch_dir <- paste(parseDirPath(volumes, input$fastq_folder), "/work", sep = "")
          system2("rm", args = c("-rf", scratch_dir) )
          cat("deleted", scratch_dir)
          
          # copy mqc to www/ to be able to open it, also use hash to enable multiple concurrent users
          
          mqc_report <- paste(parseDirPath(volumes, input$fastq_folder), 
                           "/results-fastp/multiqc_report.html", # make sure the nextflow-fastp pipeline writes to "results-fastp"
                           sep = "")
           
          system2("cp", args = c(mqc_report, paste("www/", mqc_hash, sep = "")) )
          
          # OK alert
          shinyjs::toggleState(id = "fastpButton") # make fastpButton active again
          
          # the next two change the text and function of the run button
          shinyjs::html(id = "run", 
                        html = sprintf("<a href='%s' target='_blank'>Show MultiQC report</a>", mqc_hash) )
          shinyjs::show(id = "run", anim = TRUE, animType = "fade", time = 1)
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
          shinyjs::toggleState(id = "fastpButton")
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
               callbackJS = "function(x) { if (x == true) {history.go(0);} }" # restart app by reloading page
      )
    })
   
    
 }
 
 shinyApp(ui, server)
 