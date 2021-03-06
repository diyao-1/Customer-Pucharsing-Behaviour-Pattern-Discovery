install.packages("tm")
# install the packages
library(readr)
library(tidyverse)
library(tidytext)
library(skimr)
library(dplyr)
library(purrr)
library(cluster)
library(factoextra)
library(corrplot)
library(arules)
library(arulesViz)
library(psych)
library(GPArotation)
library(leaflet)
library(tm)
library(wordcloud)
library(quanteda)
library(topicmodels)

# load the datasets
customer <- read.csv('data/olist_customers_dataset.csv')
order_item <- read.csv('data/olist_order_items_dataset.csv')
customer <- read.csv('data/olist_customers_dataset.csv')
order_item <- read.csv('data/olist_order_items_dataset.csv')
order_payment <- read.csv('data/olist_order_payments_dataset.csv')
order_reviews <- read.csv('data/olist_order_reviews_dataset.csv')
order <- read.csv('data/olist_orders_dataset.csv')
order_product <- read.csv('data/olist_products_dataset.csv')
product <- read.csv('data/olist_products_dataset.csv')
location <- read.csv('data/olist_geolocation_dataset.csv')
sellers <- read.csv('data/olist_sellers_dataset.csv')
order_reviews_translated <- read.csv("data/Translated_reviews - order_review_translated.csv")

location1 = location %>% group_by(geolocation_zip_code_prefix) %>% 
  summarize(mean_lat = mean(geolocation_lat),
            mean_long = mean(geolocation_lng))

### join all the dataset. 

##p<- left_join(left_join(left_join(customer, order, by = 'customer_id'),order_item,by = 'order_id'),order_product, by = 'product_id')
##transaction <- left_join(p,order_payment, by = "order_id")

p<- left_join(left_join(left_join(customer, order),order_item),order_product)
transaction <- left_join(p,order_payment)
transaction1 <- left_join(transaction,location1,
                          by = c("customer_zip_code_prefix"="geolocation_zip_code_prefix"))
transaction2 <- na.omit(left_join(transaction1,sellers))

transaction <- transaction2 %>%
  mutate(major_state = if_else(customer_state == c('SP','RJ','MG','BA','PA','PE'), 1, 0))

transaction$order_estimated_delivery_date <- as.POSIXct(transaction$order_estimated_delivery_date, format="%Y-%m-%d %H:%M:%S")
transaction$order_approved_at <- as.POSIXct(transaction$order_approved_at, format="%Y-%m-%d %H:%M:%S")
transaction$order_delivered_customer_date <- as.POSIXct(transaction$order_delivered_customer_date, format="%Y-%m-%d %H:%M:%S")
transaction$deliverd_difftime <- as.numeric(difftime(transaction$order_delivered_customer_date ,transaction$order_estimated_delivery_date)/3600/24)

transaction <- na.omit(transaction)




nume_tra= transaction %>% select(-customer_zip_code_prefix, -order_item_id,-customer_id, -customer_unique_id, -customer_city, -customer_city, 
                                      -customer_state,-order_id:-order_estimated_delivery_date, 
                                      -product_id:-shipping_limit_date, -product_category_name, -payment_type, -payment_installments)


## Assoction Rule
###saves singe transaction to csv. 
# save it as rds if we have time
##tr4 = transaction %>% 
##select(customer_unique_id,product_category_name)
##readr::write_csv(tr4,"data/tran4.csv")

# get the tr4 into the transaction format
t = read.transactions("data/tran4.csv",
                       format = "single",
                       header = T,
                       sep = ",",
                       cols=c("customer_unique_id","product_category_name"),
                       rm.duplicates = T
)
summary(t)
# establish the rules with 0.1% support and confidence level
rules = apriori(t,
                 parameter = list(supp = .001,
                                  conf = .001,
                                  minlen = 2,
                                  target = "rules"))
summary(rules)
inspect(rules)
# {moveis_decoracao} => {cama_mesa_banho}
# furniture_decoration -> bed table bath
# The only two rules are the relationship between furnitures and bed bath table
# The total transaction we use for this rule is around 95.

# If we want to establish more rules with lower support .01%
rules1 = apriori(t,
                 parameter = list(supp = .0001,
                                  conf = .001,
                                  minlen = 2,
                                  target = "rules"))
summary(rules1)
inspect(rules1)

#### Comments:
# we have a set of 146 rules when we have 0.01% support and 0.01% confidence
## sort the rules decreasing by lift - print out the first 5

inspect(head(sort(rules1,decreasing = T, by = "lift"),5))
#{cama_mesa_banho}& {casa_conforto}
#{casa_conforto}&{cama_mesa_banho}


## Conclusion: seems we can not get meaningful association rules,
## We want to discover some other interesting patterns from transaction dataset.


#########################################
## Discover Patterns

