# Phase 09 – Amazon RDS PostgreSQL Monitoring with Amazon CloudWatch

## 1. Purpose

The purpose of this phase was to implement operational monitoring for the Amazon RDS for PostgreSQL database deployed in Phase 08.

Amazon CloudWatch metrics and alarms were defined through Terraform to provide a staged monitoring model for database resource utilization, capacity, connectivity, memory pressure, and storage I/O performance.

The monitoring configuration extends the project from simply deploying an RDS database to implementing a basic **database reliability and observability model**.

The monitoring architecture follows this pattern:

```text
Amazon RDS PostgreSQL
        │
        │ Publishes RDS Metrics
        ▼
Amazon CloudWatch
        │
        ├── CPUUtilization
        ├── FreeStorageSpace
        ├── DatabaseConnections
        ├── FreeableMemory
        ├── ReadLatency
        └── WriteLatency
        │
        ▼
CloudWatch Alarms
        │
        ▼
Amazon SNS Topic
        │
        ▼
Notification Target
(if a subscription is configured)
```

---

**Current Repository State:** The Phase 09 monitoring design is retained as staged Terraform configuration under `future/`. The associated RDS PostgreSQL instance was previously deployed and validated during Phase 08 and was later destroyed to avoid ongoing AWS charges. The CloudWatch alarms and SNS integration documented in this phase therefore represent retained future-state monitoring configuration rather than currently deployed monitoring resources.

---
## 2. Objectives

The objectives of Phase 09 were to:

1. Monitor RDS PostgreSQL CPU utilization.
2. Monitor remaining database storage capacity.
3. Monitor active database connections.
4. Monitor available database memory.
5. Monitor database read latency.
6. Monitor database write latency.
7. Associate CloudWatch alarms with the RDS DB instance.
8. Integrate database alarms with the staged Amazon SNS alerts topic defined in `future/sns.tf`.
9. Establish monitoring that reflects a basic production-style database reliability model.
10. Provide CloudWatch visibility that can later be expanded into database dashboards and additional operational alerts.

---

## 3. Prerequisites

Before implementing this phase, the following components were required:

* Terraform installed and configured.
* AWS CLI configured with appropriate AWS credentials.
* Existing Terraform project structure.
* Existing VPC and networking resources from previous project phases.
* Staged Amazon RDS PostgreSQL configuration from Phase 08, including `aws_db_instance.postgres`.
* Staged Amazon SNS alert topic configuration represented by `aws_sns_topic.alerts`.

```hcl
aws_sns_topic.alerts
```

* AWS permissions to manage:

  * Amazon CloudWatch alarms
  * Amazon RDS resources
  * Amazon SNS resources

The CloudWatch alarms depend on the RDS instance because the database instance identifier is used as the CloudWatch metric dimension.

---

## 4. Implementation

### 4.1 Create the RDS Monitoring Terraform File

During Phase 09 development, a dedicated `rds_monitoring.tf` file was created to separate database monitoring resources from the primary RDS infrastructure configuration. In the reconciled repository, this file is retained as `future/rds_monitoring.tf`.

This created:

```text
future/
├── rds.tf
├── rds_monitoring.tf
├── sns.tf
├── variables_rds.tf
├── outputs_rds.tf
└── ...
```

Separating monitoring resources into `rds_monitoring.tf` improves organization and makes the relationship between infrastructure and observability easier to maintain.

---

### 4.2 Configure the High CPU Alarm

The following alarm monitors average RDS CPU utilization:

```hcl
resource "aws_cloudwatch_metric_alarm" "rds_high_cpu" {
  alarm_name          = "${var.project_name}-${var.environment}-rds-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "RDS PostgreSQL CPU utilization is above 80%"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.postgres.id
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-rds-high-cpu"
    Project     = var.project_name
    Environment = var.environment
  }
}
```

This alarm enters the alarm state when average CPU utilization exceeds **80% for two evaluation periods**.

