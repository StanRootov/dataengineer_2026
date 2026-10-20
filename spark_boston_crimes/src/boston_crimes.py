import argparse
from pyspark.sql import SparkSession
from pyspark.sql.window import Window
from pyspark.sql import functions as F
from pyspark.sql.types import (
    StructType,
    StructField,
    StringType,
    IntegerType,
    DoubleType,
    TimestampType,
)



def parse_args():
    parser = argparse.ArgumentParser()

    parser.add_argument(
        "--input",
        required=True,
        help="Path to input data folder",
    )

    parser.add_argument(
        "--output",
        required=True,
        help="Path to output folder",
    )

    return parser.parse_args()

def read_data(spark, input_path):
    crime_schema = StructType([
                                StructField("INCIDENT_NUMBER", StringType(), True),
                                StructField("OFFENSE_CODE", IntegerType(), True),
                                StructField("OFFENSE_CODE_GROUP", StringType(), True),
                                StructField("OFFENSE_DESCRIPTION", StringType(), True),
                                StructField("DISTRICT", StringType(), True),
                                StructField("REPORTING_AREA", StringType(), True),
                                StructField("SHOOTING", StringType(), True),
                                StructField("OCCURRED_ON_DATE", TimestampType(), True),
                                StructField("YEAR", IntegerType(), True),
                                StructField("MONTH", IntegerType(), True),
                                StructField("DAY_OF_WEEK", StringType(), True),
                                StructField("HOUR", IntegerType(), True),
                                StructField("UCR_PART", StringType(), True),
                                StructField("STREET", StringType(), True),
                                StructField("Lat", DoubleType(), True),
                                StructField("Long", DoubleType(), True),
                                StructField("Location", StringType(), True),
                            ])
    
    offense_codes_schema = StructType([
                                StructField("CODE", IntegerType(), True),
                                StructField("NAME", StringType(), True),
                            ])
    
    crimes = (
        spark.read
        .option("header", True)
        .schema(crime_schema)
        .csv(f"{input_path}/crime.csv")
    )

    offense_codes = (
        spark.read
        .option("header", True)
        .schema(offense_codes_schema)
        .csv(f"{input_path}/offense_codes.csv")
    )

    return crimes, offense_codes

def clean_crimes(crimes):
    crimes_clean = (
                        crimes
                        .dropDuplicates()
                        .filter(
                                    F.col("DISTRICT").isNotNull()
                                    & (F.trim(F.col("DISTRICT")) != "")
                                )
                        .select(
                                    F.col("INCIDENT_NUMBER"),
                                    F.col("OFFENSE_CODE"),
                                    F.col("DISTRICT"),
                                    F.col("OCCURRED_ON_DATE"),
                                    F.col("YEAR"),
                                    F.col("MONTH"),
                                    F.when(F.col("Lat") == -1, None).otherwise(F.col("Lat")).alias("lat"),
                                    F.when(F.col("Long") == -1, None).otherwise(F.col("Long")).alias("lng")
                                )    
                    )
    return crimes_clean

def clean_offense_codes(offense_codes):
    offense_codes_clean = (
                                offense_codes
                                .groupBy("CODE")
                                .agg(F.min("NAME").alias("NAME"))
                                .select(
                                    F.col("CODE"),
                                    F.col("NAME"),
                                    F.trim(F.split(F.col("NAME"), "-")[0]).alias("crime_type")
                                )    
                            )
    return offense_codes_clean

def enrich_crimes(crimes_clean, offense_codes_clean):
    crimes_enriched = (
                            crimes_clean
                            .join(
                                    F.broadcast(offense_codes_clean.select("CODE", "crime_type")), 
                                    crimes_clean.OFFENSE_CODE == offense_codes_clean.CODE, 
                                    how="left"                     
                                )
                            .drop("CODE")
                        )

    return crimes_enriched

def build_district_stats(crimes_enriched):
    district_stats = (
                        crimes_enriched
                        .groupBy("DISTRICT")
                        .agg(
                                F.count("*").alias("crimes_total"),
                                F.avg("lat").alias("lat"),
                                F.avg("lng").alias("lng")
                        )

                    )
    return district_stats