## Get to know our customers purchasing behaviours
# The distribution of customers purchasing products in 3 categories:
# home_comfort, bed table bath, furniture_decoration
# whether there are any location pattern
rules_geo <- transaction %>% 
  filter(product_category_name %in% c('casa_conforto','cama_mesa_banho',
                                      'moveis_decoracao'))
rules_geo <- rules_geo %>% select(-customer_id,-customer_unique_id)
# to check city pattern
rules_geo %>% group_by(customer_city) %>%
  count(sort = T) %>%
  print(15)
rules_geo %>% group_by(customer_zip_code_prefix) %>%
  count(sort = T) %>% 
  print(15)
## comments: The top two 2 cities are sao paulo(3602) and rio de janeiro(1595). 
###try map
leaflet() %>%
  addTiles() %>%
  addCircleMarkers(rules_geo$mean_long,
                   rules_geo$mean_lat,
                   color = rules_geo$product_category_name,
                   radius = 0.5,
                   fill = T,
                   fillOpacity = 0.2,
                   opacity = 0.6,
                   popup = paste(rules_geo$product_category_name,
                                 rules_geo$mean_lat,rules_geo$mean_long,sep = "")) %>%
  addLegend("topright",
            colors = c("#a9a9a9","red", "blue"),
            labels = c('casa_conforto','cama_mesa_banho','moveis_decoracao'),
            opacity = 2.0)
### I DONT THINK this pattern works     
### R will nearly crush by this function, BE CAREFUL


## Text Analysis
View(order_reviews_translated)
names(order_reviews_translated)
order_reviews = na.omit(order_reviews_translated)
order_reviews$review_comments = tolower(order_reviews$review_comments)
order_reviews1 <- order_reviews %>%
  unnest_tokens(token, review_comment_message) 

stopwords::stopwords_getsources() 
stopwords::stopwords_getlanguages("misc") 
stopwords::stopwords_getlanguages("snowball") 
stopwords::stopwords_getlanguages("stopwords-iso") 
stopwords::stopwords_getlanguages("smart") 

order_reviews2 <- order_reviews1 %>%
  anti_join(get_stopwords(), by = c('token' = 'word')) 
order_reviews_sum <- order_reviews2 %>%
  group_by(token) %>%
  count(sort = T)

## Word Cloud Plot
wordcloud(words = order_reviews_sum$token,
          freq = order_reviews_sum$n, min.freq = 10, max.words = 50)

## there is Chinese word, interesting....


## LDA model
order_reviews_corpus <- corpus(order_reviews$review_comment_message) 
order_reviews_corpus1 <- tm_map(order_reviews_corpus, removeWords, c("de", "o", "que", "e"))

summary(order_reviews_corpus, n = 20, showmeta = T) 
order_reviews_dfm <- dfm(order_reviews_corpus,remove_punct= T,remove = stopwords(), remove_numbers= T, remove_symbols= T) %>%
  dfm_trim(min_termfreq = 2, max_docfreq = .5,
           docfreq_type = "prop") 
order_reviews_dtm <- convert(order_reviews_dfm, 'topicmodels')
order_reviews_lda <- LDA(order_reviews_dtm, k = 2, control = list(seed = 729))
terms(order_reviews_lda, 10)



delivery <- transaction %>% 
  select(customer_zip_code_prefix:customer_state, order_purchase_timestamp:order_estimated_delivery_date,
         product_category_name, mean_lat, mean_long)

## The Dilivery Process
# Can we figure out in which city has shorter dilivery time
delivery <- transaction %>% 
  select(customer_zip_code_prefix:customer_state, order_purchase_timestamp:order_estimated_delivery_date,
         product_category_name, mean_lat, mean_long)
delivery$order_estimated_delivery_date <- as.POSIXct(delivery$order_estimated_delivery_date, format="%Y-%m-%d %H:%M:%S")
delivery$order_approved_at <- as.POSIXct(delivery$order_approved_at, format="%Y-%m-%d %H:%M:%S")
delivery$order_delivered_customer_date <- as.POSIXct(delivery$order_delivered_customer_date, format="%Y-%m-%d %H:%M:%S")
delivery$deliverd_difftime <- as.numeric(difftime(delivery$order_delivered_customer_date ,delivery$order_estimated_delivery_date)/3600/24)

hist(delivery$deliverd_difftime)
delivery_late <- delivery %>% filter(deliverd_difftime > 0)
head(delivery_late)
delivery_late %>% 
  group_by(customer_city) %>% 
  summarise(late_deliver_city = mean(deliverd_difftime)) %>% 
  arrange(desc(late_deliver_city)) %>%
  print(n=15)
