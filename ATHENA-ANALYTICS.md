# VM Metrics Analytics with AWS Athena

This guide shows how to analyze VM utilization metrics stored in S3 using AWS Athena for serverless SQL analytics.

## 📊 Overview

The VM Utilization Agent stores metrics in S3 with the following structure:
```
s3://your-bucket/
└── vm-metrics/
    ├── vm-hostname-1/
    │   ├── metrics_20250604.json
    │   ├── metrics_20250605.json
    │   └── ...
    ├── vm-hostname-2/
    │   ├── metrics_20250604.json
    │   └── ...
    └── ...
```

Each JSON file contains metrics like:
```json
{
  "fields": {
    "usage_active": 23.45,
    "usage_idle": 76.55
  },
  "name": "cpu",
  "tags": {
    "customer_id": "production-env",
    "host": "web-server-01",
    "cpu": "cpu-total"
  },
  "timestamp": 1717459200
}
```

## 🛠 Setup AWS Athena

### Step 1: Create Athena Database

```sql
-- Create database for VM metrics
CREATE DATABASE IF NOT EXISTS vm_metrics_db
COMMENT 'VM utilization metrics analysis'
LOCATION 's3://your-athena-results-bucket/databases/vm_metrics_db/';
```

### Step 2: Create Table Schema

```sql
-- Create table for VM metrics
CREATE EXTERNAL TABLE vm_metrics_db.vm_utilization (
  fields struct<
    usage_active: double,
    usage_idle: double,
    usage_iowait: double,
    usage_system: double,
    usage_user: double,
    used_percent: double,
    available: bigint,
    total: bigint,
    used: bigint,
    free: bigint,
    uptime: bigint,
    uptime_format: string,
    n_cpus: int,
    load1: double,
    load5: double,
    load15: double
  >,
  name string,
  tags struct<
    customer_id: string,
    host: string,
    cpu: string,
    device: string,
    fstype: string,
    mode: string,
    path: string
  >,
  timestamp bigint
)
PARTITIONED BY (
  year string,
  month string,
  day string,
  hostname string
)
STORED AS INPUTFORMAT 'org.apache.hadoop.mapred.TextInputFormat'
OUTPUTFORMAT 'org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat'
LOCATION 's3://your-metrics-bucket/vm-metrics/'
SERDE 'org.openx.data.jsonserde.JsonSerDe'
WITH SERDEPROPERTIES (
  'ignore.malformed.json' = 'true',
  'dots.in.keys' = 'false',
  'case.insensitive' = 'true',
  'mapping' = 'true'
);
```

### Step 3: Add Partitions

You can either add partitions manually or use automatic discovery:

#### Manual Partition Addition
```sql
-- Add partition for specific date and host
ALTER TABLE vm_metrics_db.vm_utilization ADD PARTITION (
  year='2025',
  month='06',
  day='04',
  hostname='web-server-01'
) LOCATION 's3://your-metrics-bucket/vm-metrics/web-server-01/';
```

#### Automatic Partition Discovery
```sql
-- Enable automatic partition discovery
MSCK REPAIR TABLE vm_metrics_db.vm_utilization;
```

## 📈 Analytics Queries

### Basic System Overview

#### 1. Current System Status
```sql
-- Get latest metrics for all VMs
WITH latest_metrics AS (
  SELECT 
    tags.host,
    tags.customer_id,
    name as metric_type,
    fields,
    timestamp,
    ROW_NUMBER() OVER (
      PARTITION BY tags.host, name 
      ORDER BY timestamp DESC
    ) as rn
  FROM vm_metrics_db.vm_utilization
  WHERE year = '2025' AND month = '06' AND day = '04'
)
SELECT 
  host,
  customer_id,
  metric_type,
  CASE 
    WHEN metric_type = 'cpu' THEN fields.usage_active
    WHEN metric_type = 'mem' THEN fields.used_percent
    WHEN metric_type = 'disk' THEN fields.used_percent
  END as utilization_percent,
  from_unixtime(timestamp) as last_update
FROM latest_metrics
WHERE rn = 1
ORDER BY host, metric_type;
```

#### 2. VM Fleet Summary
```sql
-- Overview of all VMs and their current status
SELECT 
  COUNT(DISTINCT tags.host) as total_vms,
  tags.customer_id,
  AVG(CASE WHEN name = 'cpu' THEN fields.usage_active END) as avg_cpu_usage,
  AVG(CASE WHEN name = 'mem' THEN fields.used_percent END) as avg_memory_usage,
  MAX(timestamp) as last_seen
FROM vm_metrics_db.vm_utilization
WHERE year = '2025' AND month = '06' AND day = '04'
  AND timestamp > UNIX_TIMESTAMP() - 300  -- Last 5 minutes
GROUP BY tags.customer_id
ORDER BY avg_cpu_usage DESC;
```

