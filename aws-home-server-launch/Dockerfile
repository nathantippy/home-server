FROM debian:10

#########
###### docker build -t home-builder .
#########
###### docker run -e ACCESS_KEY="xxxxx" -e SECRET_KEY="yyyy" home-builder
#########

ARG access_key # user with limited rights which can assume the deploy_role_arn
ARG secret_key # user with limited rights which can assume the deploy_role_arn
ARG role_arn # role with all the needed access to setup the home server
ARG region

# keep for image deployments
ENV TF_VAR_access_key=$access_key
ENV TF_VAR_secret_key=$secret_key
ENV TF_VAR_role_arn=$role_arn
ENV TF_VAR_region=$region

# needed for back end s3 state init
ENV AWS_ACCESS_KEY_ID=$access_key
ENV AWS_SECRET_ACCESS_KEY=$secret_key

RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections
RUN apt-get update
RUN apt-get install apt-utils -y
RUN apt-get install apt-transport-https ca-certificates -y 
RUN apt-get install curl gnupg2 software-properties-common -y
RUN apt-get install dialog openssh-client bash -y

RUN ssh-keygen -t ed25519 -f home-server-ssh # build key early so we are unlikely to build it again.

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

# build new server images, downloading the latest code
COPY ./home-server.pkr.hcl /
RUN packer build -parallel-builds=2\
   -var "access_key=${access_key}"\
   -var "secret_key=${secret_key}"\
   -var "region=${region}"\
   -var "role_arn=${role_arn}"\
     home-server.pkr.hcl

COPY ./full-remote-state.tfvars /
COPY ./main.tf /

RUN terraform init -upgrade=true -reconfigure -backend-config=./full-remote-state.tfvars
RUN rm ./full-remote-state.tfvars 
ENV TF_VAR_pub_key_file=home-server-ssh.pub

COPY ./internal_run.sh /
RUN chmod +x internal_run.sh
ENTRYPOINT ["/internal_run.sh"]









