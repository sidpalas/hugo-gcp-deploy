Cloud Build needs a docker image to build the hugo site

I used the Dockerfile from:
https://github.com/GoogleCloudPlatform/cloud-builders-community/blob/master/hugo/Dockerfile

There was no official image on DockerHub so I built and pushed it to the gcr.io repository in the same project as my website deployment:

`make build-tag-push`

This is used in the cloudbuild.yaml cloud build pipeline configuration.