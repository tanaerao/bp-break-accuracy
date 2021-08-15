##BP Simulator version 1.0.0 by Tanae Rao

library('dplyr','tidyr')

#creates draw by ordering teams by points, then putting them in rooms by fours
simple_generate_draw <- function(currentstate,numteams) {
  currentstate <- currentstate[sample(nrow(currentstate)),] # randomly shuffling teams
  currentstate <- currentstate[with(currentstate, order(-tpoints)),] #ordering by team points
  #converts vector of teams into a 4-by-n array, where n is the number of rooms in the tournament
  draw <- as.array(currentstate$name)
  draw <- t(array(draw, dim=c(4,numteams/4)))
  return(draw)
  #this is *intended* to behave exactly as random pull-ups would behave
}

#takes draw, outputs speaker points for that round
run_round <- function(draw,numteams) {
  roundspeaks <- matrix(0,numteams/4,4)
  for (room in 1:nrow(draw)) {
    roomspeaks <- integer(4)
    team <- 1
    add_demskill <- numeric(4)
    add_speaks <- integer(4)
    while (team <= 4) {
      #computing demonstrated skill and speaker points for each round using the parameter values described in Barnes et al. 2020
      skillnoise <- rnorm(1, mean = 0, sd = 3.02)
      demonstratedskill <- baselineskill[draw[room,team]] + skillnoise
      perceptionnoise <- rnorm(1,mean = 0, sd = 3.67)
      perceivedskill <- as.integer(demonstratedskill + perceptionnoise)
      roomspeaks[team] <- perceivedskill
      
      #catching cases where two teams have received the same speaks, and restarting simulation
      if (team == 4 && (length(unique(roomspeaks)) != 4)) {
        roomspeaks <- integer(4)
        team = 1 
      }
      else {
        add_demskill[team] <- demonstratedskill
        add_speaks[team] <- perceivedskill
        team <- team +1
      }
    }
    #adding the demonstrated skill and speaker points for the round for each team in the room
    roundspeaks[room,] <- roomspeaks
    for (i in 1:4){
      totaldemonstratedskill$tdemskill[draw[room,i]] <<- totaldemonstratedskill$tdemskill[draw[room,i]] + add_demskill[i]
      totalspeaks$tspeaks[draw[room,i]] <<- totalspeaks$tspeaks[draw[room,i]] + add_speaks[i]
    }

  }
  return(roundspeaks)
}

#takes draw, speaks, and round number, returns a df of points each team earned that round in accordance with SQ scoring
sq_score <- function(rounddraw, roundspeaks, roundnum) {
  addpoints <- numeric(32)
  for (room in 1:nrow(rounddraw)) {
    roomspeaks <- roundspeaks[room,]
    roomspeaks <- sort(roomspeaks, decreasing = TRUE)
    
    addpoints[rounddraw[room,which(roundspeaks[room,]==roomspeaks[1])]] <- 3 
    
    addpoints[rounddraw[room,which(roundspeaks[room,]==roomspeaks[2])]] <- 2 
    
    addpoints[rounddraw[room,which(roundspeaks[room,]==roomspeaks[3])]] <- 1 
    
    addpoints[rounddraw[room,which(roundspeaks[room,]==roomspeaks[4])]] <- 0
  }
  return(addpoints)
}

#same as above, but with speaker points scoring
sp_score <- function(rounddraw, roundspeaks, roundnum) {
  #using rounddraw to associate each entry in roundspeaks with the team in that position
  #the speaker points are also the teampoints earned that round (ie, speaks will be used to rank teams for the break, and allocate draws)
  roundspeaks <- as.vector(roundspeaks)
  rounddraw <- as.vector(rounddraw)
  speaks_and_draws <- data.frame(roundspeaks, rounddraw)
  speaks_and_draws <- speaks_and_draws[order(speaks_and_draws$rounddraw),]
  addpoints <- speaks_and_draws$roundspeaks
  
  return(addpoints)
}

