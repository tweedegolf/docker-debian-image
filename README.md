# Debian Docker Images

This is a debian base image with an entrypoint and some common dependencies
already set up. Currently the following tags/versions are available:

- Trixie: `trixie`, `testing`
- Bookworm: `bookworm`, `stable`, `latest`
- Bullseye: `bullseye`, `oldstable`
- Buster: `buster`, `oldoldstable`

Note that the `testing`, `stable`, `latest` and `oldstable` labels may at any
time change to a newer distribution. If you want to ensure that your images use
the same distribution any time, you should always refer to the release codename.

The images are updated automatically every weekend. If you have images building
upon these then you can check the exact schedule in our workflow and have your
own scheduled builds some time after these are built.

## Included software

Besides the software included in the base docker images from debian, we include
the following pieces of software:

- `curl` - For downloading files
- `wget` - For downloading files
- `ca-certificates` - Trusted root certificates for HTTPS
- `apt-transport-https` - For downloading apt repositories from HTTPS
- `gnupg` - Working with gnupg, and setting up additional apt sigining keys
- `dirmngr` - Setting up additional apt sigining keys
- `gosu` - Allows efficient switching from root to another user, see below.
- `git` - For accessing git repositories
- `dnsutils` - To debug DNS issues
- `tmux` - To run multiple shells simultaneously from a single one
- `nano` - Basic editing
- `vim` - Editor
- `lsof` - Debug file access issues
- `unzip` - Extracting zip files
- `libnss-wrapper` - Dynamically fake user and group names
- `procps` - Utilities for debugging currently running processes
- `strace` - For tracing system calls
- `zutils` - Tools for working with gzip/bzip2/lzip/xz

## Usage

You can run this container as you would any other container, for example, to
run a simple root container with an interactive bash, run:

    docker run -it ghcr.io/tweedegolf/debian:stable bash

### During development

Often during development you will change files from inside the container that
are mounted as a volume. If we would use the root user as in the above command
this would write any file as the root user. If you started the docker container
under your local user you suddenly would have root files in between files from
your local user.

To prevent this from happening, this image can be started with any user/group
id. Using libnss_wrapper we then dynamically assign a username (`tg` by
default) and groupname to your user inside the container. As an example, see
this command:

    docker run -it --user "$(id -u):$(id -g)" ghcr.io/tweedegolf/debian:stable bash

When you run this command you should see a prompt logged in as the `tg` user.
This user should have an effective user id and group id that is the same as the
host system user you started the command from.

You can actually change the username/group name generated inside the container
using environment variables:

    docker run -it --user "$(id -u):$(id -g)" -e "DYNAMIC_USER_NAME=$(id -un)" -e "DYNAMIC_GROUP_NAME=$(id -gn)" ghcr.io/tweedegolf/debian:stable bash

The `DYNAMIC_USER_NAME` variable sets the name of the user and the
`DYNAMIC_GROUP_NAME` sets the name of the group for the user. Note that
changing the username has no effect on any permissions of your user, it only
changes the display names.

The generated user will have a home directory at `/home` (without a username
in the path) but you can change this using the `DYNAMIC_USER_HOME` environment
variable. You can also change the login shell using `DYNAMIC_USER_SHELL`,
although in most cases this has not much of a practical effect as you have to
specify which command to start anyway.

### Dynamic users and docker exec

When you want to launch an additional process in the same container docker
provides the `exec` command (`docker exec` or `docker compose exec` when using
compose). This will start an additional process that has access to the same
resources as the process that initially started the container. However, if
you run a command with `exec` the entrypoint will not run. Because of this, we
can't setup libnss_wrapper and you may end up with `I have no name!` in your
bash prompt when using a dynamic user. Some commands may also require a
username and fail completely. To work around this you will have to manually
call the entrypoint script. You can do this by prepending `docker-entrypoint`
or `doen` to your command. If you would normally want to do:

    docker exec container bash

Then you should instead run:

    docker exec container doen bash

Note that you only have to do this if you want the entrypoint to run, so when
you want to launch an additional root process as shown below, you will not need
to use this.

### Dynamic users and root

This image does not contain sudo by default and root does not have a password
set up. Because of this you cannot simply change to root from the development
user. If there is any command you need to run as root, you should use
`docker exec` to run a command as root:

    docker exec -it -u root container bash

Note that you do not need to prepend the entrypoint script as with dynamic
users.

### During production / extending this image

When using this image as a base for your production images you should have a
specific user baked into the image instead of depending on the dynamic user
feature. This means you should use `useradd` to create a new user when
extending from this image. You can set the `ROOT_SWITCH_USER` environment
variable to make sure that the image is then never run as root, but always
automatically switches to another user when it starts as root, meaning a user
of your application cannot forget doing this for themselves. Below is an
example of how to extend this image:

    FROM ghcr.io/tweedegolf/debian:stable
    RUN useradd -c Application -m -U app
    ENV ROOT_SWITCH_USER app
    COPY --chown=app:app ./build /opt/application
    CMD ["/opt/application/app"]

One other advantage of using the `ROOT_SWITCH_USER` setting over setting
`USER` in your Dockerfile is that you can still send `RUN` commands in your
Dockerfile as root, which can simplify the build process.

### Running as root without auto switching

If you want to run your production image and you have set `ROOT_SWITCH_USER`
in your Dockerfile, then you will have to explicitly set the `ROOT_SWITCH_USER`
variable to an empty value, e.g.:

    docker run -it -e "ROOT_SWITCH_USER=" ghcr.io/tweedegolf/debian:stable bash

### Update ssh_known_hosts file

    ssh-keyscan github.com > ssh_known_hosts
    ssh-keyscan gitlab.com >> ssh_known_hosts
    ssh-keyscan tgrep.nl >> ssh_known_hosts
