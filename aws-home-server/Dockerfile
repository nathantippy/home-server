FROM base-builder-image

#########
###### docker build -t home-builder .
#########
###### docker run -e ACCESS_KEY="xxxxx" -e SECRET_KEY="yyyy" home-builder
#########

ARG access_key # user with limited rights which can assume the deploy_role_arn
ARG secret_key # user with limited rights which can assume the deploy_role_arn
ARG role_arn # role with all the needed access to setup the home server
ARG region=us-east-2
ARG user
ARG dns_impl
ARG domain


# keep for image deployments
ENV TF_VAR_access_key=$access_key
ENV TF_VAR_secret_key=$secret_key
ENV TF_VAR_role_arn=$role_arn
ENV TF_VAR_region=$region
ENV TF_VAR_dns_impl=$dns_impl
ENV TF_VAR_email_domain="$domain"
ENV USER="${user}"


# needed for back end s3 state init
ENV AWS_ACCESS_KEY_ID=$access_key
ENV AWS_SECRET_ACCESS_KEY=$secret_key

# build new server images, downloading the latest code, NOTE: we may use a pre build packer image later..
COPY ./server.pkr.hcl /
RUN packer build -parallel-builds=2\
   -var "access_key=${access_key}"\
   -var "secret_key=${secret_key}"\
   -var "region=${region}"\
   -var "role_arn=${role_arn}"\
     server.pkr.hcl


COPY ./postfix-main.cf /
COPY ./user-data.sh /
COPY ./config_inc_php.tpl /

####################################################
# copy in expect- and inject the password...
# use expect to create the user and db
ENV PG_PASS=roundcube
COPY ./expect-createuser.txt /
COPY ./expect-createdb.txt /
####################################################

RUN ssh-keygen -m PEM -t rsa -b 4096 -f home-server-ssh # build key early so we are unlikely to build it again.
ENV TF_VAR_pub_key_file=home-server-ssh.pub
ENV TF_VAR_pem_key_file=home-server-ssh
RUN chown ${user} home-server-ssh.pub
RUN chown ${user} home-server-ssh




# terraform and remote state
ADD public_ip public_ip
RUN terraform -chdir=./public_ip init -upgrade=true -reconfigure -backend-config=./remote-state.tfvars
RUN terraform -chdir=./public_ip apply -auto-approve
RUN terraform -chdir=./public_ip state pull > public_ip.tfstate # keep for the next step


RUN echo "-------------------------------------------------"
# both init and apply the public ips to lock this down
# share instructions after this for taking ip and adding to DNS.


ADD run_instance run_instance
RUN terraform -chdir="./run_instance" init -upgrade=true -reconfigure -backend-config=./remote-state.tfvars

COPY ./internal_run.sh /
RUN chmod +x internal_run.sh


ENTRYPOINT ["/internal_run.sh"]









