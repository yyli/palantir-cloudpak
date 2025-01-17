<p align="right">
<a href="https://autorelease.general.dmz.palantir.tech/palantir/palantir-cloudpak"><img src="https://img.shields.io/badge/Perform%20an-Autorelease-success.svg" alt="Autorelease"></a>
</p>

# palantir-cloudpak

This repository provides a CASE bundle for the palantir-operator to install and run Palantir for IBM Cloud Pak For Data (P4CP4D) on alongside Cloud Pak For Data 3.5+ in an Open Shift Container Platform (OCP) 4.5+.

## Planning

You can install Palantir for IBM Cloud Pak for Data on top of Cloud Pak for Data.

### Supported Platforms, Architectures and Cloud Providers

To install Palantir for IBM Cloud Pak for Data, you must have the following software already installed on your cluster:

- Red hat OpenShift Container Platform version 4.5 or later.
- IBM Cloud Pak for Data 3.5 or later refreshes. For more information, see:
  - [Planning for Cloud Pak for Data](https://www.ibm.com/support/knowledgecenter/SSQNUZ_3.5.0/cpd/plan/planning.html)
  - [Installing Cloud Pak for Data](https://www.ibm.com/support/knowledgecenter/SSQNUZ_3.5.0/cpd/install/install.html)
- IBM Watson Knowledge Catalog version 3.5.x.

It is also recommended that you have:

- IBM Watson Machine Learning version 3.5.x
- IBM Watson Studio version 3.5.x

_Architectures_

Palantir for IBM Cloud Pak for Data must be run on compute nodes that support the x86_64 architecture.

_Cloud Providers_

Palantir for IBM Cloud Pak for Data can be run on any cloud provider so long as the following are true:

- An OpenShift storage class is available that supports:
  - 3,000 IOPS with a sustained throughput of 256MiB/s
  - READ and WRITE average latency of less than 1ms and p95 latency of less than 5ms.
- A supported blob storage service, with four dedicated buckets (two for data, one for backups, and one for audit logs). We provide specialized support with optimized performance and security for AWS S3, Azure Blob Storage, and Google Cloud Storage. Additionally, we support other blob storage implementations that offer an AWS S3-compatible API and comparable performance.

### Security Considerations

Palantir for IBM Cloud Pak for Data supports encryption at rest and in transit.

*Encryption in transit*:

- Communication between services occurs over TLS 1.2 using strong, industry-standard ciphersuites.

*Encryption at rest*:

- All Foundry Filesystems (blob storage) are secured with application level encryption. See below for details.
- Encryption of metadata and other local storage should be provided passively via encrypted storage partitions exposed via configured storage classes in OpenShift.

*Palantir Foundry Filesystem Encryption*:

- Each file encrypted with distinct symmetric key (AES-256)
- AES keys are envelope encrypted with an asymmetric keypair (RSA-2048) known only to the Palantir Foundry Catalog

### Licenses

Additionally, to install the software, you must have the following entitlement keys:

- An IBM entitlement key that includes entitlements for Cloud Pak for Data and Palantir for Cloud Pak for Data. For details on how to get your entitlement key, see [Obtaining the installation files](https://www.ibm.com/support/knowledgecenter/SSQNUZ_3.5.0/cpd/install/installation-files.html) in the IBM Cloud Pak for Data documentation.  
- A Palantir registration key. For details on how to get your registration key, see [Obtaining your registration key](#obtaining-your-registration-key)
​

### Obtaining your registration key

Before you can install Palantir, you must provide information about your cluster to Palantir.

Send the following information to Palantir:

- The IP addresses that are used for outbound network traffic from your OpenShift Container Platform cluster.
​
Palantir will add these IP addresses to a security group so that your cluster can connect to the Palantir delivery environment and container registry.

After this task is complete, Palantir will send you:

- Your Palantir registration key, which gives you access to the delivery environment
- Your username and password, which you use to authenticate to the Palantir container registry.

### Generating an RSA key pair for data encryption

Palantir for IBM Cloud Pak for Data requires an RSA key pair that it will use for encrypting all data it stores in the AWS S3 compatible blob storage that is provided as part of installation. This can be generated using the following steps:
```bash
openssl genrsa -out private-pkcs1.pem 2048
openssl rsa -in private-pkcs1.pem -out public-key.pem -outform pem -pubout
openssl pkcs8 -topk8 -inform pem -in private-pkcs1.pem -outform pem -nocrypt -out private-key.pem
rm private-pkcs1.pem
```
**This key pair is the master encryption key for all data P4CP4D stores and should be backed up in a safe and secure location** 

## Installing Palantir for IBM Cloud Pak for Data

Installing Palantir for IBM Cloud Pak for Data uses the IBM Cloud Pak CLI (`cloudctl`) to install an IBM [Container Application Software for Enterprises (CASE)](https://github.com/IBM/case) bundle, which can be found at https://github.com/palantir/palantir-cloudpak. The `cloudctl` CLI and Palantir CASE bundle are responsible for preparing the OCP cluster resources and deploying the Palantir operator. The Palantir operator is then responsible for installing the P4CP4D platform. The Palantir Operator and P4CP4D container images are provided by the Palantir container registry. Instructions below are provided for information necessary to authenticate with the Palantir container registry and how to configure the installer to communicate with it.

### Pre-requisites

The installation instructions below assume the following:

- IBM Cloud Pak CLI v3.7.x has already been downloaded and is available. Details can be found at https://github.com/IBM/cloud-pak-cli.
- The Palantir for IBM Cloud Pak for Data CASE bundle has been downloaded. Details can be found at https://github.com/palantir/palantir-cloudpak.
- All pre-requisite software outlined in [Supported Platforms, Architectures and Cloud Providers](#supported-platforms-architectures-and-cloud-providers) must already be installed.

### How to install Palantir for IBM Cloud Pak for Data

#### Define installation settings

You will need the following pieces of information for the installation process:

- `$NAMESPACE` - pick the namespace that you want to install the palantir-operator in. Note that this should be different than the namespace in which Cloud Pak for Data has been installed.
- `$CPD_NAMESPACE` - the existing OpenShift namespace that the IBM Cloud Pak for Data installation exists within.
- `$CPD_DOMAIN` - the fully qualified domain name of the Cloud Pak for Data instance with which P4CP4D should integrate with.
- `$STORAGE_CLASS` - the Kubernetes storage class to use for storing data in P4CP4D.
- `$PALANTIR_DOCKER_USER` - the username to authenticate to Palantir's container registry
- `$PALANTIR_DOCKER_PASSWORD` - the password to authenticate to Palantir's container registry
- `$DATA_STORAGE_PATH` - the path in the AWS S3 compatible blob storage that P4CP4D should use for storing data. This should follow a format like `s3a://<path to use>`
- `$DATA_STORAGE_ENDPOINT` - the API endpoint to use for access to the AWS S3 compatible blob storage API that P4CP4D should use for storing data like `s3.us-east-2.amazonaws.com`
- `$DATA_STORAGE_ACCESS_KEY` - the access key for the AWS S3 compatible blob storage that you want P4CP4D to use. This is what you might set as the value for `AWS_ACCESS_KEY_ID` environment variable for the AWS SDK or `fs.s3a.access.key` for a Hadoop S3A filesystem.
- `$DATA_STORAGE_ACCESS_KEY_SECRET` - the access key secret for the AWS S3 compatible blob storage that you want P4CP4D to use. This is what you might set as the value for `AWS_SECRET_ACCESS_KEY` environment variable for the AWS SDK or `fs.s3a.secret.key` for a Hadoop S3A filesystem.
- `$DATA_STORAGE_ENCRYPTION_PUBLIC_KEY_FILE` - the file containing the PEM encoded RSA public key that P4CP4D should use for data encryption. See [Generating an RSA key pair for data encryption](#generating-an-rsa-key-pair-for-data-encryption) for how to generate this.
- `$DATA_STORAGE_ENCRYPTION_PRIVATE_KEY_FILE` - the file containing the PEM encoded RSA private key that P4CP4D should use for data encryption. See [Generating an RSA key pair for data encryption](#generating-an-rsa-key-pair-for-data-encryption) for how to generate this.
- `$IBM_ENTITLEMENT_KEY` - the IBM Entitlement key that includes entitlements for CP4D and P4CP4D that you obtained as part of [Licenses](#licenses).
- `$PALANTIR_REGISTRATION_KEY` - the Palantir registration key that you obtained as part of [Licenses](#licenses).
- `$P4CP4D_PROXY_CERTIFICATE_FILE` - the file containing the PEM encoded certificate the P4CP4D reverse proxy will present to users of P4CP4D. To use a self-signed certificate, do not set this field.
- `$P4CP4D_PROXY_PRIVATE_KEY_FILE` - the file containing the PEM encoded private key associated with the certificate provided in `$P4CP4D_PROXY_CERTIFICATE_FILE`, which the P4CP4D reverse proxy will use when establishing TLS connections for users of P4CP4D. To use a self-signed certificate, do not set this field.
- `$DISABLE_NETWORK_FIREWALLS` (optional) - set to either `true` or `false`. If not set, defaults to `false`. You can usually safely leave this at its default value. You may need to use this configuration in cases where the Container Networking Interface (CNI) plugin configured with your OSCP cluster does not work with P4CP4D's firewall policies.

These will be referenced in the installation steps below. These environment variables should be exported with appropriate values before proceeding further.

#### Installation Steps

There are two steps to installing Palantir for IBM Cloud Pak for Data. These instructions assume that `cloudctl` is on your executable path. If it is not, you should use the absolute filepath of the `cloudctl` based on where it is installed in your environment.
It is also assumed that the following steps are run inside the directory where the [Palantir for IBM Cloud Pak for Data CASE bundle](https://github.com/palantir/palantir-cloudpak) has been extracted.

1. Ensure all environment variables mentioned in [installation settings](#Define installation settings) have been exported.
2. Run the following command.
```bash
cloudctl case launch -c ./case/palantir-operator  -t=1 -e palantir-operator
```

#### Uninstalling

To uninstall Palantir for IBM Cloud Pak for Data, run the following commands:

```bash
oc delete namespace $NAMESPACE
```

Before restarting the installation, please email the Palantir team a request to re-enable the registration key.

### Validating a Palantir for IBM Cloud Pak for Data Installation

Once you have finished following the [installation steps](#installation-steps) for Palantir for IBM Cloud Pak for Data, you can validate that your installation was successful using the following steps:

1. Make sure that the Palantir for IBM Cloud Pak for Data operator is has a "Running" status in the namespace you chose for installation. Note down the value for IP column as it will be useful for later steps.

> $ oc get pods -n $NAMESPACE -lname=palantir-operator -o wide<br>
> NAME&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;READY&nbsp;&nbsp;&nbsp;STATUS&nbsp;&nbsp;&nbsp;&nbsp;RESTARTS&nbsp;&nbsp;&nbsp;AGE&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;IP&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;NODE&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;NOMINATED NODE&nbsp;&nbsp;&nbsp;READINESS GATES<br>
> palantir-operator-df4c67ffc-zbmth &nbsp;&nbsp;&nbsp;1/1&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Running&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;0&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;2m55s&nbsp;&nbsp;172.30.178.152&nbsp;&nbsp;10.188.99.6&nbsp;&nbsp;

2. Create a “bastion“ container using the following command. This command will open a shell for you inside the ”bastion“ container.

```bash
oc run -n default bastion -it --image=registry.access.redhat.com/ubi8/ubi-minimal:latest -- bash
```

3. Install jq using the following command inside the container created in Step 2

```bash
curl -L -o /usr/local/bin/jq https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64 && chmod +x /usr/local/bin/jq
```

4. Make the following HTTP request from inside the container created in Step 2 using the IP from Step 1.

```bash
curl https://<IP FROM STEP 1>:3756/palantir-operator/status/health -k | jq .checks.INSTALL_PROGRESS
```

You should see an output that looks like the following:

```json
{
  "type": "INSTALL_PROGRESS",
  "state": "REPAIRING",
  "message": "Installation is in progress",
  "params": {
    "details": {
      "APOLLO_SETUP": "in-progress",
      "APPLICATIONS_SETUP": "in-progress",
      "INFRASTRUCTURE_SETUP": "complete",
      "NAMESPACES_SETUP": "complete"
    }
  }
}
```

The installation will have completed once all of the “in-progress” items have moved to the “complete” state. The expected completion order of these is the following

- NAMESPACES_SETUP
- INFRASTRUCTURE_SETUP
- APOLLO_SETUP
- APPLICATIONS_SETUP

#### Accessing the installation

Once the installation is complete, you can open Palantir for IBM Cloud Pak for Data by clicking _Get Started_ or another link in the Palantir card on the Cloud Pak for Data home page. Alternatively, you can visit the URL for the frontend directly. This URL will depend on the domain that is being used for your Cloud Pak for Data installation. Check with your cluster administrator for this information if you don't already have it.

```
https://palantir-cloudpak.<cloudpak-for-data-hostname>/multipass/login/all
```

Once in Palantir for IBM Cloud Pak for Data, integrated documentation can be accessed via the _Help & Support_ link at the bottom of the left sidebar.

### Operator scoping and use of namespaces

The Palantir operator to install P4CP4D results in the following OpenShift namespaces being created:

- `$NAMESPACE` - the environment variable defined as part of the installation steps above is the name of the namespace used to run the Palantir Operator deployment.
- `palantir-cloudpak-compute-misc` - namespace which contains non-Spark Palantir compute services.
- `palantir-cloudpak-compute-spark` - namespace which contains Spark specific Palantir compute services.
- `palantir-cloudpak-data` - namespace which contains persisted data storage services (Cassandra, Elastic Search, etc).
- `palantir-cloudpak-infrastructure` - namespace which contains infrastructure and control plane services responsible for managing the services that make up the Palantir platform.
- `palantir-cloudpak-services` - namespace which contains the core Palantir services for P4CP4D.
