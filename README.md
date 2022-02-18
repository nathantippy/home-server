# home-server
Small family or club server for inexpensive cloud hosting on ARM. Provides email, matrix and other services.

1. Install Docker
    This is the only app you will need installed on your local machine, all the required tools will be installed inside the docker container.
    
2. Log into AWS console and capture the key and secret for the admin account

3. run 01-aws_init.sh passing in the admin key and secret this one time

4. confirm 3 ran successfully and keep contains 3 files. Then delete the key and secret from the console created in step 2.

5. run 02-aws-server-build.sh, wait as the server image is constructed.

6. run 03-aws-server-launch.sh, wait as the server is started.

///////


buy a domain..

setup keys? automate this
