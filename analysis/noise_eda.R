options(stringsAsFactors = FALSE, scipen = 999)

raw_path <- "data/raw/microclimate_sensors.csv"
fig_dir <- "figures"
processed_dir <- "data/processed"
dir.create(fig_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(processed_dir, recursive = TRUE, showWarnings = FALSE)

message("Reading full raw dataset...")
d <- read.csv(raw_path, check.names = FALSE, na.strings = c("", "NA", "null"))
names(d)[1] <- sub("^\\ufeff|^\\xef\\xbb\\xbf", "", names(d)[1])

# Parse documented fields without altering the raw file.
time_normalized <- sub("([+-][0-9]{2}):([0-9]{2})$", "\\1\\2", d$Time)
d$timestamp <- as.POSIXct(time_normalized, format = "%Y-%m-%dT%H:%M:%S%z", tz = "Australia/Melbourne")
latlong <- strsplit(d$LatLong, ",", fixed = TRUE)
d$latitude <- suppressWarnings(as.numeric(vapply(latlong, function(x) if (length(x) >= 1) trimws(x[1]) else NA_character_, "")))
d$longitude <- suppressWarnings(as.numeric(vapply(latlong, function(x) if (length(x) >= 2) trimws(x[2]) else NA_character_, "")))
d$Noise <- suppressWarnings(as.numeric(d$Noise))

n_rows <- nrow(d); n_cols <- ncol(d) - 3L # derived fields excluded from raw column count
important <- c("Device_id", "Time", "SensorLocation", "LatLong", "Noise")
missing_table <- data.frame(
  variable = important,
  missing_n = vapply(d[important], function(x) sum(is.na(x) | trimws(as.character(x)) == ""), numeric(1)),
  stringsAsFactors = FALSE
)
missing_table$missing_pct <- 100 * missing_table$missing_n / n_rows

raw_cols <- names(d)[seq_len(n_cols)]
type_table <- data.frame(variable = raw_cols, class = vapply(d[raw_cols], function(x) paste(class(x), collapse = "/"), ""))
duplicate_n <- sum(duplicated(d[raw_cols]))
valid_noise <- d$Noise[is.finite(d$Noise)]
noise_stats <- c(
  n = length(valid_noise), mean = mean(valid_noise), sd = sd(valid_noise), min = min(valid_noise),
  q01 = unname(quantile(valid_noise, .01)), q25 = unname(quantile(valid_noise, .25)),
  median = median(valid_noise), q75 = unname(quantile(valid_noise, .75)),
  q99 = unname(quantile(valid_noise, .99)), max = max(valid_noise)
)
iqr <- IQR(valid_noise)
lower_fence <- unname(quantile(valid_noise, .25)) - 1.5 * iqr
upper_fence <- unname(quantile(valid_noise, .75)) + 1.5 * iqr
extreme_n <- sum(valid_noise < lower_fence | valid_noise > upper_fence)

# Coverage and per-sensor descriptive statistics.
sensor_keys <- unique(d[c("Device_id", "SensorLocation", "latitude", "longitude")])
sensor_split <- split(seq_len(n_rows), d$Device_id)
sensor_coverage <- do.call(rbind, lapply(names(sensor_split), function(id) {
  z <- d[sensor_split[[id]], ]
  nz <- z$Noise[is.finite(z$Noise)]
  data.frame(
    Device_id = id,
    SensorLocation = paste(unique(z$SensorLocation[!is.na(z$SensorLocation) & nzchar(z$SensorLocation)]), collapse = " / "),
    latitude = if (all(is.na(z$latitude))) NA_real_ else median(z$latitude, na.rm = TRUE),
    longitude = if (all(is.na(z$longitude))) NA_real_ else median(z$longitude, na.rm = TRUE),
    first_observation = format(min(z$timestamp, na.rm = TRUE), "%Y-%m-%d %H:%M:%S %Z"),
    last_observation = format(max(z$timestamp, na.rm = TRUE), "%Y-%m-%d %H:%M:%S %Z"),
    coverage_days = as.numeric(difftime(max(z$timestamp, na.rm = TRUE), min(z$timestamp, na.rm = TRUE), units = "days")),
    observations = nrow(z), valid_noise = length(nz),
    missing_noise_pct = 100 * sum(!is.finite(z$Noise)) / nrow(z),
    mean_noise = if (length(nz)) mean(nz) else NA_real_, median_noise = if (length(nz)) median(nz) else NA_real_,
    sd_noise = if (length(nz) > 1) sd(nz) else NA_real_, min_noise = if (length(nz)) min(nz) else NA_real_,
    max_noise = if (length(nz)) max(nz) else NA_real_, stringsAsFactors = FALSE
  )
}))
rownames(sensor_coverage) <- NULL
write.csv(sensor_coverage, file.path(processed_dir, "sensor_coverage_summary.csv"), row.names = FALSE)

# Actual frequency by sensor: positive successive time gaps.
frequency_summary <- do.call(rbind, lapply(names(sensor_split), function(id) {
  tt <- sort(unique(d$timestamp[sensor_split[[id]]]))
  gaps <- as.numeric(diff(tt), units = "mins"); gaps <- gaps[is.finite(gaps) & gaps > 0]
  data.frame(Device_id=id, intervals=length(gaps), median_gap_minutes=if(length(gaps)) median(gaps) else NA_real_,
             p25_gap_minutes=if(length(gaps)) unname(quantile(gaps,.25)) else NA_real_,
             p75_gap_minutes=if(length(gaps)) unname(quantile(gaps,.75)) else NA_real_,
             pct_approximately_15_min=if(length(gaps)) 100*mean(gaps >= 12 & gaps <= 18) else NA_real_)
}))
write.csv(frequency_summary, file.path(processed_dir, "sensor_frequency_summary.csv"), row.names = FALSE)

# Derive temporal variables in Melbourne local time.
d$date <- as.Date(d$timestamp, tz = "Australia/Melbourne")
d$hour <- as.integer(format(d$timestamp, "%H", tz = "Australia/Melbourne"))
d$weekday_num <- as.integer(format(d$timestamp, "%u", tz = "Australia/Melbourne"))
d$weekday <- factor(c("Monday","Tuesday","Wednesday","Thursday","Friday","Saturday","Sunday")[d$weekday_num],
                    levels=c("Monday","Tuesday","Wednesday","Thursday","Friday","Saturday","Sunday"))
d$weekend <- factor(ifelse(d$weekday_num >= 6, "Weekend", "Weekday"), levels=c("Weekday","Weekend"))
d$month <- as.Date(format(d$date, "%Y-%m-01"))

daily <- aggregate(Noise ~ date, d, median, na.rm = TRUE)
names(daily)[2] <- "median_noise"
daily_n <- aggregate(Noise ~ date, d, function(x) sum(is.finite(x)))
names(daily_n)[2] <- "valid_n"
daily <- merge(daily, daily_n, by="date", all=TRUE)
write.csv(daily, file.path(processed_dir, "daily_noise_summary.csv"), row.names = FALSE)

hourly <- aggregate(Noise ~ hour, d, function(x) c(median=median(x,na.rm=TRUE), q25=quantile(x,.25,na.rm=TRUE), q75=quantile(x,.75,na.rm=TRUE), n=sum(is.finite(x))))
hourly <- data.frame(hour=hourly$hour, as.data.frame(hourly$Noise)); names(hourly) <- c("hour","median_noise","q25","q75","valid_n")
weekday_summary <- aggregate(Noise ~ weekday, d, function(x) c(median=median(x,na.rm=TRUE), q25=quantile(x,.25,na.rm=TRUE), q75=quantile(x,.75,na.rm=TRUE), n=sum(is.finite(x))))
weekday_summary <- data.frame(weekday=weekday_summary$weekday, as.data.frame(weekday_summary$Noise)); names(weekday_summary) <- c("weekday","median_noise","q25","q75","valid_n")
weekend_summary <- aggregate(Noise ~ weekend, d, function(x) c(median=median(x,na.rm=TRUE), q25=quantile(x,.25,na.rm=TRUE), q75=quantile(x,.75,na.rm=TRUE), n=sum(is.finite(x))))
weekend_summary <- data.frame(weekend=weekend_summary$weekend, as.data.frame(weekend_summary$Noise)); names(weekend_summary) <- c("period","median_noise","q25","q75","valid_n")

# Robustness checks: sensor composition, balanced panel, and equal-sensor summaries.
valid_d <- d[is.finite(d$Noise), ]
active_sensor_month <- aggregate(Noise ~ month + Device_id, valid_d, length)
names(active_sensor_month)[3] <- "valid_noise_n"
active_month_split <- split(active_sensor_month$Device_id, active_sensor_month$month)
active_sensor_monthly <- data.frame(
  month = as.Date(names(active_month_split)),
  active_noise_sensors = vapply(active_month_split, length, integer(1)),
  sensor_ids = vapply(active_month_split, function(x) paste(sort(x), collapse = "; "), ""),
  stringsAsFactors = FALSE
)
write.csv(active_sensor_monthly, file.path(processed_dir, "active_noise_sensors_by_month.csv"), row.names = FALSE)

active_sensor_day <- aggregate(Noise ~ date + Device_id, valid_d, length)
names(active_sensor_day)[3] <- "valid_noise_n"
active_day_split <- split(active_sensor_day$Device_id, active_sensor_day$date)
calendar_dates <- seq(min(d$date,na.rm=TRUE),max(d$date,na.rm=TRUE),by="day")
active_sensor_daily <- data.frame(date=calendar_dates,active_noise_sensors=0L,sensor_ids="None",stringsAsFactors=FALSE)
matched_days <- match(as.Date(names(active_day_split)),active_sensor_daily$date)
active_sensor_daily$active_noise_sensors[matched_days] <- vapply(active_day_split,length,integer(1))
active_sensor_daily$sensor_ids[matched_days] <- vapply(active_day_split,function(x) paste(sort(x),collapse="; "),"")
write.csv(active_sensor_daily,file.path(processed_dir,"active_noise_sensors_by_day.csv"),row.names=FALSE)
composition_runs <- rle(active_sensor_daily$sensor_ids)
run_end <- cumsum(composition_runs$lengths); run_start <- c(1L,head(run_end,-1L)+1L)
active_sensor_periods <- data.frame(start_date=active_sensor_daily$date[run_start],end_date=active_sensor_daily$date[run_end],days=composition_runs$lengths,sensor_ids=composition_runs$values,stringsAsFactors=FALSE)
write.csv(active_sensor_periods,file.path(processed_dir,"active_noise_sensor_periods.csv"),row.names=FALSE)

# Longest useful early-period balanced group: devices 01--03 overlap from the
# first complete month after device 03 starts through the last complete month
# before device 01 stops. Weekly medians are first computed within sensor.
balanced_ids <- sprintf("ICTMicroclimate-%02d", 1:3)
balanced_start <- as.Date("2023-01-01")
balanced_end <- as.Date("2026-06-30")
balanced_raw <- valid_d[valid_d$Device_id %in% balanced_ids & valid_d$date >= balanced_start & valid_d$date <= balanced_end, ]
balanced_raw$week <- balanced_raw$date - (as.integer(format(balanced_raw$date, "%u")) - 1L)
sensor_week <- aggregate(Noise ~ week + Device_id, balanced_raw, median)
week_sensor_n <- aggregate(Device_id ~ week, sensor_week, length)
complete_weeks <- week_sensor_n$week[week_sensor_n$Device_id == length(balanced_ids)]
balanced_weekly <- aggregate(Noise ~ week, sensor_week[sensor_week$week %in% complete_weeks, ], median)
names(balanced_weekly)[2] <- "balanced_sensor_median"
pooled_period <- valid_d[valid_d$date >= balanced_start & valid_d$date <= balanced_end, ]
pooled_period$week <- pooled_period$date - (as.integer(format(pooled_period$date, "%u")) - 1L)
pooled_weekly <- aggregate(Noise ~ week, pooled_period, median)
names(pooled_weekly)[2] <- "original_pooled_median"
balanced_comparison <- merge(pooled_weekly, balanced_weekly, by = "week", all = FALSE)
write.csv(sensor_week, file.path(processed_dir, "balanced_sensor_weekly_components.csv"), row.names = FALSE)
write.csv(balanced_comparison, file.path(processed_dir, "balanced_sensor_sensitivity.csv"), row.names = FALSE)

# Give every sensor equal weight after computing its own hour/weekday median.
sensor_hour <- aggregate(Noise ~ Device_id + hour, valid_d, median)
standard_hour <- aggregate(Noise ~ hour, sensor_hour, function(x) c(median=median(x), q25=quantile(x,.25), q75=quantile(x,.75), sensors=length(x)))
standard_hour <- data.frame(hour=standard_hour$hour, as.data.frame(standard_hour$Noise)); names(standard_hour) <- c("hour","standardised_median","sensor_q25","sensor_q75","sensor_n")
hour_comparison <- merge(hourly[c("hour","median_noise")], standard_hour, by="hour")
names(hour_comparison)[2] <- "pooled_median"
write.csv(hour_comparison, file.path(processed_dir, "hourly_pooled_vs_sensor_standardised.csv"), row.names = FALSE)

sensor_weekday <- aggregate(Noise ~ Device_id + weekday, valid_d, median)
standard_weekday <- aggregate(Noise ~ weekday, sensor_weekday, function(x) c(median=median(x), q25=quantile(x,.25), q75=quantile(x,.75), sensors=length(x)))
standard_weekday <- data.frame(weekday=standard_weekday$weekday, as.data.frame(standard_weekday$Noise)); names(standard_weekday) <- c("weekday","standardised_median","sensor_q25","sensor_q75","sensor_n")
weekday_comparison <- merge(weekday_summary[c("weekday","median_noise")], standard_weekday, by="weekday", sort=FALSE)
weekday_comparison$weekday <- factor(weekday_comparison$weekday, levels=levels(d$weekday))
weekday_comparison <- weekday_comparison[order(weekday_comparison$weekday),]
names(weekday_comparison)[2] <- "pooled_median"
write.csv(weekday_comparison, file.path(processed_dir, "weekday_pooled_vs_sensor_standardised.csv"), row.names = FALSE)

# Academic-style figures using dependency-free base R.
plot_theme <- function() { grid(nx=NA, ny=NULL, col="#E5E7EB", lty=1); box(bty="l", col="#4B5563") }
png(file.path(fig_dir,"fig1_daily_noise_over_time.png"), 1800, 1000, res=180)
daily_complete <- merge(data.frame(date=calendar_dates),daily,by="date",all.x=TRUE)
par(mar=c(5,5,3,1), las=1); plot(daily_complete$date, daily_complete$median_noise, type="l", lwd=1.35, col="#2166AC", xlab="Date", ylab="Daily median noise (dataset units)", main="Pooled recorded noise over time (changing sensor composition)"); plot_theme(); lines(daily_complete$date,daily_complete$median_noise,lwd=1.35,col="#2166AC"); mtext("Gaps are not connected; available-sensor median, descriptive network series, not a city-wide trend",side=1,line=3.7,cex=.72,col="#555555"); dev.off()

png(file.path(fig_dir,"fig2_noise_by_hour.png"), 1800, 1000, res=180)
par(mar=c(5,5,3,1),las=1); plot(hourly$hour,hourly$median_noise,type="n",xlab="Hour of day (local time)",ylab="Noise (dataset units)",main="Typical recorded noise by hour of day",xaxt="n",ylim=range(c(hourly$q25,hourly$q75),na.rm=TRUE)); polygon(c(hourly$hour,rev(hourly$hour)),c(hourly$q25,rev(hourly$q75)),col="#D8E8F5",border=NA); plot_theme(); polygon(c(hourly$hour,rev(hourly$hour)),c(hourly$q25,rev(hourly$q75)),col=adjustcolor("#A6CEE3",.55),border=NA); lines(hourly$hour,hourly$median_noise,lwd=2,col="#2166AC"); points(hourly$hour,hourly$median_noise,pch=16,col="#2166AC",cex=.7); axis(1,at=0:23); legend("topleft",c("Median","Interquartile range"),lwd=c(2,NA),pch=c(NA,15),col=c("#2166AC",adjustcolor("#A6CEE3",.7)),bty="n"); dev.off()

png(file.path(fig_dir,"fig3_noise_by_weekday.png"), 1800, 1000, res=180)
par(mar=c(5,5,3,1),las=1); mids<-barplot(weekday_summary$median_noise,names.arg=substr(weekday_summary$weekday,1,3),col="#4C78A8",border=NA,ylim=c(0,max(weekday_summary$q75)*1.08),ylab="Noise (dataset units)",xlab="Day of week",main="Typical recorded noise by day of week"); arrows(mids,weekday_summary$q25,mids,weekday_summary$q75,angle=90,code=3,length=.05,col="#1F2937",lwd=1.2); legend("topleft","Bars: median; whiskers: interquartile range",bty="n",cex=.85); dev.off()

png(file.path(fig_dir,"fig6_active_noise_sensors_over_time.png"), 2100, 1500, res=180)
layout(matrix(c(1,2),2,1), heights=c(1,2.3)); par(mar=c(1,9,3,2),las=1)
plot(active_sensor_monthly$month,active_sensor_monthly$active_noise_sensors,type="s",lwd=2,col="#2166AC",xaxt="n",xlab="",ylab="Active sensors",main="Active noise sensors over time",ylim=c(0,max(active_sensor_monthly$active_noise_sensors)+1)); axis(2,at=0:max(active_sensor_monthly$active_noise_sensors)); grid(nx=NA,ny=NULL,col="#E5E7EB"); lines(active_sensor_monthly$month,active_sensor_monthly$active_noise_sensors,type="s",lwd=2,col="#2166AC")
sensor_levels <- sort(unique(active_sensor_month$Device_id)); month_levels <- sort(unique(active_sensor_month$month)); mat <- matrix(0,nrow=length(sensor_levels),ncol=length(month_levels),dimnames=list(sensor_levels,as.character(month_levels))); mat[cbind(match(active_sensor_month$Device_id,sensor_levels),match(active_sensor_month$month,month_levels))] <- 1
par(mar=c(5,9,1,2)); image(as.numeric(month_levels),seq_along(sensor_levels),t(mat),col=c("#F3F4F6","#2C7FB8"),breaks=c(-.5,.5,1.5),axes=FALSE,xlab="Month",ylab=""); axis.Date(1,at=seq(min(month_levels),max(month_levels),by="6 months"),format="%Y-%m"); axis(2,at=seq_along(sensor_levels),labels=sensor_levels,las=1,cex.axis=.72); box(); mtext("Blue = at least one valid noise observation in month; aws5-0999 is absent because all noise is missing",side=1,line=3.6,cex=.72,col="#555555"); dev.off()

png(file.path(fig_dir,"fig7_balanced_sensor_sensitivity.png"), 1900, 1050, res=180)
par(mar=c(5,5,3,1),las=1); yr<-range(c(balanced_comparison$original_pooled_median,balanced_comparison$balanced_sensor_median),na.rm=TRUE); plot(balanced_comparison$week,balanced_comparison$original_pooled_median,type="l",lwd=1.2,col=adjustcolor("#7F8C8D",.8),ylim=yr,xlab="Week",ylab="Weekly median noise (dataset units)",main="Original pooled series versus balanced-sensor sensitivity"); grid(nx=NA,ny=NULL,col="#E5E7EB"); lines(balanced_comparison$week,balanced_comparison$original_pooled_median,lwd=1.2,col=adjustcolor("#7F8C8D",.8)); lines(balanced_comparison$week,balanced_comparison$balanced_sensor_median,lwd=2,col="#B2182B"); legend("topright",c("Original pooled: all active sensors","Balanced: equal median of sensors 01--03"),lwd=c(1.2,2),col=c("#7F8C8D","#B2182B"),bty="n"); mtext("Common period 2023-01-01 to 2026-06-30; only weeks containing all three balanced sensors",side=1,line=3.7,cex=.72,col="#555555"); dev.off()

png(file.path(fig_dir,"fig8_hourly_sensor_standardised.png"), 1800, 1000, res=180)
par(mar=c(5,5,3,1),las=1); plot(hour_comparison$hour,hour_comparison$pooled_median,type="l",lwd=1.5,col="#7F8C8D",xaxt="n",xlab="Hour of day (local time)",ylab="Median noise (dataset units)",main="Hourly noise: pooled versus equal-sensor summary",ylim=range(c(hour_comparison$pooled_median,hour_comparison$standardised_median))); grid(nx=NA,ny=NULL,col="#E5E7EB"); lines(hour_comparison$hour,hour_comparison$pooled_median,lwd=1.5,col="#7F8C8D"); lines(hour_comparison$hour,hour_comparison$standardised_median,lwd=2.2,col="#2166AC"); points(hour_comparison$hour,hour_comparison$standardised_median,pch=16,cex=.65,col="#2166AC"); axis(1,at=0:23); legend("topleft",c("Pooled observations","Median of sensor-specific medians"),lwd=c(1.5,2.2),col=c("#7F8C8D","#2166AC"),bty="n"); dev.off()

png(file.path(fig_dir,"fig9_weekday_sensor_standardised.png"), 1800, 1000, res=180)
par(mar=c(5,5,3,1),las=1); xx<-1:7; plot(xx,weekday_comparison$pooled_median,type="b",pch=1,lwd=1.5,col="#7F8C8D",xaxt="n",xlab="Day of week",ylab="Median noise (dataset units)",main="Weekday noise: pooled versus equal-sensor summary",ylim=range(c(weekday_comparison$pooled_median,weekday_comparison$standardised_median))); grid(nx=NA,ny=NULL,col="#E5E7EB"); lines(xx,weekday_comparison$pooled_median,type="b",pch=1,lwd=1.5,col="#7F8C8D"); lines(xx,weekday_comparison$standardised_median,type="b",pch=16,lwd=2.2,col="#2166AC"); axis(1,at=xx,labels=substr(as.character(weekday_comparison$weekday),1,3)); legend("topleft",c("Pooled observations","Median of sensor-specific medians"),pch=c(1,16),lwd=c(1.5,2.2),col=c("#7F8C8D","#2166AC"),bty="n"); dev.off()

sensor_valid <- sensor_coverage[is.finite(sensor_coverage$median_noise),]
ord <- order(sensor_valid$median_noise)
png(file.path(fig_dir,"fig4_noise_by_sensor.png"), 2000, 1500, res=180)
par(mar=c(5,9,3,1),las=1); y<-seq_along(ord); plot(sensor_valid$median_noise[ord],y,type="n",yaxt="n",xlab="Median noise (dataset units)",ylab="",main="Recorded noise by monitored sensor",xlim=range(c(sensor_valid$mean_noise-sensor_valid$sd_noise,sensor_valid$mean_noise+sensor_valid$sd_noise),na.rm=TRUE)); abline(h=y,col="#F0F0F0"); segments(sensor_valid$mean_noise[ord]-sensor_valid$sd_noise[ord],y,sensor_valid$mean_noise[ord]+sensor_valid$sd_noise[ord],y,col="#9CA3AF",lwd=2); points(sensor_valid$median_noise[ord],y,pch=16,col="#B2182B",cex=.85); axis(2,at=y,labels=sensor_valid$Device_id[ord],las=1,cex.axis=.75); legend("bottomright",c("Median","Mean +/- 1 SD"),pch=c(16,NA),lwd=c(NA,2),col=c("#B2182B","#9CA3AF"),bty="n"); dev.off()

loc <- sensor_coverage[is.finite(sensor_coverage$latitude)&is.finite(sensor_coverage$longitude),]
png(file.path(fig_dir,"fig5_sensor_location_map.png"), 1600, 1300, res=180)
boundary_path <- file.path("data","reference","melbourne_municipal_boundary_coordinates.csv")
boundary <- if (file.exists(boundary_path)) read.csv(boundary_path) else NULL
par(mar=c(5,5,3,1),las=1); valid_loc <- is.finite(loc$median_noise); cexv <- rep(1.3,nrow(loc)); cexv[valid_loc] <- 1.2 + 2.4*(loc$median_noise[valid_loc]-min(loc$median_noise[valid_loc]))/max(diff(range(loc$median_noise[valid_loc])),1e-8)
if (!is.null(boundary)) { plot(boundary$longitude,boundary$latitude,type="n",xlab="Longitude",ylab="Latitude",main="Typical recorded noise at monitored sensor locations",asp=1/cos(mean(boundary$latitude)*pi/180)); for (ring in split(boundary,boundary$ring_id)) polygon(ring$longitude,ring$latitude,col="#EEF2F3",border="#7B8794",lwd=1.2) } else { plot(loc$longitude,loc$latitude,type="n",xlab="Longitude",ylab="Latitude",main="Typical recorded noise at monitored sensor locations",asp=1/cos(mean(loc$latitude)*pi/180)) }
points(loc$longitude[valid_loc],loc$latitude[valid_loc],pch=21,bg=adjustcolor("#D73027",.78),col="white",cex=cexv[valid_loc]); points(loc$longitude[!valid_loc],loc$latitude[!valid_loc],pch=4,col="#374151",lwd=2,cex=1.2); short_id <- sub("ICTMicroclimate-", "", loc$Device_id, fixed=TRUE); label_pos <- rep(3,nrow(loc)); label_pos[loc$Device_id=="ICTMicroclimate-10"] <- 2; label_pos[loc$Device_id=="ICTMicroclimate-11"] <- 4; text(loc$longitude,loc$latitude,labels=short_id,pos=label_pos,cex=.64,font=2); legend("bottomleft",c("Valid Noise (size = median)","No valid Noise"),pch=c(21,4),pt.bg=c("#D73027",NA),col=c("white","#374151"),pt.cex=c(1.5,1),bty="n",cex=.8); mtext("City of Melbourne municipal boundary; monitored sensor locations only",side=1,line=3.7,cex=.72,col="#555555"); dev.off()

# Compact machine-readable results for the narrative writer.
coverage_range <- range(sensor_coverage$coverage_days, na.rm=TRUE)
result <- list(
  n_rows=n_rows,n_cols=n_cols,raw_columns=raw_cols,type_table=type_table,
  earliest=format(min(d$timestamp,na.rm=TRUE),"%Y-%m-%d %H:%M:%S %Z"),latest=format(max(d$timestamp,na.rm=TRUE),"%Y-%m-%d %H:%M:%S %Z"),
  unique_devices=length(unique(d$Device_id)),unique_locations=length(unique(d$SensorLocation)),missing_table=missing_table,
  duplicate_n=duplicate_n,noise_stats=noise_stats,lower_fence=lower_fence,upper_fence=upper_fence,extreme_n=extreme_n,
  sensor_coverage=sensor_coverage,frequency_summary=frequency_summary,hourly=hourly,weekday=weekday_summary,weekend=weekend_summary,
  active_sensor_monthly=active_sensor_monthly,active_sensor_daily=active_sensor_daily,active_sensor_periods=active_sensor_periods,
  balanced_ids=balanced_ids,balanced_start=balanced_start,balanced_end=balanced_end,
  balanced_comparison=balanced_comparison,hour_comparison=hour_comparison,weekday_comparison=weekday_comparison,
  coverage_range=coverage_range,location_count=nrow(loc)
)
saveRDS(result,file.path(processed_dir,"noise_eda_results.rds"))
message("Analysis complete.")