### Performance Analysis

#### 3. CPU Utilization Trends
```sql
-- CPU utilization over time for specific VM
SELECT 
  from_unixtime(timestamp) as time_bucket,
  tags.host,
  fields.usage_active as cpu_usage,
  fields.usage_system as system_cpu,
  fields.usage_user as user_cpu,
  fields.load1 as load_average
FROM vm_metrics_db.vm_utilization
WHERE name = 'cpu'
  AND tags.host = 'web-server-01'
  AND year = '2025' AND month = '06' AND day = '04'
  AND timestamp > UNIX_TIMESTAMP() - 3600  -- Last hour
ORDER BY timestamp;
```

#### 4. Memory Usage Analysis
```sql
-- Memory usage patterns
SELECT 
  tags.host,
  MIN(fields.used_percent) as min_memory_usage,
  AVG(fields.used_percent) as avg_memory_usage,
  MAX(fields.used_percent) as max_memory_usage,
  STDDEV(fields.used_percent) as memory_usage_stddev,
  COUNT(*) as sample_count
FROM vm_metrics_db.vm_utilization
WHERE name = 'mem'
  AND year = '2025' AND month = '06' AND day = '04'
GROUP BY tags.host
HAVING COUNT(*) > 10  -- At least 10 samples
ORDER BY avg_memory_usage DESC;
```

#### 5. Disk Space Monitoring
```sql
-- Disk usage by mount point
SELECT 
  tags.host,
  tags.path as mount_point,
  fields.used_percent as disk_usage_percent,
  ROUND(fields.free / 1024.0 / 1024.0 / 1024.0, 2) as free_gb,
  ROUND(fields.total / 1024.0 / 1024.0 / 1024.0, 2) as total_gb,
  from_unixtime(MAX(timestamp)) as last_update
FROM vm_metrics_db.vm_utilization
WHERE name = 'disk'
  AND year = '2025' AND month = '06' AND day = '04'
  AND tags.path NOT IN ('/dev', '/proc', '/sys')  -- Exclude system mounts
GROUP BY tags.host, tags.path, fields.used_percent, fields.free, fields.total
HAVING fields.used_percent > 80  -- Alert threshold
ORDER BY fields.used_percent DESC;
```

### Alerting and Monitoring

#### 6. High Resource Usage Alert
```sql
-- VMs exceeding resource thresholds
WITH resource_alerts AS (
  SELECT 
    tags.host,
    tags.customer_id,
    name as metric_type,
    CASE 
      WHEN name = 'cpu' AND fields.usage_active > 85 THEN 'HIGH_CPU'
      WHEN name = 'mem' AND fields.used_percent > 90 THEN 'HIGH_MEMORY'
      WHEN name = 'disk' AND fields.used_percent > 95 THEN 'HIGH_DISK'
      WHEN name = 'system' AND fields.load15 > 4 THEN 'HIGH_LOAD'
    END as alert_type,
    CASE 
      WHEN name = 'cpu' THEN fields.usage_active
      WHEN name = 'mem' THEN fields.used_percent
      WHEN name = 'disk' THEN fields.used_percent
      WHEN name = 'system' THEN fields.load15
    END as current_value,
    timestamp,
    from_unixtime(timestamp) as alert_time
  FROM vm_metrics_db.vm_utilization
  WHERE year = '2025' AND month = '06' AND day = '04'
    AND timestamp > UNIX_TIMESTAMP() - 900  -- Last 15 minutes
)
SELECT *
FROM resource_alerts
WHERE alert_type IS NOT NULL
ORDER BY timestamp DESC;
```

#### 7. Availability Monitoring
```sql
-- VMs that haven't reported recently
WITH vm_last_seen AS (
  SELECT 
    tags.host,
    tags.customer_id,
    MAX(timestamp) as last_timestamp,
    from_unixtime(MAX(timestamp)) as last_seen
  FROM vm_metrics_db.vm_utilization
  WHERE year = '2025' AND month = '06' AND day = '04'
  GROUP BY tags.host, tags.customer_id
)
SELECT 
  host,
  customer_id,
  last_seen,
  UNIX_TIMESTAMP() - last_timestamp as seconds_since_last_report
FROM vm_last_seen
WHERE UNIX_TIMESTAMP() - last_timestamp > 600  -- No data for 10+ minutes
ORDER BY seconds_since_last_report DESC;
```

### Historical Analysis