With a five-minute period, this configuration helps identify sustained CPU pressure rather than reacting immediately to a brief CPU spike.

---

### 4.3 Configure the Low Storage Alarm

The following alarm monitors available RDS storage:

```hcl
resource "aws_cloudwatch_metric_alarm" "rds_low_storage" {
  alarm_name          = "${var.project_name}-${var.environment}-rds-low-storage"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 2147483648
  alarm_description   = "RDS PostgreSQL free storage is below 2 GB"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.postgres.id
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-rds-low-storage"
    Project     = var.project_name
    Environment = var.environment
  }
}
```

The threshold:

```text
2147483648 bytes
```

is equivalent to approximately `2 GB`, or exactly `2 GiB` using binary units.

This alarm provides an early warning when database storage approaches exhaustion.

Storage exhaustion is particularly important for database workloads because insufficient free storage can interfere with database growth, temporary operations, logging, and normal database availability.

---

### 4.4 Configure the Database Connections Alarm

The following alarm monitors database connections:

```hcl
resource "aws_cloudwatch_metric_alarm" "rds_high_connections" {
  alarm_name          = "${var.project_name}-${var.environment}-rds-high-connections"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "RDS PostgreSQL database connections are above expected threshold"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.postgres.id
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-rds-high-connections"
    Project     = var.project_name
    Environment = var.environment
  }
}
```

This alarm provides visibility into connection growth and can help identify:

* Unexpected application connection increases.
* Connection pooling problems.
* Excessive idle sessions.
* Connection leaks.
* Workload increases.
* Potential exhaustion of database connection capacity.

The threshold of `80` is appropriate as a project monitoring baseline but should be tuned for an actual production system based on the database instance class, PostgreSQL configuration, application connection behavior, and established workload baselines.

---

### 4.5 Configure the Low Memory Alarm

The following alarm monitors available memory:

```hcl
resource "aws_cloudwatch_metric_alarm" "rds_low_memory" {
  alarm_name          = "${var.project_name}-${var.environment}-rds-low-memory"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "FreeableMemory"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 134217728
  alarm_description   = "RDS PostgreSQL freeable memory is below 128 MB"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.postgres.id
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-rds-low-memory"
    Project     = var.project_name
    Environment = var.environment
  }
}
```

The threshold:

```text
134217728 bytes
```

is equivalent to approximately `128 MB`, or exactly `128 MiB` using binary units.

The `FreeableMemory` metric provides visibility into memory pressure on the RDS instance.

Sustained low available memory may indicate:

* Increased database workload.
* Excessive database connections.
* Memory-intensive queries.
* Insufficient database instance sizing.
* PostgreSQL memory configuration that requires further investigation.

---

### 4.6 Configure the High Read Latency Alarm

The following alarm monitors storage read latency:

```hcl
resource "aws_cloudwatch_metric_alarm" "rds_high_read_latency" {
  alarm_name          = "${var.project_name}-${var.environment}-rds-high-read-latency"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "ReadLatency"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 0.1
  alarm_description   = "RDS PostgreSQL read latency is above 100 ms"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.postgres.id
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-rds-high-read-latency"
    Project     = var.project_name
    Environment = var.environment
  }
}
```

The `ReadLatency` metric is measured in seconds.

Therefore:

```text
0.1 seconds = 100 milliseconds
```

Sustained read latency above the configured threshold may indicate storage contention, increased workload, inefficient queries, or an RDS/storage configuration requiring further investigation.

---

### 4.7 Configure the High Write Latency Alarm

The following alarm monitors storage write latency:

```hcl
resource "aws_cloudwatch_metric_alarm" "rds_high_write_latency" {
  alarm_name          = "${var.project_name}-${var.environment}-rds-high-write-latency"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "WriteLatency"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 0.1
  alarm_description   = "RDS PostgreSQL write latency is above 100 ms"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.postgres.id
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-rds-high-write-latency"
    Project     = var.project_name
    Environment = var.environment
  }
}
```

The alarm detects sustained average write latency greater than:

