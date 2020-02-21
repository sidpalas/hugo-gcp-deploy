# Project config variables
SITE_NAME ?= <SITE_NAME>
# NOTE: PROJECT_ID Needs to be unique across all of GCP (and < 30 characters...)
PROJECT_ID := $(SITE_NAME)-project
IMAGE_NAME := hugo-builder

.PHONY: build-container
build-container:
	docker build ./ --tag $(IMAGE_NAME)

.PHONY: build-tag-push
build-tag-push: build-container
	docker tag $(IMAGE_NAME) gcr.io/$(PROJECT_ID)/$(IMAGE_NAME);
	docker push gcr.io/$(PROJECT_ID)/$(IMAGE_NAME);