#### 8. Daily Resource Consumption
```sql
-- Daily resource usage summary
SELECT 
  year,
  month,
  day,
  tags.host,
  COUNT(CASE WHEN name = 'cpu' THEN 1 END) as cpu_samples,
  AVG(CASE WHEN name = 'cpu' THEN fields.usage_active END) as avg_daily_cpu,
  MAX(CASE WHEN name = 'cpu' THEN fields.usage_active END) as peak_daily_cpu,
  AVG(CASE WHEN name = 'mem' THEN fields.used_percent END) as avg_daily_memory,
  MAX(CASE WHEN name = 'mem' THEN fields.used_percent END) as peak_daily_memory
FROM vm_metrics_db.vm_utilization
WHERE year = '2025' AND month = '06'
  AND name IN ('cpu', 'mem')
GROUP BY year, month, day, tags.host
ORDER BY year, month, day, tags.host;
```

#### 9. Weekly Performance Trends
```sql
-- Weekly aggregated performance metrics
SELECT 
  YEAR(from_unixtime(timestamp)) as year,
  WEEK(from_unixtime(timestamp)) as week_number,
  tags.customer_id,
  COUNT(DISTINCT tags.host) as active_vms,
  AVG(CASE WHEN name = 'cpu' THEN fields.usage_active END) as avg_cpu,
  PERCENTILE_APPROX(CASE WHEN name = 'cpu' THEN fields.usage_active END, 0.95) as p95_cpu,
  AVG(CASE WHEN name = 'mem' THEN fields.used_percent END) as avg_memory,
  PERCENTILE_APPROX(CASE WHEN name = 'mem' THEN fields.used_percent END, 0.95) as p95_memory
FROM vm_metrics_db.vm_utilization
WHERE year = '2025' AND month = '06'
  AND name IN ('cpu', 'mem')
GROUP BY YEAR(from_unixtime(timestamp)), WEEK(from_unixtime(timestamp)), tags.customer_id
ORDER BY year, week_number;
```

### Cost Optimization

#### 10. Underutilized Resources
```sql
-- Identify underutilized VMs for cost optimization
WITH vm_utilization AS (
  SELECT 
    tags.host,
    tags.customer_id,
    AVG(CASE WHEN name = 'cpu' THEN fields.usage_active END) as avg_cpu,
    AVG(CASE WHEN name = 'mem' THEN fields.used_percent END) as avg_memory,
    COUNT(*) as sample_count
  FROM vm_metrics_db.vm_utilization
  WHERE year = '2025' AND month = '06'
    AND name IN ('cpu', 'mem')
    AND timestamp > UNIX_TIMESTAMP() - 604800  -- Last 7 days
  GROUP BY tags.host, tags.customer_id
  HAVING COUNT(*) > 100  -- Sufficient data points
)
SELECT 
  host,
  customer_id,
  ROUND(avg_cpu, 2) as avg_cpu_percent,
  ROUND(avg_memory, 2) as avg_memory_percent,
  sample_count,
  CASE 
    WHEN avg_cpu < 5 AND avg_memory < 30 THEN 'SIGNIFICANTLY_UNDERUTILIZED'
    WHEN avg_cpu < 15 AND avg_memory < 50 THEN 'UNDERUTILIZED'
    ELSE 'APPROPRIATELY_SIZED'
  END as sizing_recommendation
FROM vm_utilization
WHERE avg_cpu < 20 OR avg_memory < 50
ORDER BY avg_cpu + avg_memory;
```

## 🔧 Advanced Analytics

### Custom Metrics and KPIs

#### 11. Custom Performance Score
```sql
-- Calculate a custom performance score
WITH vm_scores AS (
  SELECT 
    tags.host,
    tags.customer_id,
    -- Performance score (0-100, higher is better performance)
    GREATEST(0, 100 - (
      AVG(CASE WHEN name = 'cpu' THEN fields.usage_active END) * 0.4 +
      AVG(CASE WHEN name = 'mem' THEN fields.used_percent END) * 0.3 +
      AVG(CASE WHEN name = 'disk' THEN fields.used_percent END) * 0.2 +
      AVG(CASE WHEN name = 'system' THEN LEAST(fields.load15 * 25, 100) END) * 0.1
    )) as performance_score,
    COUNT(*) as sample_count
  FROM vm_metrics_db.vm_utilization
  WHERE year = '2025' AND month = '06' AND day = '04'
    AND timestamp > UNIX_TIMESTAMP() - 3600  -- Last hour
  GROUP BY tags.host, tags.customer_id
  HAVING COUNT(*) > 10
)
SELECT 
  host,
  customer_id,
  ROUND(performance_score, 1) as performance_score,
  CASE 
    WHEN performance_score >= 80 THEN 'EXCELLENT'
    WHEN performance_score >= 60 THEN 'GOOD'
    WHEN performance_score >= 40 THEN 'FAIR'
    ELSE 'POOR'
  END as performance_grade,
  sample_count
FROM vm_scores
ORDER BY performance_score DESC;
```

