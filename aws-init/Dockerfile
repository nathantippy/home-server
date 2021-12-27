FROM debian:10


#########
###### docker build -t aws-init-builder .
#########
###### docker run -e ACCESS_KEY="xxxxx" -e SECRET_KEY="yyyy" aws-init-builder
#########


RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections
RUN apt-get update
RUN apt-get install apt-utils -y
RUN apt-get install apt-transport-https ca-certificates curl gnupg2 software-properties-common -y
RUN apt-get install dialog openssh-client bash -y

#terraform
ENV APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE=DontWarn 
RUN curl -fsSL https://apt.releases.hashicorp.com/gpg | apt-key add -
RUN apt-add-repository \
    "deb [arch=$(dpkg --print-architecture)] https://apt.releases.hashicorp.com \
	$(lsb_release -cs) \
	main"
RUN apt-get update

RUN apt-get install packer=1.7.2 -y
RUN apt-get install terraform=1.1.2 -y

COPY ./main.tf /
COPY ./next_bash.tpl /
COPY ./remote-state.tpl /
RUN terraform init -migrate-state  # using local unshared state, this is just to bootstrap further work and pre-download providers

#TODO:  write up instrctrucions for capture of key and secret.. in the readme
#TODO:  internal run builds state file we should have checked in?

COPY ./internal_run.sh /
RUN chmod +x internal_run.sh
RUN mkdir exports

ENTRYPOINT ["/internal_run.sh"]









