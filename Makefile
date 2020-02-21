# Project config variables
SITE_NAME := <SITE_NAME>
# NOTE: PROJECT_ID Needs to be unique across all of GCP (and < 30 characters...)
PROJECT_ID := $(SITE_NAME)-project
REGION := us-central1
ZONE := us-central1-a
IMAGE_NAME := $(SITE_NAME)-caddy
MACHINE_TYPE := f1-micro
VM_IMAGE := projects/cos-cloud/global/images/cos-69-10895-385-0
INSTANCE_NAME := cos-$(MACHINE_TYPE)
ADDRESS_NAME := $(SITE_NAME)-ip
IMAGE_TAG := 0.1

# Instructions
.PHONY: help
help:
	@echo __ 0. run $$ make create-site [uses https://gohugo.io/getting-started/quick-start/]
	@echo __ 1. run $$ make create-project
	@echo __ 2. enable billing using the project link
	@echo __ 3. run $$ make vm-setup
	@echo __ 4. run $$ make deploy
	@echo __ 5. run $$ make list-vms // create A + CNAME record for domain
	@echo __ 6. modify the Caddyfile and redeploy to configure https

################################################################
#
# Local Operations
#
# These Make targets should be run when interacting 
# with the site on your local system
#
################################################################
.PHONY: create-site
create-site:
	hugo new site $(SITE_NAME)
	mv ./$(SITE_NAME)/* ./
	rm -r ./$(SITE_NAME)
	git init
	git submodule add https://github.com/budparr/gohugo-theme-ananke.git themes/ananke
	echo 'theme = "ananke"' >> config.toml
	hugo new posts/test-post.md

.PHONY: build-site
build-site:
	HUGO_ENV=production hugo

.PHONY: run-hugo-server
run-hugo-server:
	hugo server -D

.PHONY: build-container
build-container: build-site
	docker build ./ --tag $(IMAGE_NAME)

################################################################
#
# Remote Operations
#
# These Make targets should be run when interacting 
# with the compute engine vm
#
################################################################
.PHONY: ssh
ssh:
	gcloud compute ssh $(INSTANCE_NAME) \
		--project=$(PROJECT_ID) \
		--zone=$(ZONE)

.PHONY: build-tag-push
build-tag-push: build-container
	@echo "Did you update the IMAGE_TAG? (y or n)"; \
	read UPDATED; \
	if [ $$UPDATED != "y" ]; then echo you didn\'t answer \'y\'... aborting; exit 1 ; fi
	docker tag $(IMAGE_NAME) gcr.io/$(PROJECT_ID)/$(IMAGE_NAME):$(IMAGE_TAG);
	docker push gcr.io/$(PROJECT_ID)/$(IMAGE_NAME):$(IMAGE_TAG);

.PHONY: cleanup-remote-containers
cleanup-remote-containers:
	# Using dash in front of the following command 
	# so that if $docker container stop command fails
	# (b/c there are no containers) Make will still proceed
	- gcloud compute ssh $(INSTANCE_NAME) \
		--project=$(PROJECT_ID) \
		--zone=$(ZONE) -- \
		'docker container stop $$(docker container ls -aq) && docker container rm $$(docker container ls -aq)'

.PHONY: deploy
deploy: build-tag-push cleanup-remote-containers
	gcloud compute ssh $(INSTANCE_NAME) \
		--project=$(PROJECT_ID) \
		--zone=$(ZONE) -- \
		'docker run -d --restart=unless-stopped -p 80:80 -p 443:443 -v $$HOME/.caddy:/root/.caddy gcr.io/$(PROJECT_ID)/$(IMAGE_NAME):$(IMAGE_TAG)' &

################################################################
#
# GCP Resource Set up
#
# These Make targets should only need to be run 
# once (when settings things up in GCP)
#
################################################################
.PHONY: create-project
create-project:
	gcloud projects create $(PROJECT_ID)
	@echo Navigate to: https://console.cloud.google.com/billing/linkedaccount?project=$(PROJECT_ID) in order to link a billing account before proceeding with $$make vm-setup

.PHONY: enable-apis
enable-apis:
	gcloud services enable compute.googleapis.com --project=$(PROJECT_ID)
	gcloud services enable containerregistry.googleapis.com --project=$(PROJECT_ID)
	
.PHONY: reserve-static-ip
reserve-static-ip:
	gcloud compute addresses create $(ADDRESS_NAME) \
		--project=$(PROJECT_ID) \
		--region=$(REGION) 

.PHONY: create-vm
create-vm: 
	gcloud compute instances create $(INSTANCE_NAME) \
		--project=$(PROJECT_ID) \
		--zone=$(ZONE) \
		--machine-type=$(MACHINE_TYPE) \
		--image=$(VM_IMAGE) \
		--address=$(ADDRESS_NAME) \
		--tags=http-server,https-server

.PHONY: add-firewall-rules
add-firewall-rules:
	gcloud compute firewall-rules create default-allow-http \
		--project=$(PROJECT_ID) \
		--target-tags=http-server \
        --allow tcp:80
	gcloud compute firewall-rules create default-allow-https \
		--project=$(PROJECT_ID) \
		--target-tags=https-server \
        --allow tcp:443

# Must be run once to enable local docker to push to google container registry
.PHONY: configure-docker
configure-docker:
	gcloud auth configure-docker

# Must be run once to enable remote docker to pull from google container registry
.PHONY: configure-gcr
configure-gcr:
	gcloud compute ssh $(INSTANCE_NAME) \
		--project=$(PROJECT_ID) \
		--zone=$(ZONE) -- \
		docker-credential-gcr configure-docker

.PHONY: list-vms
list-vms:
	gcloud compute instances list \
		--project=$(PROJECT_ID)

.PHONY: vm-setup
vm-setup:
	$(MAKE) enable-apis
	$(MAKE) reserve-static-ip
	$(MAKE) add-firewall-rules
	$(MAKE) create-vm
	$(MAKE) configure-docker
	$(MAKE) configure-gcr
	$(MAKE) list-vms

################################################################
#
# Cloud Build Setup
#
################################################################

USER := <USER_NAME> # username when SSHing into VM (used to specify /home/USER path)
REPO_NAME := <REPO_NAME>

# Instructions
.PHONY: help-cloud-build
help-cloud-build:
	@echo __ 0. Follow https://cloud.google.com/source-repositories/docs/mirroring-a-github-repository to mirror github repo to cloud source repo
	# Alternatively, just use cloud source to begin with... (I just prefer keeping my code in one place and that happens to be GitHub right now).#
	# This was necessary because of the theme being used as a git submodule (https://github.com/GoogleCloudPlatform/cloud-builders/issues/26)

	@echo __ 1. Set USER and REPO_NAME variables in Makefile
	@echo __ 2. run $$ make setup-cloud-build

.PHONY: enable-more-apis
enable-more-apis:
	gcloud services enable sourcerepo.googleapis.com --project=$(PROJECT_ID)
	gcloud services enable cloudbuild.googleapis.com --project=$(PROJECT_ID)

.PHONY: add-iam-roles
add-iam-roles:
	gcloud projects add-iam-policy-binding $(PROJECT_ID) \
		--member serviceAccount:$$(gcloud projects describe $(PROJECT_ID) --format="value(projectNumber)")@cloudbuild.gserviceaccount.com \
		--role roles/compute.instanceAdmin.v1
	gcloud projects add-iam-policy-binding $(PROJECT_ID) \
		--member serviceAccount:$$(gcloud projects describe $(PROJECT_ID) --format="value(projectNumber)")@cloudbuild.gserviceaccount.com \
		--role roles/iam.serviceAccountUser

###################################### 
#
# Actual pipeline: See cloudbuild.yaml
#
#   1) init and update submodule
#
#   Tip: 
# 	  Use ssh when adding the submodule as the remote (so pushing is easier) but change to https 
#     in .gitmodules and .git/config to enable cloud builder to access
#
#   2) build site with hugo
#   3) build container image 
#	4) push container image
#   5) stop running server
#   6) start new server
#
######################################	

# NOTE: must install gcloud beta components)
.PHONY create-trigger:
create-trigger:
	gcloud beta builds triggers create cloud-source-repositories \
		--project=$(PROJECT_ID) \
		--repo=$(REPO_NAME) \
		--branch-pattern=master \
		--build-config=cloudbuild.yaml \
		--substitutions=_IMAGE_NAME=$(IMAGE_NAME),_SSH_STRING=$(USER)@$(INSTANCE_NAME),_ZONE=$(ZONE),_HOME=/home/$(USER)

.PHONY setup-cloud-build:
setup-cloud-build:
	$(MAKE) enable-more-apis
	$(MAKE) add-iam-roles
	$(MAKE) create-trigger