#### 12. Capacity Planning
```sql
-- Capacity planning analysis
WITH hourly_peaks AS (
  SELECT 
    tags.host,
    HOUR(from_unixtime(timestamp)) as hour_of_day,
    MAX(CASE WHEN name = 'cpu' THEN fields.usage_active END) as peak_cpu,
    MAX(CASE WHEN name = 'mem' THEN fields.used_percent END) as peak_memory
  FROM vm_metrics_db.vm_utilization
  WHERE year = '2025' AND month = '06'
    AND name IN ('cpu', 'mem')
    AND timestamp > UNIX_TIMESTAMP() - 604800  -- Last 7 days
  GROUP BY tags.host, HOUR(from_unixtime(timestamp))
)
SELECT 
  host,
  AVG(peak_cpu) as avg_hourly_peak_cpu,
  MAX(peak_cpu) as max_peak_cpu,
  AVG(peak_memory) as avg_hourly_peak_memory,
  MAX(peak_memory) as max_peak_memory,
  -- Capacity recommendations
  CASE 
    WHEN MAX(peak_cpu) > 90 THEN 'UPGRADE_CPU'
    WHEN MAX(peak_memory) > 95 THEN 'UPGRADE_MEMORY'
    WHEN AVG(peak_cpu) < 30 AND AVG(peak_memory) < 40 THEN 'DOWNGRADE_POSSIBLE'
    ELSE 'CURRENT_SIZE_APPROPRIATE'
  END as capacity_recommendation
FROM hourly_peaks
GROUP BY host
ORDER BY max_peak_cpu DESC, max_peak_memory DESC;
```

## 🚀 Performance Optimization

### Query Optimization Tips

1. **Use Partitioning**: Always include partition columns in WHERE clauses
   ```sql
   WHERE year = '2025' AND month = '06' AND day = '04'
   ```

2. **Limit Time Ranges**: Use timestamp filters to reduce data scanned
   ```sql
   AND timestamp > UNIX_TIMESTAMP() - 3600  -- Last hour only
   ```

3. **Use Columnar Formats**: Consider converting to Parquet for better performance
   ```sql
   CREATE TABLE vm_metrics_parquet 
   STORED AS PARQUET
   LOCATION 's3://your-bucket/parquet-data/'
   AS SELECT * FROM vm_metrics_db.vm_utilization;
   ```

4. **Projection Pushdown**: Select only needed columns
   ```sql
   SELECT tags.host, fields.usage_active, timestamp 
   -- Instead of SELECT *
   ```

### Data Lifecycle Management

```sql
-- Create lifecycle partitions for cost optimization
-- Keep recent data in standard storage, archive older data

-- Example: Move data older than 30 days to IA storage
-- This would be configured in S3 lifecycle policies, not SQL
```

## 📋 Setup Checklist

- [ ] Create Athena database
- [ ] Create table schema with appropriate partitions
- [ ] Configure S3 bucket permissions for Athena
- [ ] Set up Athena result bucket
- [ ] Add partitions (manual or automatic)
- [ ] Test basic queries
- [ ] Set up scheduled analysis queries
- [ ] Configure alerts based on query results
- [ ] Optimize table format if needed
- [ ] Set up data lifecycle policies

## 🔗 Integration Examples

### CloudWatch Dashboards
```sql
-- Query for CloudWatch custom metrics
SELECT 
  tags.host as InstanceId,
  AVG(fields.usage_active) as CPUUtilization,
  AVG(fields.used_percent) as MemoryUtilization
FROM vm_metrics_db.vm_utilization
WHERE name IN ('cpu', 'mem')
  AND timestamp > UNIX_TIMESTAMP() - 300
GROUP BY tags.host;
```

### Grafana Integration
Use Athena as a data source in Grafana for custom dashboards.

### Alerting Integration
Export query results to CloudWatch Logs or SNS for alerting.

---

## 📚 Additional Resources

- [AWS Athena Documentation](https://docs.aws.amazon.com/athena/)
- [Athena SQL Reference](https://docs.aws.amazon.com/athena/latest/ug/language-reference.html)
- [S3 Data Partitioning Best Practices](https://docs.aws.amazon.com/athena/latest/ug/partitions.html)
- [JSON SerDe Documentation](https://docs.aws.amazon.com/athena/latest/ug/json-serde.html)

For VM Utilization Agent setup, see [README.md](README.md) 