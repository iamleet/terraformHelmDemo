# Intro to Terraform and Helm Charts
Quick intro to Terraform and Helm which can provision infrastructure as code very efficiently.

# Tools
Please check out the links for the tools we are using. Below is a brief description of what we will be using them for.

* [Terraform](https://www.terraform.io/) - provisions infrastructure as code.
* [Helm](https://helm.sh/) - provisions services on Kube from code.
* [Google Cloud](https://cloud.google.com) - infrastructure as a service that will host our environment for a small fee.
* [Lets Encrypt](https://letsencrypt.org/) - free ssl encryption service.

## Top Level Commands
At a high level this is what the process consists of.
Terraform is used to provision the infrastructure components in this case a Kubernetes cluster and Helm is used to provision the service in this case a Ghost blog on the new cluster.

To deploy a cluster and service.
```shell
terraform apply
helm install stable/ghost
```
To destroy service and cluster.
```shell
helm delete --purge devopsmiami
terraform destroy
```
# Phase 1 - Plain Ol' Blog (HTTP Only)
This repo is split into multiple phases to better explain the changes happening in the infrastructure. In the first phase we will have only the blog exposed to the web on top of the Kube cluster.

## Kube Cluster
These are the steps to get the demo blog rolling.

* Install GCP
* Setup an Access Key
* Setup Terraform
* Create variables file for Terraform
* Create a Kubernetes Cluster with Terraform
* Patch Kubernetes cluster for Helm
* Create an external IP in GCP
* Create secrets file for Helm
* Run Helm

## Terraform
Using Terraform to provision a Kubernetes cluster on Google Cloud Engine. The `kubeCluster.tf` file contains the instructions to use a module that will setup our Kube cluster with no grief. `Secrets.tf` contains all the secrets we don't want in version control and needs to be created by you.

[Terraform Module](https://www.terraform.io/docs/providers/google/r/container_cluster.html)

### Terraform Secrets
The values we like to keep out of version control are kept in a `secrets.tf` file. Rename the `example-secrets.tf` file to `secrets.tf` and adjust the values. Items labeled *required* in the chart below require an update before continuing.

option | default | requires update
:---: | :---: | :---:
Cluster Name | devopscluster |
Node count | 1 |
Project name | devops-miami-demo | *required*
Cluster username | root |
Cluster password | REPLACEME | *required*
Availability zone | us-east1-c |
Domain label | devopsmiami |
Cluster Tags | blog, demo, helm, terraform |

### GCP Access Token
Install gcloud suite CLI tool and create a token you can use via the console. This is beyond the scope of this tutorial and you should reference the documents for how to create the access token required to continue. [How to Create Token](https://cloud.google.com/docs/authentication/production)
```shell
export GOOGLE_APPLICATION_CREDENTIALS=./accessToken.json
```
*If this is a new project and you have never used Kubernetes Engine before you will need to visit the Kubernetes Engine section on the console(website) to initialize it.*

Now we have all the parts we need. A token for accessing GCP, instructions for Terraform, and secrets to fill in the blanks.
```shell
terraform apply
```

## Helm
Quickly deploy services to Kubernetes cluster from code. *Oooo shiny! I like shiny.*
It runs a Tiller agent which allows for two way communication, a lot more can get done. Sorry Terraform, you are just managing my clusters b.
[Helm - A La Bitnami](https://docs.bitnami.com/kubernetes/how-to/deploy-application-kubernetes-helm/)

### LB IP reservation
We need a public facing IP; we can reserve one and set it with the `ghostLoadBalancerIP` in the following section. Run the following command then navigate in the console to `VPC network` -> `External IP addresses`.
```shell
$ gcloud compute addresses create ghost-public-ip
```

On this page you should see an entry labeled `ghost-public-ip`; copy the external address for the next step.

### Secrets file
Secrets are kept in a `example-values.yaml`. Rename it to `secrets.yaml` then update the required value. The chart below shows all the values which need to be updated tagged as *required*.

Example: [values.yml](https://github.com/helm/charts/blob/master/stable/ghost/values.yaml)

option | default | requires update | notes
:---: | :---: | :---: | :---: |
ghostLoadBalancerIP | no default | *required* | must match lb external IP
ghostUsername | user@example.com | |
ghostPassword | no default password | *required* |
ghostEmail | user@example.com | | your login
ghostDatabasePassword | no default password | *required* | must match mariadb.user.password & mariadb.rootUser.password
mariadb.user.password | no default set | *required* | must match ghostDatabasePassword
mariadb.rootUser.password | no default set | *required* | must match ghostDatabasePassword
resources.cpu | 300m | *required* | set to 200m for clusters under 2 nodes

*This Helm chart launches mariadb with the rootUser pw - might need to check that out*

Add these lines above externlDatabase to set the db password ghost is going to use to connect to the DB.

### Helm and Tiller - Bleeding edge stuff
Helm requires a service account on the Kubernetes cluster in order to work correctly. Using a yaml file we can create what's required to get going.
```shell
kubectl apply -f create-helm-service-account.yaml
helm init --service-account helm --override 'spec.template.spec.containers[0].command'='{/tiller,--storage=secret}'
```

Give it a minute to provision your Tiller pod and then move to the next section. A quick way to test if it is running or not is running `helm list`. It will give you an error the Tiller pod is not running if it is still spinning up. Otherwise, it gives you back a blank return since nothing is running yet.

### Install Ghost Chart
Ready to run Helm, init Tiller on the your Kube cluster and setup a Chart.
```shell
# Run helm
helm install --name demo-blog -f secrets.yaml stable/ghost
```

Now you should get a return that show s the `Blog URL` and `Admin URL` you can use any one of these to reach the site and confirm a successful deployment. Mind you this is not production ready.

When you are finished exploring the blog and the deployment you can destory it with the following command:
```shell
# Destroy
helm del --purge demo-blog
```