```text
0.1 seconds = 100 milliseconds
```

Elevated write latency can indicate:

* Storage contention.
* Heavy write activity.
* Transaction-intensive workloads.
* Database checkpoint activity.
* Insufficient storage performance.
* Workload or database design issues requiring investigation.

---

### 4.8 Complete Monitoring Configuration

The completed Phase 09 monitoring configuration provides coverage for six important RDS metrics:

| Metric                | Alarm Condition     | Operational Purpose               |
| --------------------- | ------------------- | --------------------------------- |
| `CPUUtilization`      | Greater than 80%    | Detect sustained CPU pressure     |
| `FreeStorageSpace`    | Less than 2 GiB     | Detect storage capacity risk      |
| `DatabaseConnections` | Greater than 80     | Detect abnormal connection growth |
| `FreeableMemory`      | Less than 128 MiB   | Detect memory pressure            |
| `ReadLatency`         | Greater than 100 ms | Detect degraded read performance  |
| `WriteLatency`        | Greater than 100 ms | Detect degraded write performance |

Each alarm uses the following RDS dimension:

```hcl
dimensions = {
  DBInstanceIdentifier = aws_db_instance.postgres.id
}
```

This associates the CloudWatch metric with the PostgreSQL RDS instance definition from Phase 08. That RDS instance is not currently deployed; its Terraform configuration is retained under `future/`.

Each staged alarm is configured to send alarm actions to:

```hcl
aws_sns_topic.alerts.arn
```

This creates the operational flow:

```text
RDS Metric
    │
    ▼
CloudWatch Alarm
    │
    ▼
SNS Topic
    │
    ▼
Notification Target
(if configured separately)
```

---

## 5. Deployment

The commands in this section describe the Terraform workflow that would be used when integrating and deploying the staged Phase 09 monitoring configuration. The CloudWatch alarms, SNS topic, and associated RDS instance are not currently deployed.

After the staged configuration has been integrated into a complete Terraform root module, formatting, validation, and execution-plan review should be performed before deployment.

### 5.1 Format Terraform Configuration

```powershell
terraform fmt
```

Expected result:

Terraform automatically formats the new monitoring configuration if formatting changes are required.

---

### 5.2 Validate Terraform Configuration

```powershell
terraform validate
```

Expected result:

```text
Success! The configuration is valid.
```

---

### 5.3 Review the Terraform Execution Plan

```powershell
terraform plan
```

The plan should show the new CloudWatch alarm resources that Terraform intends to create.

Expected resources include:

```text
aws_cloudwatch_metric_alarm.rds_high_cpu
aws_cloudwatch_metric_alarm.rds_low_storage
aws_cloudwatch_metric_alarm.rds_high_connections
aws_cloudwatch_metric_alarm.rds_low_memory
aws_cloudwatch_metric_alarm.rds_high_read_latency
aws_cloudwatch_metric_alarm.rds_high_write_latency
```

The execution plan should be reviewed before making changes to the AWS environment.

---

### 5.4 Apply the Configuration

If the plan is correct:

```powershell
terraform apply
```

Review the proposed changes and approve the deployment when prompted.

When the staged RDS, SNS, and monitoring configuration is integrated and deployed, Terraform creates the CloudWatch alarms and associates them with the RDS PostgreSQL instance and SNS notification topic.

---

## 6. Validation

The validation procedures below document how the monitoring resources should be verified when the staged configuration is deployed. They do not describe the current AWS environment.

### 6.1 Validate with Terraform

Run:

```powershell
terraform state list
```

Verify that the following resources are represented in Terraform state:

```text
aws_cloudwatch_metric_alarm.rds_high_cpu
aws_cloudwatch_metric_alarm.rds_low_storage
aws_cloudwatch_metric_alarm.rds_high_connections
aws_cloudwatch_metric_alarm.rds_low_memory
aws_cloudwatch_metric_alarm.rds_high_read_latency
aws_cloudwatch_metric_alarm.rds_high_write_latency
```

