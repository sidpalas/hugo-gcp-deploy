## Hugo Static Site Running on GCP Free Tier VM

This project is to create a site with [Hugo](https://gohugo.io/) and deploy it to GCP in < 5min.

**NOTE:** For a static site like this, the built in `hugo deploy` approach to host directly within a GCP/AWS/Azure bucket is more practical and scaleable, but I wanted to familiarize myself with setting up an nginx server and eventually want to do some benchmarking on the f1-micro instance to see what kind of load it can handle.

Before starting, update:

        SITE_NAME := <SITE_NAME>

within the `./Makefile` to reflect the name of your site.

### Prerequisites
- Install hugo (`brew install hugo`)
- Install docker (`brew cask install docker`)
- Install google cloud sdk (`brew cask install google-cloud-sdk && gcloud init`)

### Instructions

0) Run `$make create-site` (uses https://gohugo.io/getting-started/quick-start/)
    - Creates the hugo site and moves it into this directory
1) Run `$make create-project`
    - Creates a new GCP project
2) enable billing using the project link output by previous command
3) Run `$make vm-setup`
    - Enables `compute.googleapis.com` and `containerregistry.googleapis.com`
    - Reserves a static IP for the site
    - Adds http and https firewall rules
    - Creates f1-micro vm,
    - Configures your local docker install to use google container registry (gcr)
    - Configures VM docker install to be able to use google container registry
5) Run `$make deploy`
    - Builds hugo site
    - Builds nginx based docker container containing site files
    - Tags and pushes to gcr
    - Removes currently running containers on VM
    - Starts container on VM using new container image
6) Run `$make list-vms` --> create A record for domain (not automated)
    - Go to your DNS provider and point your domain to the VM static IP

### TODO:
- Set up HTTPS    
- Adjust nginx config