# Commits: The top 3 cities that have largest average develiery late are
# 1 montanha                        182. 
# 2 perdizes                        163. 
# 3 macapa                          145. 
##is there certain goods/ city have higher possibility to late 
zip_late <- delivery_late %>% group_by(customer_zip_code_prefix) %>% 
  count(sort = T) %>% 
  zip_total <- transaction2 %>% group_by(customer_zip_code_prefix) %>% 
  count(sort= T)

zip <- left_join(zip_late, zip_total,by = ("customer_zip_code_prefix"))
zip <- left_join(zip, location1, by = c("customer_zip_code_prefix"='geolocation_zip_code_prefix'))
zip <- zip %>% mutate(late_rate = n.x/n.y) %>% arrange(late_rate)

## make total order more than 20 and late rate more than 0.3
zip_filter <- zip %>% filter(late_rate >= 0.2& n.y >= 10) 
leaflet() %>%
  addTiles() %>%
  addCircleMarkers(zip_filter$mean_long,
                   zip_filter$mean_lat,
                   color = zip$late_rate,
                   radius = 0.5,
                   fill = T,
                   fillOpacity = 0.2,
                   opacity = 0.6)

##conclusion: is look like rural area may have more delay 

### is there any pattern on product catogory? 
ggplot(delivery_late,aes(x =product_category_name))+
  geom_bar()
delivery_late %>% 
  group_by(product_category_name) %>% 
  summarise(late_deliver_cat = mean(deliverd_difftime)) %>% 
  arrange(desc(late_deliver_cat)) %>%
  print(n=15)
# Commits: The top 3 product category that have largest develiery late are
# 1 eletrodomesticos_2                    19.9
# 2 moveis_colchao_e_estofado             15.7
# 3 climatizacao                          15.1

### to see catogrial pattern
late_categories <- delivery_late %>% group_by(product_category_name) %>% 
  summarise(mean = mean(deliverd_difftime),
            late = n()) %>% 
  arrange(desc(late))
category <- transaction %>% 
  group_by(product_category_name) %>% 
  summarise(total = n()) %>%
  arrange(desc(total))
cate <- left_join(late_categories, category)  
cate <- cate %>% mutate(ratio = late/total) %>% 
  arrange(desc(ratio))
cate_filter <- cate %>% filter(total >= 1000)
### we can choose some different criterion

## Supply Side - applied for SCM
supply <- transaction %>% 
  select(seller_city, customer_city, price) %>% 
  na.omit()
# We wanna analyze the goods transportaition between cities
# weighted by the value of the goods
supply %>% 
  group_by(seller_city,customer_city) %>%
  summarise(ave_price = mean(price)) %>% 
  ungroup() %>% 
  arrange(desc(ave_price)) %>% 
  print(n=15)
## Commits: Top 3 pairs
# 1 londrina      vitoria                   6729 
# 2 goiania       marilia                   6499 
# 3 sao paulo     bom jesus do galho        4100.


## But things are not that simple.
## When it comes to the logistic transportation or inventory management,
## the size and weight of the products are also important.

## Payment Method - applied for the markeing/ opeartion
payment <- transaction %>% 
  select(customer_unique_id, price, freight_value, product_category_name, payment_type,
         payment_value)


## Clustering

##  choose numerical value
transac = transaction %>% select("payment_installments","payment_sequential",
                                 "product_weight_g","freight_value","payment_value","deliverd_difftime")
t_k = transac

### scale the data
j = scale(t_k)

### cluster plot 
k = kmeans(j, centers=4, iter.max=25, nstart=25)
fviz_cluster(k, data=j)

merge <- cbind(transac, cluster = k$cluster, major = transaction$major_state, state = transaction$customer_state)
con <- merge %>% group_by(cluster) %>% 
  summarise(weight=mean(product_weight_g),
            payment_value = mean(payment_value),
            timedif = mean(deliverd_difftime),
            payment_installments = mean(payment_installments),
            major_state = mean(major))

cluster1 <- merge %>% filter(cluster == 1)
cluster2 <- merge %>% filter(cluster == 2)            
cluster3 <- merge %>% filter(cluster == 3) 
cluster4 <- merge %>% filter(cluster == 4)

state1 <- as.data.frame(table(cluster1$state))
state2 <- as.data.frame(table(cluster2$state))
state3 <- as.data.frame(table(cluster3$state))
state4 <- as.data.frame(table(cluster4$state))

top5 <- state4[state4$Freq %in% tail(sort(state4$Freq),5),] 

ggplot(top5, aes(x=reorder(Var1,Freq), y=Freq, fill=Var1))+
  geom_bar(position = 'stack', stat = 'identity')+
  scale_fill_discrete(name = "City", labels = c('Minas Gerais','Paraná','Rio de Janeiro','Rio Grande do Sul','São Paulo'))+
  labs(title = "City Buy Most Valuable Products", 
       x = "City")+
  scale_fill_manual(values=c("#fec44f", "#56B1F7","#E69F00","#addd8e","#fc9272"))

###########################################################################