This confirms Terraform is managing the monitoring resources.

---

### 6.2 Validate CloudWatch Alarms in the AWS Console

Navigate to:

```text
AWS Management Console
    → CloudWatch
    → Alarms
    → All alarms
```

Verify that alarms exist for:

* RDS high CPU utilization
* RDS low free storage
* RDS high database connections
* RDS low freeable memory
* RDS high read latency
* RDS high write latency

For each alarm, verify:

* The metric namespace is `AWS/RDS`.
* The correct metric is selected.
* The correct RDS DB instance identifier is configured.
* The expected threshold is present.
* The evaluation period is correct.
* The SNS topic is configured as the alarm action.

An alarm may initially appear as:

```text
INSUFFICIENT_DATA
```

until enough CloudWatch metric samples have been collected.

Under normal conditions, alarms should eventually transition to:

```text
OK
```

unless a configured threshold has been exceeded.

---

### 6.3 Validate RDS Metrics

Navigate to:

```text
AWS Management Console
    → RDS
    → Databases
    → PostgreSQL DB Instance
    → Monitoring
```

Review available RDS monitoring data such as:

```text
CPUUtilization
DatabaseConnections
FreeableMemory
FreeStorageSpace
ReadLatency
WriteLatency
```

This confirms that the database is publishing operational metrics that correspond to the configured CloudWatch alarms.

---

### 6.4 Validate SNS Integration

Navigate to:

```text
AWS Management Console
    → SNS
    → Topics
    → Alerts Topic
```

Confirm that the SNS topic referenced by:

```hcl
aws_sns_topic.alerts.arn
```

exists and is associated with the CloudWatch alarms.

If an SNS subscription is added separately, verify that the subscription is confirmed or otherwise active before relying on it for notification delivery.

---

### 6.5 Validate Dashboard Visibility

RDS metrics can also be displayed through Amazon CloudWatch dashboards to provide a centralized operational view of the database.

A conceptual dashboard can include:

```text
┌─────────────────────────────────────────────┐
│        RDS PostgreSQL Monitoring            │
├─────────────────────┬───────────────────────┤
│ CPU Utilization     │ Freeable Memory       │
├─────────────────────┼───────────────────────┤
│ Free Storage Space  │ DB Connections        │
├─────────────────────┼───────────────────────┤
│ Read Latency        │ Write Latency         │
└─────────────────────┴───────────────────────┘
```

**Important:** The Terraform notes for this phase create the CloudWatch alarms but do not contain an `aws_cloudwatch_dashboard` resource. Therefore, the documentation should not state that a custom Terraform-managed RDS dashboard was deployed unless that resource is added separately.

The RDS monitoring views available through the AWS Console can still be used to visualize these metrics.

---

## 7. Architecture

The monitoring architecture introduced in this phase can be represented as:

```text
                       AWS Cloud
┌──────────────────────────────────────────────────────────┐
│                                                          │
│              Existing VPC Infrastructure                 │
│                                                          │
│      ┌────────────────────────────────────────────┐      │
│      │              Private Subnets               │      │
│      │                                            │      │
│      │        Amazon RDS PostgreSQL               │      │
│      │                                            │      │
│      └──────────────────┬─────────────────────────┘      │
│                         │                                │
│                         │ AWS/RDS Metrics                │
│                         ▼                                │
│               ┌────────────────────┐                    │
│               │ Amazon CloudWatch  │                    │
│               └─────────┬──────────┘                    │
│                         │                                │
│          ┌──────────────┼───────────────┐                │
│          │              │               │                │
│          ▼              ▼               ▼                │
│       CPU / Memory   Storage / Conn.   I/O Latency       │
│          │              │               │                │
│          └──────────────┼───────────────┘                │
│                         │                                │
│                         ▼                                │
│                CloudWatch Alarms                         │
│                         │                                │
│                         ▼                                │
│                    Amazon SNS                            │
│                         │                                │
└─────────────────────────┼────────────────────────────────┘
                          │
                          ▼
                  Notification Target
                  (if subscription configured)
```

