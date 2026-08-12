## Purpose
	Establish the GitHub repository, local development workspace, Terraform project structure, and baseline configuration required to begin building the AWS Networking Enterprise Foundation project.


## Objectives

	• Create the GitHub repository. 
	• Create the local working directory. 
	• Build the initial folder structure. 
	• Configure Terraform. 
	• Initialize the Terraform working directory. 

## Prerequisites
Before beginning this project, ensure the following are installed and configured:
Requirement	Purpose
Git	Clone the repository and manage source control
GitHub account	Host the repository
Terraform	Provision AWS infrastructure
AWS CLI	Authenticate and interact with AWS
AWS account	Deploy infrastructure
Visual Studio Code	Edit Terraform configuration files
PowerShell (Windows)	Execute project commands
Configured AWS credentials (aws configure)	Allow Terraform to authenticate to AWS


## Development Environment and Tooling

The project was developed and validated using the following environment:

| Component | Details |
|----------|---------|
| Operating System | Windows 11 |
| Editor | Visual Studio Code |
| Shell | PowerShell |
| Cloud Provider | Amazon Web Services (AWS) |
| AWS Region | us-east-1 |
| Infrastructure as Code | Terraform |
| Version Control | Git |
| Repository Hosting | GitHub |



## Initial Repository Creation
The project began by creating a dedicated GitHub repository and cloning it into the local development workspace. A standard Git repository was initialized and configured to use the main branch.

# Commands used:

git init
git branch -M main
git remote add origin https://github.com/...
git remote -v


# Validation:

git remote -v
git status


## Repository Structure
The repository was organized to separate infrastructure code, documentation, diagrams, and project evidence. This layout mirrors the structure commonly found in enterprise Infrastructure-as-Code repositories.

terraform/
docs/
diagrams/
screenshots/
.github/


# Commands Used:

mkdir terraform
mkdir docs
mkdir diagrams
mkdir screenshots


## Terraform Bootstrap
Terraform was initialized to download the required providers, create the local working directory, and generate the dependency lock file.

# Commands Used

        terraform fmt

        terraform init

        terraform validate

        terraform plan


# Expected Results
	• .terraform/ 
	• .terraform.lock.hcl 
	• Successful validation

## Validation

Verified Git remote.

Verified Terraform initialization.

Verified provider download.

Verified project directory structure.

Verified repository connected to GitHub.

## Lessons Learned

* Standardizing the repository structure early simplified later development.
* Using .gitignore from the beginning prevented accidental commits of Terraform state and secrets.
* Initializing Terraform before adding infrastructure helped identify provider issues early.
* Keeping reusable variables and outputs in separate files improved maintainability.