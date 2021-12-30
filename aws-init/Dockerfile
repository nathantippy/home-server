FROM base-builder-image


#########
###### docker build -t aws-init-builder .
#########
###### docker run -e ACCESS_KEY="xxxxx" -e SECRET_KEY="yyyy" aws-init-builder
#########

COPY ./main.tf /
COPY ./home-server-setup.tpl /
COPY ./remote-state.tpl /
RUN terraform init # using local unshared state, this is just to bootstrap further work and pre-download providers

COPY ./internal_run.sh /
RUN chmod +x internal_run.sh

ENTRYPOINT ["/internal_run.sh"]