def build_monthly_stats(crimes_enriched):
    monthly_stats = (
                        crimes_enriched
                        .groupBy("DISTRICT", "YEAR", "MONTH")
                        .agg(F.count("*").alias("crimes_month"))
                        .groupBy("DISTRICT")
                        .agg(
                                F.percentile_approx(
                                                    F.col("crimes_month"), 
                                                    0.5
                                                   ).alias("crimes_monthly"))
                    )
    return monthly_stats

def build_frequent_crime_types(crimes_enriched):
    district_crime_types = (
                                crimes_enriched
                                .groupBy("DISTRICT", "crime_type")
                                .agg(F.count("*").alias("crime_count"))
                                
                            )
    window_spec = Window.partitionBy("DISTRICT").orderBy(F.col("crime_count").desc(), F.col("crime_type").asc())

    top_3_crimes = (
                        district_crime_types
                        .withColumn("rn", F.row_number().over(window_spec))
                        .filter(F.col("rn") <= 3)
                    )

    frequent_crime_types = (
                                top_3_crimes
                                .groupBy("DISTRICT")
                                .agg(
                                        F.concat_ws(
                                                        ", ",
                                                        F.transform(
                                                                        F.sort_array(
                                                                            F.collect_list(
                                                                                F.struct(F.col("rn"), F.col("crime_type"))
                                                                            )
                                                                        ),
                                                                        lambda x: x["crime_type"]
                                                                    )
                                                    ).alias("frequent_crime_types")
                                    )
                            )

    return frequent_crime_types

def build_mart(crimes_enriched):
    district_stats = build_district_stats(crimes_enriched)
    monthly_stats = build_monthly_stats(crimes_enriched)
    frequent_crime_types = build_frequent_crime_types(crimes_enriched)

    mart = (
                district_stats
                .join(
                        monthly_stats,
                        on="DISTRICT",
                        how="left"
                     )
                .join(
                        frequent_crime_types,
                        on="DISTRICT",
                        how="left"
                    )
                .select(
                            F.col("DISTRICT").alias("district"),
                            F.col("crimes_total"),
                            F.col("crimes_monthly"),
                            F.col("frequent_crime_types"),
                            F.col("lat"),
                            F.col("lng"),
                        )
            )
    return mart

def write_result(mart, output_path):
    (
        mart
        .coalesce(1)
        .write
        .mode("overwrite")
        .parquet(output_path)
    )

def main():
    args = parse_args()

    spark = (
        SparkSession.builder
        .appName("BostonCrimesMart")
        .getOrCreate()
    )
    spark.sparkContext.setLogLevel("WARN")

    crimes, offense_codes = read_data(spark, args.input)

    crimes_clean = clean_crimes(crimes)
    offense_codes_clean = clean_offense_codes(offense_codes)

    crimes_enriched = enrich_crimes(
        crimes_clean,
        offense_codes_clean,
    )

    # mart = build_mart(crimes_enriched)

    # write_result(mart, args.output)

    # print("crimes_clean:", crimes_clean.count())
    # print("crimes_enriched:", crimes_enriched.count())

    # print(
    #     "crime_type NULL:",
    #     crimes_enriched
    #     .filter(F.col("crime_type").isNull())
    #     .count()
    # )

    # crimes_enriched.explain("formatted")

    # district_stats = build_district_stats(crimes_enriched)

    # district_stats.orderBy("DISTRICT").show(truncate=False)

    # print(build_monthly_stats(crimes_enriched).orderBy("DISTRICT").show())

    # print(build_frequent_crime_types(crimes_enriched).show(truncate=False))

    mart = build_mart(crimes_enriched)

    # mart.orderBy("district").show(
    #     truncate=False
    # )

    # print("mart rows:", mart.count())

    # mart.agg(
    #             F.sum("crimes_total")
    #         ).show()

    # mart.select([
    #                 F.count(
    #                             F.when(F.col(c).isNull(), 1)
    #                         ).alias(c)
    #                         for c in mart.columns
    #             ]).show()

    write_result(mart, args.output)

    spark.stop()

if __name__ == "__main__":
    main()