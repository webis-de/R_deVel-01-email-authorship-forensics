source("R/packages.R")

# Read data

data_all <- readRDS(file = "data/pan11/processed_data.rds")
names(data_all)

# Look at authors/dep.variable
data_all$candidate %>% table() %>% sort()

data_sub <- 
  data_all %>% 
  group_by(candidate) %>% 
  filter(n() >= 50) %>% 
  as.data.frame()

data_sub$candidate %>% table() %>% sort()


data <- 
  data_sub %>% 
  select(-t,
         -blank_lines,
         -total_lines,
         -number_stopwords,
         -number_shortwords,
         -M,
         -V,
         -C) 

names(data)


# Z-standardize
data_z <- 
  data %>% 
  mutate_at(vars(-one_of("candidate","text")),
            funs(as.vector(scale(.))))

data_z[data_z == "NaN"] <- 0

model_data_all <- 
  data_z %>% 
  select(-text)%>% # this has to be fixed
  na.omit()

# Get frequencies
ggplot(data = model_data_all) +
  geom_bar(aes(x = candidate),stat = "count")+
  geom_text(aes(x = candidate,label = ..count..),nudge_y = 20,stat = "count")+
  theme(axis.text = element_text(angle = 90, hjust = 1,vjust = 1)) +
  labs(title = "Author Frequency")

##### 




sub_cands <- sample(x = unique(model_data_all$candidate),size = 3,replace = F)

model_data <- 
  model_data_all %>% 
  filter(candidate %in% sub_cands) %>% 
  group_by(candidate) %>% 
  sample_n(round(50))

names(model_data)

subsett <- function(i,total,split) {
  df = data.frame(x = 1:total,
             y = rep(c(1:split),each = total/split,len = total))
  return(df[df$y == i,1])
}

subsett(i = 10,total = 50,split = 10)

# Splitting in training and test data
results <- data.frame()
q = 1

for(q in 1:10){

model_data <- 
  model_data %>% 
  group_by(candidate) %>% 
  mutate(lfdn = sample(x = 1:n(),size = n(),replace = FALSE))

training_data <- 
  model_data %>% 
  filter(!lfdn %in% subsett(i = q,total = 50,split = 10))


testing_data <- 
  model_data %>% 
  filter(lfdn %in% subsett(i = q,total = 50,split = 10))

names(training_data)


# Tune 1
svm_tune1 <- 
    tune(svm, factor(candidate)~ -lfdn, data = training_data,
         kernel="radial", type = "C-classification",
         ranges=list(cost=10^(-3:5), 
                     gamma=10^(-3:5)),
         tunecontrol = tune.control(sampling = "cross")
         )
svm_tune1

## classification mode
# default with factor response:
model <- svm(candidate ~ 
             -lfdn,
             data = training_data,
             gamma = svm_tune1$best.parameters$gamma,
             cost = svm_tune1$best.parameters$cost,
             kernel = "radial",
             type = "C-classification")

print(model)
summary(model)


# Calculate Decision Values and Probabilities
predictions <- predict(model,
                 testing_data,
                 decision.values = TRUE)
str(predictions)
attr(predictions, "decision.values")

# Check accuracy:

t1 <- table(predicted = predictions,
                  actual_author = testing_data$candidate) ; t1

t2 <- round(table(predicted = predictions,
                  actual_author = testing_data$candidate) %>% prop.table(2),2); t2

(precision <- diag(t1) / rowSums(t1))
(recall <- (diag(t1) / colSums(t1)))

(f <- (2*(precision*recall))/(precision+recall))

accuracy <- length(which(predictions == testing_data$candidate))/length(predictions);accuracy

out_pre <- sum(precision,na.rm = TRUE)/3
out_rec <- sum(recall,na.rm = TRUE)/3
out_f <- f

results  <- 
  bind_rows(results,
                      data.frame(loop = q,
                                 precision = out_pre,
                                 recall = out_rec,
                                 f_score = f,
                                 accuracy = accuracy)
)

}
