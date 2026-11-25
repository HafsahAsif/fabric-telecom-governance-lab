# ===================== CELL 1 : setup =====================
# Day 2 - Bronze -> Silver (clean, dedupe, quarantine)
# Author: Hafsah Asif
from pyspark.sql import functions as F
from datetime import datetime

BRONZE   = "lh_bronze"                     # source lakehouse
RUN_TS   = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
FMT      = "delta"
EMAIL_RX = r"^[^@\s]+@[^@\s]+\.[^@\s]+$"

def read_bronze(t):
    return spark.read.table(f"{BRONZE}.{t}")

def write_silver(df, t):
    (df.write.mode("overwrite").option("overwriteSchema", "true")
       .format(FMT).saveAsTable(t))
    print(f"  wrote {t:<28} {df.count():>9,} rows")

def clean_str(c):
    """trim; empty string -> NULL"""
    v = F.trim(F.col(c).cast("string"))
    return F.when(v == "", None).otherwise(v)

def clean_msisdn(c):
    """keep leading zero even if bronze stored it as a number"""
    v = clean_str(c)
    return F.when(v.isNull(), None).otherwise(F.lpad(v, 11, "0"))

def split_valid(df, reason_col="dq_reason"):
    good = df.filter(F.col(reason_col) == "").drop(reason_col)
    bad  = df.filter(F.col(reason_col) != "").withColumn("quarantined_at", F.lit(RUN_TS))
    return good, bad

print("setup ok, run_ts =", RUN_TS)


# ===================== CELL 2 : reference tables =====================
plans = read_bronze("plans").select(
    clean_str("plan_id").alias("plan_id"),
    clean_str("plan_name").alias("plan_name"),
    clean_str("plan_type").alias("plan_type"),
    F.col("monthly_fee_pkr").cast("decimal(12,2)").alias("monthly_fee_pkr"),
    F.col("data_gb").cast("int").alias("data_gb"),
    F.col("voice_mins").cast("int").alias("voice_mins"),
)
regions = read_bronze("regions").select(
    *[clean_str(c).alias(c) for c in ["region_id", "region", "city", "province"]]
)
write_silver(plans, "plans")
write_silver(regions, "regions")


# ===================== CELL 3 : subscribers =====================
raw_s = read_bronze("subscribers")
s = raw_s.select(
    clean_str("subscriber_id").alias("subscriber_id"),
    clean_str("full_name").alias("full_name"),
    clean_str("cnic").alias("cnic"),
    clean_msisdn("msisdn").alias("msisdn"),
    F.lower(clean_str("email")).alias("email"),
    F.to_date(clean_str("date_of_birth")).alias("date_of_birth"),
    clean_str("gender").alias("gender"),
    F.coalesce(clean_str("city"), F.lit("Unknown")).alias("city"),   # completeness: default, not reject
    clean_str("region").alias("region"),
    clean_str("province").alias("province"),
    clean_str("plan_id").alias("plan_id"),
    F.to_date(clean_str("activation_date")).alias("activation_date"),
    clean_str("status").alias("status"),
    F.to_date(clean_str("churn_date")).alias("churn_date"),
)

before = s.count()
s = s.dropDuplicates(["subscriber_id"])                               # uniqueness
print(f"duplicates removed: {before - s.count()}")

s = s.withColumn("dq_reason", F.concat_ws("; ",
        F.when(F.col("cnic").isNull(), F.lit("missing_cnic")),
        F.when(F.col("email").isNull() | ~F.col("email").rlike(EMAIL_RX), F.lit("invalid_email")),
    ))
subs_ok, subs_bad = split_valid(s)
write_silver(subs_ok, "subscribers")
write_silver(subs_bad, "quarantine_subscribers")


# ===================== CELL 4 : cdrs =====================
valid_ids = subs_ok.select("subscriber_id").withColumn("_known", F.lit(1))

c = read_bronze("cdrs").select(
    clean_str("cdr_id").alias("cdr_id"),
    clean_str("subscriber_id").alias("subscriber_id"),
    F.to_timestamp(clean_str("event_ts")).alias("event_ts"),
    clean_str("event_type").alias("event_type"),
    F.col("duration_sec").cast("int").alias("duration_sec"),
    F.col("data_mb").cast("decimal(12,2)").alias("data_mb"),
    clean_msisdn("other_party_msisdn").alias("other_party_msisdn"),
    F.col("charge_pkr").cast("decimal(12,2)").alias("charge_pkr"),
    clean_str("cell_id").alias("cell_id"),
).join(valid_ids, "subscriber_id", "left")

c = c.withColumn("dq_reason", F.concat_ws("; ",
        F.when(F.col("charge_pkr") < 0, F.lit("negative_charge")),              # validity
        F.when(F.col("_known").isNull(), F.lit("unknown_or_quarantined_subscriber")),  # referential integrity
    )).drop("_known")
cdr_ok, cdr_bad = split_valid(c)
write_silver(cdr_ok, "cdrs")
write_silver(cdr_bad, "quarantine_cdrs")


# ===================== CELL 5 : service_requests =====================
sr = read_bronze("service_requests").select(
    clean_str("sr_id").alias("sr_id"),
    clean_str("subscriber_id").alias("subscriber_id"),
    F.to_timestamp(clean_str("opened_ts")).alias("opened_ts"),
    F.to_timestamp(clean_str("closed_ts")).alias("closed_ts"),
    clean_str("category").alias("category"),
    clean_str("priority").alias("priority"),
    clean_str("channel").alias("channel"),
    clean_str("status").alias("status"),
    F.col("resolution_hours").cast("decimal(10,1)").alias("resolution_hours"),
    F.coalesce(clean_str("city"), F.lit("Unknown")).alias("city"),
).join(valid_ids, "subscriber_id", "left")

sr = sr.withColumn("dq_reason", F.concat_ws("; ",
        F.when(F.col("_known").isNull(), F.lit("unknown_or_quarantined_subscriber")),
        F.when((F.col("status") == "Closed") & F.col("closed_ts").isNull(), F.lit("closed_without_close_date")),
    )).drop("_known")
sr_ok, sr_bad = split_valid(sr)
write_silver(sr_ok, "service_requests")
write_silver(sr_bad, "quarantine_service_requests")


# ===================== CELL 6 : run summary =====================
summary = spark.createDataFrame([
    ("subscribers",      raw_s.count(),                      subs_ok.count(), subs_bad.count()),
    ("cdrs",             read_bronze("cdrs").count(),        cdr_ok.count(),  cdr_bad.count()),
    ("service_requests", read_bronze("service_requests").count(), sr_ok.count(), sr_bad.count()),
], ["table", "bronze_rows", "silver_rows", "quarantined_rows"])
display(summary)

for q in ["quarantine_subscribers", "quarantine_cdrs", "quarantine_service_requests"]:
    print(q)
    spark.table(q).groupBy("dq_reason").count().orderBy(F.desc("count")).show(truncate=False)
