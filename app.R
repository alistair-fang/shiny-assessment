library(shiny)
library(bslib)
library(ggplot2)
library(DT)
library(dplyr)

ui <-  page_sidebar (
  title = "Cumulative Paid Claims Calculator",
  sidebar = sidebar(
    fileInput("claims_data", label = "Upload Claims Data (.csv file)", accept = ".csv"),
    helpText("Note: csv file must have columns with headers 'loss_year','dev_year','claims'. See README.md for more info"),
    numericInput("tf", label = "Tail Factor", value = 1.1, step = 0.05),
    checkboxInput("show_table", label ="Show Data Table", value = TRUE),
    dataTableOutput(outputId = "table", height = "100%", width = "100%"),
    width = "32.5%"
  ),
  
  card(card_header("Cumulative Paid Claims ($)"),
       plotOutput(outputId = "plot", fill = TRUE)
  )
)

server <- function(input, output) {
  
  # Calculate cumulative claims based on input data
  
  calculate_data <- reactive({
    
    if (is.null(input$claims_data))
      return(NULL)
    
    data <- read.csv((input$claims_data)$datapath)
    
    # For sake of convenience, we assume that: the claims data given has 
    # N unique consecutive loss and development years;
    # development years start from 1;
    # and for the jth development year, we have claims data for the first 
    # N - j + 1 loss years
    
    loss_years <- sort(unique(data$loss_year))
    dev_years <- sort(unique(data$dev_year))
    N <- length(dev_years)
    
    # Initialise data frame to store cumulative claims data 
    
    cum_claims <- data.frame(
      matrix(nrow = N, ncol = (N + 1)),
      row.names = loss_years
    )
    
    colnames(cum_claims) <- 1:(N + 1)
    
    for (j in 1:N) {
      
      # Sum up claims data to produce cumulative claims
      
      for (i in 1:(N - j + 1)) {
        cum_claims[i, j] <- sum(data$claims[data$loss_year == loss_years[i] 
                                            & data$dev_year <= j])
      }
      
      # Calculate projected cumulative claims for N development years
      
      if (N - j + 2 < N + 1) {
        for (i in (N - j + 2):N) {
          cum_claims[i, j] <- sum(cum_claims[1:(N - j + 1), j]) / 
          sum(cum_claims[1:(N - j + 1), j - 1]) * 
          cum_claims[i, j - 1]
        }
      }
    }
    
    return(cum_claims)
    
  })
  
  # Finalise data based on tail factor
  
  final_data <- reactive({
    
    TAIL_FACTOR <- input$tf
    cum_claims  <- calculate_data()
    N           <- ncol(cum_claims) - 1 
    
    if (is.null(cum_claims))
        return(NULL)
    
    # Calculate projected cumulative claims for (N + 1)th development year
    
    cum_claims[, N + 1] <- cum_claims[, N] * TAIL_FACTOR
    
    return(round(cum_claims))
    
  })
  
  # Displays data table if the checkbox is ticked
  
  output$table <- renderDataTable({
    
    final_data <- final_data()
    
    if (is.null(final_data))
      return(NULL)
    
    if(input$show_table){
      DT::datatable(data = final_data, options = list(pageLength = 10),
                    caption = "Rows represent loss year; 
                               Columns represent development year")
    }
  })
  
  # Displays cumulative claims data on  a scatter-plot
  
  output$plot <- renderPlot({
    
    final_data <- final_data()
    
    if (is.null(final_data))
      return(NULL)
    
    # Modify data to a format compatible with ggplot2
    
    plot_data <- final_data %>%
      rownames_to_column (var = "loss_year") %>%
      pivot_longer(cols = -loss_year, 
                   names_to = "development_year", 
                   values_to = "cumulative_claims"
                   )
    
    plot_data$development_year <- as.numeric(plot_data$development_year)
    
    # Plot the data 
    
    ggplot(
      data = plot_data,
      mapping = aes(x = development_year, 
                    y = cumulative_claims,
                    color = loss_year)
    ) +
      geom_point() +
      geom_smooth()
    
  })
}

shinyApp(ui = ui, server = server)
