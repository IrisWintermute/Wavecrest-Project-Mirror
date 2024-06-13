# Dev-Common-Setup

## Table of Contents

- [Dev-Common-Setup](#dev-common-setup)
  - [Table of Contents](#table-of-contents)
  - [About ](#about-)
  - [Getting Started ](#getting-started-)
  - [Prerequisites ](#prerequisites-)
  - [Using ](#using-)

## About <a name = "about"></a>

This terraform project is designed to be run to set up an environment for Wavecrest Connect. Containing environment secrets, DNS setup, certificates, keys and everything else that should be generated before running the main installations.

## Getting Started <a name = "getting_started"></a>

These instructions will get you a copy of the project up and running on your local machine for development and testing purposes. See [deployment](#deployment) for notes on how to deploy the project on a live system.

## Prerequisites <a name = "prerequisites"></a>

Needs:
* Linux environment (and bash version >=4)
* Terraform

```
Give examples
```

## Using <a name = "using"></a>

1. AWS SSO login to AWS Account complete

Assuming the Account Profile is "dev"

```
export AWS_PROFILE=dev
aws sso login
aws configure export-credentials --format env
```

1. Initialise Terraform, plan and then apply

```
make init
make plan
make apply
```

