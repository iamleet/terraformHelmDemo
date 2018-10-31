# Intro to Terraform and Helm Charts
Quick intro to Terraform and Helm which can provision infrastructure as code very efficiently.

# Tools
Please check out the links for the tools we are using. Below is a brief description of what we will be using them for.

* [Terraform](https://www.terraform.io/) - provisions infrastructure as code.
* [Helm](https://helm.sh/) - provisions services on Kube from code.
* [Google Cloud](https://cloud.google.com) - infrastructure as a service that will host our environment for a small fee.
* [Lets Encrypt](https://letsencrypt.org/) - free ssl encryption service.

## Top Level Commands
At a high level this is what the process consists of. Terraform is used to provision the infrastructure components in this case a Kubernetes cluster and Helm is used to provision the service in this case a Ghost blog on the new cluster.

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
Using Terraform to provision a Kubernetes cluster on Google Cloud Engine. The `kubeCluster.tf` file contains the instructions to use a module that will setup our Kube cluster with no grief.
[Terraform Module](https://www.terraform.io/docs/providers/google/r/container_cluster.html)

### Setup the vars file
All the variables are contained in a separate file not stored in version control. Create the file and add the required values.
```yaml
# Cluster name
variable "name" {
  type = "string"
  default = "devopsDemocluster"
}
# Project name
variable "project" {
  type = "string"
  default = "devopsmiamiDemo-#######"
}
# Cluster username
variable "username" {
  type = "string"
  default = "root"
}
# Cluster password
variable "password" {
  type = "string"
  default = "longstringypassword"
}
# Availability zones
variable "zone" {
  type = "string"
  default = "us-east1-c"
}

variable "additional_zones" {
  type = "string"
  default = "us-east1-b"
}
# Domain label
variable "domain_label" {
  type = "string"
}
  default = "devopsmiami"
```

### GCP Access Token
Install their CLI tool and create a token you can use. This is beyond the scope of this tutorial and you should reference the documents for how to create the access token required to continue.
```shell
export GOOGLE_APPLICATION_CREDENTIALS=./accessKey.json
```
Now we have all the parts we need. A token for accessing GCP, instructions for Terraform, and secrets to fill in the blanks.
```shell
terraform apply -var "environment=production"
```
## Helm
Its a more advanced manager for deloying services.. oooo shiny! I like shiny.
It runs a Tiller agent which allows for two way communication, a lot more can get done. Sorry Terraform, you are just managing my clusters b.
[Helm - A La Bitnami](https://docs.bitnami.com/kubernetes/how-to/deploy-application-kubernetes-helm/)

## Secrets file
Secrets are kept in a values yaml file called secrets and ignored by git.
Example: [values.yml](https://github.com/helm/charts/blob/master/stable/ghost/values.yaml)

Create a secrets file from the default example and fill in the following values.
```yml
# ghost section
ghostLoadBalancerIP: SEE BELOW FOR LB INFO
ghostBlogTitle: Devops Miami Blog
ghostUsername: root
ghostPassword: someLoginPassword
ghostBlogTitle: The title of you blog
## mysql section
rootUser:
  password: morelongStringyPasswords #must match db pw below
```

Add these lines above externlDatabase to set the db password ghost is going to use to connect to the DB.
```yml
## Local database configuration
ghostDatabasePassword: morelongStringyPasswords #needs to match rootUser pw above
```
#### LB IP reservation
We need a public facing IP, we can reserve one ahead of time and set it with the `ghostLoadBalancerIP`. Run the following commands then set variable to the ip address in the secrets file.
```shell
$ gcloud compute addresses create ghost-public-ip
```

### Helm and Tiller - Bleeding edge stuff
Helm doesnt work out of the box from the looks(--rbac something maybe?). Run the following to get it going. Make sure you created your `secrets.yml` and set the required values.
```shell
# Helm bug
helm init # adds a tiller service to your cluster
kubectl create serviceaccount --namespace kube-system tiller
kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller
kubectl patch deploy --namespace kube-system tiller-deploy -p '{"spec":{"template":{"spec":{"serviceAccount":"tiller"}}}}'
```
[patch role](https://github.com/helm/helm/issues/2224)

### Install Ghost Chart
Ready to run Helm, init Tiller on the your Kube cluster and setup a Chart.
```shell
# Run helm
helm install --name prod-devopsmiami-blog -f secrets.yaml stable/ghost
# Destroy
helm del --purge prod-devopsmiami-blog
```

## SSL with Lets Encrypt
Who wants insecure sites? Not us. Using an Nginx container with Lets Encrypt we can proxy the Ghost for easy ssl.

### Create the service.
Launch the service via Helm.
```shell
helm install stable/nginx-ingress \
  --namespace kube-system \
  --name prod-devopsmiami-ingress
```

Turn off external access to the unsecured port on the Ghost app by switching it to the internal address.
```yaml
kubectl patch svc prod-devopsmiami-blog-ghost --type='json' -p '[{"op":"remove","path":"/spec/ports/0/nodePort"},{"op":"replace","path":"/spec/type","value":"ClusterIP"}]'
```

Create an ingress point.
```shell
kubectl apply -f ingress.yaml
```

At this point you should be able to see the page with SSL but not a valid cert.

*Make sure to redirect your dns to the new IP address of the proxy because the next step will not work without a valid dns!*

### Sign it
Deploy a kube-lego container to pull a Let's Encrypt cert. Set the email to something that works for you.
```shell
helm install stable/kube-lego \
  --namespace kube-system \
  --name prod-lego-devopsmiami \
  --set rbac.create=true,config.LEGO_EMAIL=$EMAIL,config.LEGO_URL=https://acme-v01.api.letsencrypt.org/directory
```

Point to the `tls-ingress` yaml and trigger the Let's Encrypt process.
```shell
kubectl apply -f tls-ingress.yaml
```

# Configuring Ghost
*Google Analytics* for site statistics and a style block to override css on the theme. Anything you add to the `Blog Header` section gets injected into each page on the blog.

## Ghost Theme
The theme can be updated from code injection page by adding the following to the `Blog Header` section.
[Mapache Ghost Theme](https://github.com/godofredoninja/Mapache)
```html
<style>
:root {
  --primary-color: #2b2b2b;
  --header-color: #FFFFFF;
  --header-color-hover: #8a0000;
  --post-color-link: #8a0000;
  --story-cover-category-color: #8a0000;
  --footer-color-link: #8a0000;
  --composite-color: #8a0000;
}
.button--primary {
    border-color: rgba(196, 50, 53, 1);
    color: rgba(196, 50, 53, 1);
}
.u-accentColor--iconNormal {
    color: rgba(196, 50, 53, 1);
    fill: rgba(196, 50, 53, 1);
}
.button--dark:hover {
    background: rgba(196, 50, 53, 1);
    border-color: rgba(196, 50, 53, 1);
}
mark {background-image: linear-gradient(to bottom, rgba(255, 220, 214, 1), rgba(255, 220, 214, 1)) !important;}
</style>
```
## Google Analytics
Google Analytics gives insight to the traffic of the site. Metrics for the who, what, when, and where. When you plug the correct block of code into the `Blog Header` section this information will be passed over to `analytics.google.com`.  
```html
<!-- Global site tag (gtag.js) - Google Analytics -->
<script async src="https://www.googletagmanager.com/gtag/js?id=$ID"></script>
<script>
  window.dataLayer = window.dataLayer || [];
  function gtag(){dataLayer.push(arguments);}
  gtag('js', new Date());

  gtag('config', '$ID');
</script>
```