#same, but early taper scoring. Only correct for 9 round-tournaments (but will not cause an error for other numbers of rounds)
et_score <- function(rounddraw, roundspeaks, roundnum) {
  addpoints <- numeric(32)
  for (room in 1:nrow(rounddraw)) {
    roomspeaks <- roundspeaks[room,]
    roomspeaks <- sort(roomspeaks, decreasing = TRUE)
    
    multiplier <- 1
    
    if (roundnum == 1) {
      multiplier <- 4
    }
    
    if (roundnum == 2) {
      multiplier <- 3
    }
    
    if (roundnum == 3) {
      multiplier <- 2
    }
    
    if (roundnum == 4) {
      multiplier <- 2
    }
    
    
    addpoints[rounddraw[room,which(roundspeaks[room,]==roomspeaks[1])]] <- 3*multiplier
    
    addpoints[rounddraw[room,which(roundspeaks[room,]==roomspeaks[2])]] <- 2*multiplier
    
    addpoints[rounddraw[room,which(roundspeaks[room,]==roomspeaks[3])]] <- 1*multiplier
    
    addpoints[rounddraw[room,which(roundspeaks[room,]==roomspeaks[4])]] <- 0*multiplier
  }
  return(addpoints)
}

#simulates a tournament once, returns df of performance metrics by team ('results')
simulate_tournament <- function(numteams,numrounds,scoringtype) {
  ##initialising variables
  teampoints <- data.frame(1:numteams,numeric(numteams))
  names(teampoints) <- c('name','tpoints')
  
  #baseline skill is assigned to each team, never gets changed
  baselineskill <<- rnorm(numteams,mean = 150, sd = 6.52)
  
  #demonstrated skill starts at 0 for each team
  totaldemonstratedskill <<- data.frame(1:numteams,numeric(numteams))
  names(totaldemonstratedskill) <<- c('name','tdemskill')
  
  #speaks start at 0 for each team
  totalspeaks <<- data.frame(1:numteams,numeric(numteams))
  names(totalspeaks) <<- c('name','tspeaks')
  
  #for loop creates draw, simulates round, scores round, and adds points to existing points as many times as there are rounds in the tournament
  for (debateround in 1:numrounds) {
    rounddraw <- simple_generate_draw(teampoints, numteams)
    roundspeaks <- run_round(rounddraw,numteams)
    if (scoringtype == 'et') {
      teampoints$tpoints <- teampoints$tpoints + et_score(rounddraw, roundspeaks,debateround)
    }
    if (scoringtype == 'sq') {
      teampoints$tpoints <- teampoints$tpoints + sq_score(rounddraw, roundspeaks,debateround)
    }
    if (scoringtype == 'sp') {
      teampoints$tpoints <- teampoints$tpoints + sp_score(rounddraw, roundspeaks,debateround)
    }
  }
  #returns a df of information it has
  return(data.frame(teampoints,totalspeaks$tspeaks,baselineskill,totaldemonstratedskill$tdemskill))
}

#takes tournament results and returns break quality metrics
calculate_bqm <- function(results,breaksize,numrounds) {
  #infering number of teams in the tournament from entries in results
  numteams <- nrow(results)
  
  #initializing indicator variables (initially at 0) which go to 1 if team is in the break
  results$realbreak <- integer(numteams)
  results$perfectbreak <- integer(numteams)
  
  #initializing break quality metrics 
  hlc <- 0
  mdsactual <- 0
  mdsperfect <- 0
  
  #for loop does a bunch of stuff at the same time, going team by team
  for (team in 1:numteams) {
    #reordering results dataframe by teampoints, then speaks, both in descending order
    results <- results[order(-results$tpoints,-results$totalspeaks.tspeaks),]
    rownames(results) <- NULL
    
    #if the team being analysed as part of the main for loop is within the real break:
    if (team %in% results[1:breaksize,]$name) {
      #...make realbreak 1
      results$realbreak[which(results$name == team)] <- 1
      #...and add tds to mdsactual
      mdsactual <- mdsactual + results$totaldemonstratedskill.tdemskill[which(results$name == team)] 
    }
    
    #reordering results dataframe by total demonstrated skill
    results <- results[order(-results$totaldemonstratedskill.tdemskill),]
    rownames(results) <- NULL
    
    #if the team being analysed as part of the main for loop is within the actual break:
    if (team %in% results[1:breaksize,]$name) {
      #...make perfectbreak 1
      results$perfectbreak[which(results$name == team)] <- 1 
      #...and add tds to mdsperfect
      mdsperfect <- mdsperfect + results$totaldemonstratedskill.tdemskill[which(results$name == team)] 
    }
    
    #if the team is in the perfect break ('deserving') but not in the real break, add 1 to hlc
    if (results$realbreak[which(results$name == team)] == 0 & results$perfectbreak[which(results$name == team)] == 1) {
      hlc <- hlc + 1
    }
    
  }
  #the QDS is the difference between the actual and real mds, adjusted for breaksize and the number of rounds
  #note: neither mdsperfect not mdsactual is actually a *mean* at this point; they are sums
  qds <- (mdsperfect - mdsactual)/(breaksize*numrounds) 
  #adjusting for numrounds here allows us to fairly evaluate the effect of increasing/decreasing the number of rounds in a tournament
  
  return(c(hlc,qds))
}

