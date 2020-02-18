## Hugo Static Site Running on GCP Free Tier VM

This project is to create a site with [Hugo](https://gohugo.io/) and deploy it to GCP in < 5min.

---

**NOTE:** For a static site like this, the built in `hugo deploy` approach to host directly within a GCP/AWS/Azure bucket might be easier/more scalable, but I wanted to familiarize myself with various server options (first I used [nginx](https://www.nginx.com/), and then switched to [caddy](https://caddyserver.com/v1/) b/c of its automatic https config!) and eventually want to do some benchmarking on the f1-micro instance to see what kind of load it can handle.

Before starting, update the following:

        <SITE_NAME> (within ./Makefile, e.g. my-website)
        <DOMAIN> (within ./Caddyfile, e.g. my-website.com)
        <EMAIL_ADDRESS> (within ./Caddyfile, e.g. my.name@gmail.com)

to their appropriate values.

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
    - Builds caddy based docker container containing site files
    - Tags and pushes to gcr
    - Removes currently running containers on VM
    - Starts container on VM using new container image
6) Run `$make list-vms` --> create A record for domain (not automated)
    - Go to your DNS provider and point your domain to the VM static IP
    - It's also useful to add a www CNAME record (to automatiaclly point requests like www.my-website.com to my-website.com)

### TODO:
- Tune caddy config
- Add CDN (eventually)