Phase 09 does not change the network path to the database.

The validated Phase 08 RDS design places the database in private subnets. If the Phase 09 monitoring configuration is integrated and deployed, CloudWatch monitoring adds operational visibility without introducing public database access.

---

## 8. Results and Operational Significance

Phase 09 defined a Terraform-based monitoring layer for the PostgreSQL database environment and retained that configuration for future integration.

The staged monitoring configuration is designed to provide visibility into:

```text
Compute
   └── CPU utilization

Memory
   └── Freeable memory

Capacity
   └── Free storage space

Connectivity
   └── Database connections

Storage Performance
   ├── Read latency
   └── Write latency
```

CloudWatch alarms convert these metrics into operational conditions that can generate notifications through Amazon SNS.

This represents an important distinction between simply deploying infrastructure and operating infrastructure reliably.

The staged monitoring model provides the foundation for:

* Proactive database monitoring.
* Capacity management.
* Performance troubleshooting.
* Operational alerting.
* Incident investigation.
* Database reliability engineering practices.

When deployed with the staged RDS and SNS components, the monitoring configuration would provide infrastructure-level observability across compute, memory, storage, connection, and I/O performance signals.

---

## 9. Security Considerations

The Phase 09 monitoring design was defined without changing the network security posture established in previous phases.

### 9.1 RDS Remains Private

CloudWatch monitoring does not require the RDS database to become publicly accessible.

The Phase 08 RDS design places PostgreSQL within the private subnet architecture, and the Phase 09 monitoring configuration does not alter that network posture.

```text
Internet
   │
   ▼
Public Subnet
   │
   │ Controlled Access
   ▼
Private Subnets
   │
   ▼
RDS PostgreSQL
   │
   │ Operational Metrics
   ▼
Amazon CloudWatch
   │
   ▼
Amazon SNS
```

Monitoring therefore adds observability without introducing an inbound Internet path to the database.

### 9.2 Security Group Controls Remain in Effect

The existing database security group remains the intended control point for PostgreSQL network access when the staged RDS configuration is deployed.

CloudWatch metric collection does not require opening PostgreSQL port `5432` to the Internet.

### 9.3 No Database Credentials Are Stored in CloudWatch Alarms

The CloudWatch alarm resources reference:

```hcl
DBInstanceIdentifier = aws_db_instance.postgres.id
```

They do not require the PostgreSQL username or password.

Database credentials should therefore remain separate from monitoring configuration.

### 9.4 SNS Access Should Be Controlled

The SNS topic used for operational alerts should be protected through appropriate AWS IAM permissions and topic policies.

Only authorized resources and identities should be able to publish to, modify, or subscribe to the notification topic.

### 9.5 Least-Privilege IAM Should Be Maintained

Users, roles, and automation interacting with CloudWatch and SNS should receive only the permissions required for their operational responsibilities.

Monitoring infrastructure should not require broad administrative privileges during normal operation.

### 9.6 Monitoring Does Not Replace Database Auditing

CloudWatch infrastructure metrics provide information about database resource behavior but do not provide complete visibility into individual SQL statements, user activity, database authorization events, or PostgreSQL auditing.

Additional database logging and auditing capabilities would be required for deeper database security monitoring.

### 9.7 Operational Data Should Be Protected

CloudWatch alarms, dashboards, and SNS notifications may expose operational information such as:

* Database identifiers.
* Resource utilization.
* Capacity conditions.
* Performance degradation.
* Infrastructure naming conventions.

Access to monitoring and notification information should therefore be restricted to authorized personnel.

---

## 10. Troubleshooting

### Alarm Remains in `INSUFFICIENT_DATA`

Possible causes:

* The RDS instance was recently created.
* CloudWatch has not collected enough metric samples.
* The RDS instance has been stopped or destroyed.
* The configured dimension does not match the DB instance.

Verify:

```hcl
DBInstanceIdentifier = aws_db_instance.postgres.id
```

and confirm the RDS instance exists.

---

### SNS Notification Is Not Received

Verify:

1. The SNS topic exists.
2. The CloudWatch alarm references the correct topic ARN.
3. An SNS subscription exists.
4. The subscription has been confirmed.
5. The CloudWatch alarm has actually entered the `ALARM` state.

Creating an alarm alone does not generate an SNS notification. The configured condition must first be met.

---

### Alarm Threshold Appears Too Sensitive

Thresholds used during a portfolio project should not automatically be interpreted as universal production thresholds.

Production thresholds should be determined using:

* Historical workload behavior.
* Instance size.
* Storage characteristics.
* Connection limits.
* Application requirements.
* Performance baselines.
* Business service-level objectives.

---

### Database Connection Alarm Does Not Reflect Connection Limit

The value:

```hcl
threshold = 80
```

is a monitoring threshold, not necessarily the PostgreSQL `max_connections` setting.

The alarm is intended to warn when the number of database connections exceeds the project's expected operating threshold.

Production environments should establish the threshold relative to the actual connection limit and normal application workload.

---

### Read or Write Latency Alarm Triggers

Investigate:

* Increased workload.
* Slow SQL.
* Storage I/O activity.
* Long-running transactions.
* Database checkpoints.
* Instance resource pressure.
* Storage performance characteristics.
* Changes in workload patterns.

A CloudWatch latency alarm identifies a symptom. Additional database and operating metrics may be required to determine the underlying cause.

---

### Terraform Reports an SNS Reference Error

If Terraform reports an error similar to an undeclared resource for:

```hcl
aws_sns_topic.alerts
```

Verify that `future/sns.tf` is included with the staged monitoring configuration and defines `aws_sns_topic.alerts`.

The monitoring resources depend on that topic for:

```hcl
alarm_actions = [aws_sns_topic.alerts.arn]
```

---

## 11. Lessons Learned

This phase demonstrated that deploying a database is only one part of operating a reliable database platform.

Key lessons included:

1. **CloudWatch provides infrastructure-level observability for Amazon RDS.**
   RDS automatically exposes metrics that can be incorporated into operational monitoring without installing an agent on the managed database host.

2. **Monitoring should cover multiple failure domains.**
   CPU alone does not provide sufficient visibility. Database monitoring should include compute, memory, storage capacity, connections, and I/O performance.

3. **Metrics and alarms serve different purposes.**
   Metrics provide measurements, while alarms evaluate those measurements against defined operating conditions.

4. **Alarm thresholds require context.**
   Values appropriate for a lab or portfolio project are not automatically appropriate for production. Thresholds should be adjusted according to workload baselines and service requirements.

5. **SNS converts monitoring into actionable notification.**
   CloudWatch identifies the operational condition, while SNS provides a mechanism for notifying administrators or downstream systems.

6. **Monitoring does not require weakening database network security.**
   RDS can remain isolated in private subnets while still publishing metrics to AWS monitoring services.

7. **Infrastructure monitoring supports database reliability engineering.**
   CPU pressure, memory pressure, connection growth, storage capacity, and I/O latency are important signals when diagnosing database availability and performance incidents.

8. **Observability should be implemented as Infrastructure as Code.**
   Defining CloudWatch alarms in Terraform makes monitoring reproducible, version-controlled, and ready to deploy alongside the database infrastructure when the staged RDS environment is reintroduced.

9. **A monitoring alarm identifies a condition, not necessarily the root cause.**
   Additional investigation using database logs, PostgreSQL statistics, query analysis, and supporting AWS metrics may still be necessary during an incident.

10. **Dashboards and alarms should be documented separately when necessary.**
    Although RDS metrics can be viewed through AWS monitoring interfaces, a custom Terraform-managed CloudWatch dashboard should only be documented as deployed if an `aws_cloudwatch_dashboard` resource is actually included in the infrastructure code.