#takes tournament results and returns order accuracy metrics
calculate_oam <- function(results, breaksize) {
  numteams <- nrow(results)
  
  #assigning numerical 'names' to each team in the results dataframe
  results$name <- 1:numteams
  
  #generating real break and perfect break columns
  #realbreak is 1 if team actually broke, 0 if not
  #perfectbreak is 1 if team deserved to break (as per demonstrated skill), 0 if not
  
  results$realbreak <- integer(numteams)
  results$perfectbreak <- integer(numteams)
  for (team in 1:numteams) {
    results <- results[order(-results$tpoints,-results$totalspeaks.tspeaks),]
    rownames(results) <- NULL
    if (team %in% results$name[1:breaksize]) {
      results$realbreak[which(results$name == team)] <- 1
    }
    
    results <- results[order(-results$totaldemonstratedskill.tdemskill,-results$totalspeaks.tspeaks),]
    rownames(results) <- NULL
    if (team %in% results$name[1:breaksize]) {
      results$perfectbreak[which(results$name == team)] <- 1
    }
  }
  
  #generating real and perfect ranking columns
  #realrank is the team's ordinal ranking on the real tab (e.g., 1 is best team, 2 is second best team)
  #perfectrank is the team's ordinal ranking by demonstrated skill
  
  results <- results[order(-results$tpoints,-results$totalspeaks.tspeaks),]
  results$realrank <- 1:nrow(results)
  
  results <- results[order(-results$totaldemonstratedskill.tdemskill),]
  results$perfectrank <- 1:nrow(results)
  
  #pairwise error count
  
  #generating a df of every pair of teams
  teampairs <- as.data.frame(t(as.data.frame(combn(results$name,2,simplify = TRUE))))
  #initializing pairwise error count at 0
  pec <- 0
  #every time a team is ranked differently in realrank and perfectrank, add 1 to pec
  for (pair in 1:nrow(teampairs)) {
    team1 <- teampairs[pair,1]
    team2 <- teampairs[pair,2]
    
    if ((((results$realrank[which(results$name == team1)]) > (results$realrank[which(results$name == team2)])) &
        ((results$perfectrank[which(results$name == team1)]) < (results$perfectrank[which(results$name == team2)]))) | 
        (((results$realrank[which(results$name == team1)]) < (results$realrank[which(results$name == team2)])) &
        ((results$perfectrank[which(results$name == team1)]) > (results$perfectrank[which(results$name == team2)])))) {
      pec <- pec + 1
    }
  }
  
  #rank difference squared
  #initialize rds at 0
  rds <- 0
  
  #for each team, add to rds the squared difference between realrank and perfectrank
  for (team in 1:length(results)) {
    rds <- rds + (results$realrank[which(results$name == team)]-results$perfectrank[which(results$name == team)])^2
  }
  
  #sum of skill difference
  #initalize ssd at 0
  ssd <- 0
  
  #for each rank, add to ssd the absolute value of the difference between the demonstrated skill of the team that actually ranked there, and the team that should have ranked there
  for (rank in 1:length(results)) {
    ssd <- ssd + abs(results$totaldemonstratedskill.tdemskill[which(results$realrank == rank)]-results$totaldemonstratedskill.tdemskill[which(results$perfectrank == rank)])
  }
  
  return(c(pec,rds,ssd))
  
}

