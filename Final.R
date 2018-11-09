library(httr)
library(jsonlite)
library(RCurl)
library(ggplot2)
library(dplyr)
library(lubridate)

#log in the system with NASA EarthData account username and password
secret <- base64_enc(paste("henryxie1003", "100394Xie", sep = ":"))
response <- POST("https://lpdaacsvc.cr.usgs.gov/appeears/api/login", 
                 add_headers("Authorization" = paste("Basic", gsub("\n", "", secret)),
                             "Content-Type" = "application/x-www-form-urlencoded;charset=UTF-8"), 
                 body = "grant_type=client_credentials")

#check log in status
token_response <- prettify(toJSON(content(response), auto_unbox = TRUE))
token_response

response_p <- GET("https://lpdaacsvc.cr.usgs.gov/appeears/api/product")
product_response <- toJSON(content(response_p), auto_unbox = TRUE)

# create a list indexed by the product name and version
products <- fromJSON(product_response)
products <- setNames(split(products, seq(nrow(products))), products$ProductAndVersion)

# create a task request
task <- '{
          "task_type": "point",
"task_name": "my-task",
"params":{
"dates": [
{
  "startDate": "01-01-2008",
  "endDate": "06-30-2018"
}],
  "layers": [
  {
"product": "MOD13A2.006",
  "layer": "_1_km_16_days_NDVI"
  }],
  "coordinates": [
  {
  "latitude": 43.0444,
  "longitude": -78.7833
  }]
}
}'
task <- fromJSON(task)
task <- toJSON(task, auto_unbox=TRUE)

#submit the task request
token <- paste("Bearer", fromJSON(token_response)$token)
response <- POST("https://lpdaacsvc.cr.usgs.gov/appeears/api/task", body = task, encode = "json", 
                 add_headers(Authorization = token, "Content-Type" = "application/json"))
task_response <- prettify(toJSON(content(response), auto_unbox = TRUE))
task_response

#retrieve the task detail
token <- paste("Bearer", fromJSON(token_response)$token)
task_id <- fromJSON(task_response)$task_id
response <- GET(paste("https://lpdaacsvc.cr.usgs.gov/appeears/api/task/", task_id, sep = ""), add_headers(Authorization = token))
task_response <- prettify(toJSON(content(response), auto_unbox = TRUE))
task_response

#bundle API
token <- paste("Bearer", fromJSON(token_response)$token)
response <- GET(paste("https://lpdaacsvc.cr.usgs.gov/appeears/api/bundle/", task_id, sep = ""), add_headers(Authorization = token))
bundle_response <- prettify(toJSON(content(response), auto_unbox = TRUE))
bundle_response

#Download file

#get csv file id and name
file_list<-fromJSON(bundle_response)$files
file_id<-file_list$file_id[file_list$file_type=="csv"]
file_name<-file_list$file_name[file_list$file_id==file_id]

# create a destination directory to store the file in
dest_dir <- getwd()
filepath <- paste(dest_dir, file_name, sep = '/')
suppressWarnings(dir.create(dirname(filepath)))

# write the file to disk using the destination directory and file name 
response <- GET(paste("https://lpdaacsvc.cr.usgs.gov/appeears/api/bundle/", task_id, '/', file_id, sep = ""),
                write_disk(filepath, overwrite = TRUE), progress(), add_headers(Authorization = token))

#read and view data
data<-read.csv(file_name)
View(data)

#read data from my github
data<-read.csv(text=getURL("https://raw.githubusercontent.com/AdamWilsonLabEDU/geo503-2018-finalproject-Henryxie1003/master/my-task-MOD13A2-006-results.csv"))
View(data)

#data wrangling
#filter out cloudy pixel and add year marker to each observation
data_nonCloud<-filter(data,MOD13A2_006__1_km_16_days_VI_Quality_MODLAND!='0b10'& MOD13A2_006__1_km_16_days_VI_Quality_Adjacent_cloud_detected!='0b1'& data$MOD13A2_006__1_km_16_days_VI_Quality_Aerosol_Quantity!='0b11')
data_nonCloud$Year<-substr(data_nonCloud$Date,1,4)
data_nonCloud$NumDays<-yday(data_nonCloud$Date)


#plot data
ggplot(data_nonCloud,aes(x=NumDays,y=MOD13A2_006__1_km_16_days_NDVI,col=Year))+
  geom_smooth(method='auto',span=0.55,fill=NA,se=F)+
  ylim(0.0,1.0)+
  labs(x='Number of days',y='NDVI')+
  theme_bw()
