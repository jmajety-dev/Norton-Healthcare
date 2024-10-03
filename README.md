# NortonHealthcare Infrastructure Project

This repository contains the Terraform infrastructure code for managing AWS services such as DNSSEC, AWS Firewall, Route 53, CloudFront, API Gateway, AWS Backup, GuardDuty, Macie, and CloudWatch, with an emphasis on security and HIPAA compliance for NortonHealthcare.

## Table of Contents
- [Architecture](#architecture)
- [Features](#features)
- [Setup Instructions](#setup-instructions)
- [Sensitive Data](#sensitive-data)
- [HIPAA Compliance](#hipaa-compliance)
- [Disaster Recovery Plan](#disaster-recovery-plan)
- [License](#license)

## Architecture

The following architecture demonstrates the overall cloud infrastructure designed for NortonHealthcare, including integrations for DNSSEC, Route 53, CloudFront, API Gateway, and various security services.

![NortonHealthcare Architecture](NortonHealthcare.jpeg)

## Features
- **DNSSEC and Route 53**: DNS security and routing are configured to protect DNS integrity.
- **AWS Firewall Manager**: Provides centralized management of VPC security policies.
- **CloudFront**: Content distribution for API Gateway and other static content.
- **API Gateway**: Secure API Gateway setup with Route 53 routing.
- **SNS Notifications**: Real-time notifications for the IT Security team.
- **AWS Backup**: Automated backups for RDS and S3 resources, integrated with KMS for encryption.
- **GuardDuty and Macie**: Security monitoring for unusual behavior and sensitive data discovery.
- **CloudWatch and CloudTrail**: Monitoring and logging of infrastructure activity.

## Setup Instructions

### Prerequisites
- AWS CLI and Terraform installed
- AWS Account with the necessary permissions

### Steps to Deploy
1. Clone this repository:
    ```bash
    git clone https://github.com/jmajety-lab/Norton-Healthcare.git
    cd nortonhealthcare-infra
    ```
2. Initialize Terraform:
    ```bash
    terraform init
    ```
3. Validate the configuration:
    ```bash
    terraform validate
    ```
4. Plan the deployment:
    ```bash
    terraform plan
    ```
5. Apply the configuration:
    ```bash
    terraform apply
    ```



## HIPAA Compliance

This infrastructure is designed to comply with **HIPAA** guidelines, ensuring that protected health information (PHI) is handled with the highest level of security and privacy. The following measures have been implemented to ensure compliance:
- **Encryption**: All data stored in S3 and RDS is encrypted using AWS KMS, meeting HIPAA encryption requirements.
- **Access Control**: IAM policies restrict access to sensitive data to authorized users only, ensuring role-based access control (RBAC).
- **Audit Logs**: AWS CloudTrail is enabled to provide detailed audit logs for all API calls and activities across the infrastructure, ensuring traceability and accountability.
- **Security Monitoring**: AWS GuardDuty and Macie are integrated to monitor for suspicious activity and the presence of sensitive data, ensuring ongoing protection of PHI.

## Disaster Recovery Plan

This infrastructure includes a comprehensive **disaster recovery plan** to ensure business continuity in the event of a disaster. The disaster recovery plan includes:
- **Automated Backups**: AWS Backup is configured for RDS and S3, providing daily snapshots and data retention policies.
- **Multi-Region Redundancy**: S3 and RDS snapshots are replicated across regions to ensure data is recoverable even in the event of a regional failure.
- **Failover Mechanisms**: Route 53 is configured with failover policies, allowing traffic to be rerouted to backup instances in case of service disruptions.
- **Recovery Time Objective (RTO)**: The infrastructure is designed to recover critical systems within the shortest possible time frame, reducing downtime.
- **Recovery Point Objective (RPO)**: Regular backups ensure that data can be restored to the most recent state, minimizing data loss in case of disaster.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