#runs tournaments using each of the et, sq, sp scoring systems, and returns a dataframe of break/order accuracy metrics for each simulated tournament
et_sq_sp_compare <- function(iterations) {
  bqm_sq_hlc <- numeric(iterations)
  bqm_sq_qds <- numeric(iterations)
  bqm_et_hlc <- numeric(iterations)
  bqm_et_qds <- numeric(iterations)
  bqm_sp_hlc <- numeric(iterations)
  bqm_sp_qds <- numeric(iterations)
  
  oam_sq_pec <- numeric(iterations)
  oam_sq_rds <- numeric(iterations)
  oam_sq_ssd <- numeric(iterations)
  oam_et_pec <- numeric(iterations)
  oam_et_rds <- numeric(iterations)
  oam_et_ssd <- numeric(iterations)
  oam_sp_pec <- numeric(iterations)
  oam_sp_rds <- numeric(iterations)
  oam_sp_ssd <- numeric(iterations)
  
  #run tournament, get and record bqms and oams, repeat for each scoring system
  #note: we can't use different scoring systems for the 'same' tournament, because each scoring system affects draws differently
  for (i in 1:iterations) {

    results <- simulate_tournament(360,9,'sq')
    bqm <- calculate_bqm(results,48,9)
    oam <- calculate_oam(results,48)
    
    bqm_sq_hlc[i] <- bqm[1]
    bqm_sq_qds[i] <- bqm[2]
    
    oam_sq_pec[i] <- oam[1]
    oam_sq_rds[i] <- oam[2]
    oam_sq_ssd[i] <- oam[3]
    
    results <- simulate_tournament(360,9,'et')
    bqm <- calculate_bqm(results,48,9)
    oam <- calculate_oam(results,48)
    
    bqm_et_hlc[i] <- bqm[1]
    bqm_et_qds[i] <- bqm[2]
    
    oam_et_pec[i] <- oam[1]
    oam_et_rds[i] <- oam[2]
    oam_et_ssd[i] <- oam[3]
    
    results <- simulate_tournament(360,9,'sp')
    bqm <- calculate_bqm(results,48,9)
    oam <- calculate_oam(results,48)
    
    bqm_sp_hlc[i] <- bqm[1]
    bqm_sp_qds[i] <- bqm[2]
    
    oam_sp_pec[i] <- oam[1]
    oam_sp_rds[i] <- oam[2]
    oam_sp_ssd[i] <- oam[3]
    
  }
  return(data.frame(bqm_sq_hlc,bqm_sq_qds,bqm_et_hlc,bqm_et_qds,bqm_sp_hlc,bqm_sp_qds,oam_sq_pec,oam_sq_rds,oam_sq_ssd,oam_et_pec,oam_et_rds,oam_et_ssd,oam_sp_pec,oam_sp_rds,oam_sp_ssd))
}

#steps to generating the results-et_sq_sp_compare.png plot included in Github

data <- et_sq_sp_compare(100) #this takes about 20 minutes to run on my laptop

par(mfrow=c(2,3))

boxplot(data$bqm_sq_hlc,data$bqm_et_hlc,data$bqm_sp_hlc,outline = FALSE,names = c('SQ','ET','SP'),ylab='Hard Luck Count',
        col=c('#F76C5E','#247BA0','#80D39B'),border = '#061A40')

boxplot(data$bqm_sq_qds,data$bqm_et_qds,data$bqm_sp_qds,outline = FALSE,names = c('SQ','ET','SP'),ylab='Quality Deficit Score',
        col=c('#F76C5E','#247BA0','#80D39B'),border = '#061A40')

boxplot(data$oam_sq_pec,data$oam_et_pec,data$oam_sp_pec,outline = FALSE,names = c('SQ','ET','SP'),ylab='Pairwise Error Count',
        col=c('#F76C5E','#247BA0','#80D39B'),border = '#061A40')
boxplot(data$oam_sq_rds,data$oam_et_rds,data$oam_sp_rds, outline = FALSE,names = c('SQ','ET','SP'),ylab='Rank Difference Squared',
        col=c('#F76C5E','#247BA0','#80D39B'),border = '#061A40')
boxplot(data$oam_sq_ssd,data$oam_et_ssd,data$oam_sp_ssd, outline = FALSE,names = c('SQ','ET','SP'),ylab='Sum of Skill Difference',
        col=c('#F76C5E','#247BA0','#80D39B'),border = '#061A40')

#steps to generating the demskill-teampoints.png plot included in Github

sq <- simulate_tournament(360,9,'sq')
et <- simulate_tournament(360,9,'et')
sp <- simulate_tournament(360,9,'sp')

par(mfrow=c(1,3))

plot(sq$totaldemonstratedskill.tdemskill,sq$tpoints,col='#F76C5E',pch=4,main='SQ',
     xlab='Total Demonstrated Skill',ylab='Team Points')
plot(et$totaldemonstratedskill.tdemskill,et$tpoints,col='#247BA0',pch=4,main='ET',
     xlab='Total Demonstrated Skill',ylab='Team Points')
plot(sp$totaldemonstratedskill.tdemskill,sp$tpoints,col='#80D39B',pch=4,main='SP',
     xlab='Total Demonstrated Skill',ylab='Team Points (Total Speaks)')
