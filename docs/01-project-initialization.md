# Project Initialization

## Purpose

Establish the GitHub repository, local development workspace, Terraform project structure, and baseline configuration required to begin building the AWS Networking Enterprise Foundation project.

## Objectives

* Create the GitHub repository.
* Create the local working directory.
* Build the initial repository structure.
* Configure Terraform.
* Initialize and validate the Terraform working directory.
* Establish source-control and repository-hygiene practices.

## Prerequisites

Before beginning this project, ensure the following are installed and configured:

| Requirement        | Purpose                                                       |
| ------------------ | ------------------------------------------------------------- |
| Git                | Manage source control                                         |
| GitHub account     | Host the repository                                           |
| Terraform          | Validate and provision infrastructure                         |
| AWS CLI            | Interact with AWS and verify authentication                   |
| AWS account        | Provide the target deployment environment                     |
| Visual Studio Code | Edit Terraform and documentation                              |
| PowerShell         | Execute local project commands                                |
| AWS credentials    | Required when Terraform or AWS CLI operations access AWS APIs |

## Development Environment and Tooling

The project was developed and validated using the following environment:

| Component              | Details                   |
| ---------------------- | ------------------------- |
| Operating System       | Windows 11                |
| Editor                 | Visual Studio Code        |
| Shell                  | PowerShell                |
| Cloud Provider         | Amazon Web Services (AWS) |
| AWS Region             | `us-east-1`               |
| Infrastructure as Code | Terraform v1.15.1         |
| AWS Terraform Provider | HashiCorp AWS v5.100.0    |
| Version Control        | Git                       |
| Repository Hosting     | GitHub                    |

## Initial Repository Creation

The project began by creating a dedicated GitHub repository, creating the local development workspace and directory structure, and initializing the local directory as a Git repository connected to GitHub.

### Commands Used

```powershell
git init
git branch -M main
git remote add origin https://github.com/arobb-cloud/sjqa-aws-networking-enterprise-foundation.git
git remote -v
```

### Validation

```powershell
git remote -v
git status
```

## Repository Structure

The repository was organized to separate active Terraform configuration, staged future configuration, documentation, and diagrams.

The current high-level repository structure is:

```text
├── diagrams/
├── docs/
├── future/
├── terraform/
├── .gitignore
└── README.md
```

The primary directories serve the following purposes:

* `terraform/` contains the active Terraform configuration.
* `future/` contains staged configuration retained for future integration and is not part of the current active Terraform deployment.
* `docs/` contains the project phase documentation, deployment guidance, networking notes, and troubleshooting guidance.
* `diagrams/` contains architecture and project diagrams.

## Terraform Bootstrap

Terraform was initialized from the `terraform/` directory to download the required provider, create the local `.terraform/` working directory, and generate the dependency lock file.

### Commands Used

```powershell
terraform init
terraform fmt -check -recursive
terraform validate
terraform providers
```

### Expected Results

* `.terraform/` generated locally and ignored by Git.
* `.terraform.lock.hcl` generated and retained in version control.
* Required Terraform provider successfully installed.
* Terraform formatting checks completed successfully.
* Terraform configuration validated successfully.

## Validation

The local environment, Terraform configuration, and repository connection were verified using:

```powershell
terraform version
terraform fmt -check -recursive
terraform validate
terraform providers
git remote -v
git status
```

Terraform v1.15.1 and AWS provider v5.100.0 were confirmed during project development. Terraform formatting and configuration validation also completed successfully.

The initialization process verified:

* Terraform installation.
* AWS provider availability.
* Terraform configuration validity.
* Project directory structure.
* Git repository status.
* GitHub remote configuration.

## Security and Repository Hygiene

Repository and Terraform configuration were reviewed to ensure that local, generated, and potentially sensitive files are not committed to source control.

The project `.gitignore` excludes Terraform working files and local configuration that should remain outside the Git repository, including:

```text
.terraform/
*.tfstate
*.tfstate.*
*.tfvars
tfplan
*.tfplan
crash.log
crash.*.log
```

Terraform state files are excluded because they may contain resource metadata or sensitive values. Local `.tfvars` files are also excluded so that environment-specific values and credentials are not unintentionally published to the repository.

A sanitized `terraform.tfvars.example` file is committed to the repository to document supported configuration values without exposing local or sensitive data.

AWS credentials are not stored directly in the Terraform provider configuration. Authentication is supplied through the AWS credential chain or another supported AWS authentication mechanism when access to AWS APIs is required.

The Terraform dependency lock file, `.terraform.lock.hcl`, is retained in version control to preserve provider selections and checksums and improve reproducibility across Terraform executions.

Git tracking and ignore behavior were verified using:

```powershell
git status
git ls-files
git check-ignore -v <file>
```

The repository review confirmed that Terraform state files, local variable files, Terraform plan files, and the `.terraform/` working directory are not tracked by Git.

## Lessons Learned

* Standardizing the repository structure early simplified later development.
* Separating active Terraform configuration from staged future configuration makes the current deployment state easier to understand.
* Configuring `.gitignore` early reduced the risk of accidentally committing Terraform state, local variable files, plan files, and other generated artifacts.
* Initializing Terraform before adding infrastructure helped identify provider issues early.
* Retaining `.terraform.lock.hcl` in version control improves provider consistency and reproducibility.
* Keeping reusable variables and outputs in separate files improved maintainability.
