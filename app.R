library(shiny)
library(bslib)
library(ggplot2)
library(DT)
library(dplyr)

# Define UI ----
ui <- page_sidebar(
  title = "Cumulative Paid Claims Calculator",
  sidebar = sidebar(
    fileInput("claims_data", label = "Upload Claims Data (.csv file)", accept = ".csv"),
    helpText('Note: csv file must have columns with headers "loss_year","dev_year","claims"'),
    numericInput("tf", label = "Tail Factor", value = 1, step = 0.05),
    checkboxInput("show_table", label ="Show Data Table", value = TRUE)
  ),
  card(textOutput(outputId = "title"), 
       dataTableOutput(outputId = "table"), 
       plotOutput(outputId = "plot"))
  )


# Define server logic ----
server <- function(input, output) {
  
  # Validates the given .csv file 
  # validate_data <- reactive({
    
  #})
  
  calc_data <- reactive({
    
    if (is.null(input$claims_data))
      return(NULL)
    
    data <- read.csv((input$claims_data)$datapath)
    
    # For sake of convenience, we assume that: the claims data given has N unique consecutive loss and development years;
    # development years start from 1;
    # and for the jth development year, we have claims data for the first N - j + 1 loss years
    
    loss_years <- sort(unique(data$loss_year))
    dev_years <- sort(unique(data$dev_year))
    N <- length(dev_years)
    
    cum_claims <- data.frame(
      matrix(nrow = N, ncol = (N + 1)),
      row.names = loss_years
    )
    
    colnames(cum_claims) <- 1:(N + 1)
    
    for (j in 1:N) {
      # Sum up claims data to produce cumulative claims
      for (i in 1:(N - j + 1)) {
        cum_claims[i, j] <- sum(data$claims[data$loss_year == loss_years[i] & data$dev_year <= j])
      }
      
      # Calculate projected cumulative claims each loss year for N development years
      if (N - j + 2 < N + 1) {
        for (i in (N - j + 2):N) {
          cum_claims[i, j] <- sum(cum_claims[1:(N - j + 1), j]) / sum(cum_claims[1:(N - j + 1), j - 1]) * cum_claims[i, j - 1]
        }
      }
    }
    
    return(cum_claims)
    
  })
  
  final_data <- reactive({
    
    TAIL_FACTOR <- input$tf
    cum_claims  <- calc_data()
    
    if (is.null(cum_claims))
        return(NULL)
    
    # Calculate projected cumulative claims for (N + 1)th development year
    cum_claims[, N + 1] <- cum_claims[, N] * TAIL_FACTOR
    
    return(round(cum_claims))
    
  })
  
  output$table <- renderDataTable({
    if(input$show_table){

      DT::datatable(data = final_data(), options = list(pageLength = 10),
                    caption = "Cumulative Claims by Development Year against Loss Year")
    }
  })
  
}

# Run the app ----
shinyApp(ui = ui, server = server)
