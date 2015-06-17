---
title: earlier upgrades
layout: page
---

# Upgrades to 0.21.x and earlier

## Steps to upgrade from 0.20.x to 0.21.x

    export RAILS_ENV=production # if upgrading a production server - remember to set this again if closing and reopening the shell

    bundle exec ./script/delayed_job stop
    bundle exec rake sunspot:solr:stop

#if using rvm do:
    rvm get stable
    rvm install ruby-2.1.3

#then:

    hg pull https://bitbucket.org/seek4science/seek -r v0.21.0
    hg update # only if no other changes have been made to your local version, if you get an error ignore it and do merge
    hg merge # only required if you've made changes since installing. If you have, you may need to deal with conflicts.
    hg commit -m "merged" # likewise - only required if you made changes since installing
    cd .. && cd seek #this is to allow RVM to pick up the ruby and gemset changes
    bundle install --deployment
    bundle exec rake seek:upgrade

The mechanism to start, stop and restart the delayed-job process has now
changed you you should use the rake task
seek:workers:<start|stop|restart|status>, e.g

    bundle exec rake seek:workers:start

there is a new init.d script for this described at
https://gist.github.com/e4219ec7cb161129f1c7

## Steps to upgrade from 0.19.x to 0.20.x

Start the upgrade following the standard steps:

    #if using rvm do:
    rvm get stable
    rvm install ruby-1.9.3-p545

    export RAILS_ENV=production # if upgrading a production server - remember to set this again if closing and reopening the shell

    ./script/delayed_job stop
    bundle exec rake sunspot:solr:stop
    hg pull https://bitbucket.org/seek4science/seek -r v0.20.0
    hg update # only if no other changes have been made to your local version, if you get an error ignore it and do merge
    hg merge # only required if you've made changes since installing. If you have, you may need to deal with conflicts.
    hg commit -m "merged" # likewise - only required if you made changes since installing
    bundle install --deployment
    bundle exec rake seek:upgrade

If you are upgrading a production server, you also need to run the following
task. Be patient, as this can take a few minutes

    bundle exec rake assets:precompile

Now proceed with the rest of the usual tasks:

    bundle exec rake sunspot:solr:start # to restart the search server
    ./script/delayed_job start

    touch tmp/restart.txt
    bundle exec rake tmp:clear

If you are running through Apache, you should also add the following block to
your Apache configuration, after the Directory block:

    <LocationMatch "^/assets/.*$">
             Header unset ETag
             FileETag None
             # RFC says only cache for 1 year
             ExpiresActive On
             ExpiresDefault "access plus 1 year"
    </LocationMatch>

so it will look something like:

    <VirtualHost *:80>
         ServerName www.yourhost.com
         DocumentRoot /srv/rails/seek/public
            <Directory /srv/rails/seek/public>
             AllowOverride all
             Options -MultiViews
          </Directory>
          <LocationMatch "^/assets/.*$">
             Header unset ETag
             FileETag None
             # RFC says only cache for 1 year
             ExpiresActive On
             ExpiresDefault "access plus 1 year"
          </LocationMatch>
    </VirtualHost>

You may also need to enable a couple of Apache modules, so run:

    sudo a2enmod headers
    sudo a2enmod expires

You will then need to restart Apache

    sudo service apache2 restart

## Steps to upgrade from 0.18.x to 0.19.x

Upgrading follows the standard steps:

    RAILS_ENV=production ./script/delayed_job stop
    bundle exec rake sunspot:solr:stop RAILS_ENV=production
    hg pull https://bitbucket.org/seek4science/seek -r v0.19.1
    hg update
    hg merge # only required if you've made changes since installing. If you have you may need to deal with conflicts.
    hg commit -m "merged" # likewise - only required if you made changes since installing
    bundle install --deployment
    bundle exec rake seek:upgrade RAILS_ENV=production

    bundle exec rake sunspot:solr:start RAILS_ENV=production # to restart the search server
    RAILS_ENV=production ./script/delayed_job start

    touch tmp/restart.txt
    bundle exec rake tmp:assets:clear RAILS_ENV=production
    bundle exec rake tmp:clear RAILS_ENV=production

## Steps to upgrade from 0.17.x to 0.18.x

The changes for Version 0.18 included upgrading Ruby to version 1.9.3 and
Rails to version 3.2 - this means the upgrade process is a little bit more
involved that usual. For this reason we have a seperate page detailing this
upgrade.

Please visit [Upgrading to 0.18](doc/UPGRADING-TO-0-18.html) for details of
how to do this upgrade.

## Steps to upgrade from 0.16.x to 0.17.x

Upgrading follows the standard steps:

    RAILS_ENV=production ./script/delayed_job stop
    bundle exec rake sunspot:solr:stop RAILS_ENV=production
    hg pull https://bitbucket.org/seek4science/seek -r v0.17.1
    hg update
    hg merge # only required if you've made changes since installing. If you have you may need to deal with conflicts.
    hg commit -m "merged" # likewise - only required if you made changes since installing
    bundle install --deployment
    bundle exec rake seek:upgrade RAILS_ENV=production

    bundle exec rake sunspot:solr:start RAILS_ENV=production # to restart the search server
    RAILS_ENV=production ./script/delayed_job start

    touch tmp/restart.txt
    bundle exec rake tmp:assets:clear RAILS_ENV=production
    bundle exec rake tmp:clear RAILS_ENV=production

## Steps to upgrade between patches (e.g. between 0.16.0 to 0.16.3)

This example shows upgrading from v0.16.0, v0.16.1, or v0.16.2 to v0.16.3 as
an example, but the process is the same for upgrading between patch versions
unless otherwise stated. You can upgrade directly from one patch version to
another, skipping the intermediate versions (so you can upgrade directly
0.16.0 to 0.16.3 without first having to upgrade to 0.16.1)

    hg pull https://bitbucket.org/seek4science/seek -r v0.16.3
    hg update
    hg merge # if necessary
    hg commit -m "merged" # if necessary
    bundle install --deployment
    bundle exec rake db:migrate RAILS_ENV=production

    RAILS_ENV=production ./script/delayed_job stop
    RAILS_ENV=production ./script/delayed_job start

    touch tmp/restart.txt
    bundle exec rake tmp:assets:clear RAILS_ENV=production
    bundle exec rake tmp:clear RAILS_ENV=production

## Steps to upgrade from 0.15.x to 0.16.x

First there are additional dependencies you will need, which on Ubuntu 12.04
can be installed with:

    sudo apt-get install poppler-utils libreoffice

On Ubuntu 10.04:

    sudo apt-get install poppler-utils openoffice.org openoffice.org-java-common

Libre Office is a background service which is called by convert_office plugin,
to convert some document types (ms office documents, open office documents,
etc.) into pdf document.

The command to start libre office in headless mode and as the background
process:

    nohup soffice --headless --accept="socket,host=127.0.0.1,port=8100;urp;" --nofirststartwizard > /dev/null 2>&1

If you run on production server, using apache and phusion passenger, you will
need to run the Libre Office service under www-data user. To do this it will
need to create a working directory in /var/www. The name of the directory
changes between versions, but will be called something similar to libreoffice
or .openoffice.org2. The easiest way to create this directory is to make a
note of the permissions for /var/www, then make it writable to www-data, start
the service, and then put the permissions on /var/www back to what they were
originally.

    sudo chown www-data:www-data /var/www

Then to start the service manually you use:

    nohup sudo -H -u www-data soffice --headless --accept="socket,host=127.0.0.1,port=8100;urp;" --nofirststartwizard > /dev/null 2>&1

The 8100 port is used by default, if you'd like to run on another port, you
need also to synchronize the changed port with the default soffice_port
setting for convert_office plugin in config/environment.rb

We recommend the Libre Office service is setup using an init.d script,
following the same procedures for delayed job using the script found at:
https://gist.github.com/3787679

If you have problem with converting speed, you should upgrade OS to Ubuntu
12.04 to use Libre Office. Or you can install libre office 3.5 from PPA, but
there could be problems later on when upgrading OS. Here are the command to
install libre office from PPA:

    sudo apt-get purge openoffice* libreoffice*
    sudo apt-get install python-software-properties
    sudo add-apt-repository ppa:libreoffice/libreoffice-3-5
    sudo apt-get update
    sudo apt-get install libreoffice

Other than this, the remaining steps are the same standard steps are previous
versions:

    RAILS_ENV=production ./script/delayed_job stop
    bundle exec rake sunspot:solr:stop RAILS_ENV=production
    hg pull https://bitbucket.org/seek4science/seek -r v0.16.3
    hg update
    hg merge # only required if you've made changes since installing. If you have you may need to deal with conflicts.
    hg commit -m "merged" # likewise - only required if you made changes since installing
    bundle install --deployment
    bundle exec rake seek:upgrade RAILS_ENV=production
    bundle exec rake tmp:assets:clear RAILS_ENV=production
    bundle exec rake tmp:clear RAILS_ENV=production

    bundle exec rake sunspot:solr:start RAILS_ENV=production # to restart the search server
    RAILS_ENV=production ./script/delayed_job start
    touch tmp/restart.txt

## Steps to upgrade from 0.14.x to 0.15.x

SEEK 0.15 upgraded Rails to the latest 2 version,2.3.14. This requires an
update of Rubygems to 1.6.2. You can update rubygems directly by running

    gem update --system 1.6.2

or install from scratch by reading the INSTALL guide. You can also use
[RVM](https://rvm.io/). SEEK 0.15 also runs fine on the latest Rubygems
(currently 1.8.24) but you will get some deprecation warnings. You can check
you have the correct version of rubygems by running

    gem -v

Then you will need to install additional dependency:

    sudo apt-get install git

Once Rubygems has been updated and additional dependency has been installed,
the upgrade is the typical:

    RAILS_ENV=production ./script/delayed_job stop
    bundle exec rake sunspot:solr:stop RAILS_ENV=production
    hg pull https://bitbucket.org/seek4science/seek -r v0.15.4
    hg update
    hg merge # only required if you've made changes since installing. If you have you may need to deal with conflicts.
    hg commit -m "merged" # likewise - only required if you made changes since installing
    bundle install --deployment
    bundle exec rake seek:upgrade RAILS_ENV=production
    bundle exec rake tmp:assets:clear RAILS_ENV=production
    bundle exec rake tmp:clear RAILS_ENV=production

    bundle exec rake sunspot:solr:start RAILS_ENV=production # to restart the search server
    RAILS_ENV=production ./script/delayed_job start
    touch tmp/restart.txt

## Steps to upgrade from 0.13.x to 0.14.x

These are the fairly standard steps when upgrading between minor versions.
Note, the seek:upgrade task can take a while if there are many people and
assets in your SEEK, as it needs to populate some tables for the default
subscriptions (for email notifications).

    RAILS_ENV=production ./script/delayed_job stop
    bundle exec rake sunspot:solr:stop RAILS_ENV=production
    hg pull https://bitbucket.org/seek4science/seek -r v0.14.1
    hg update
    hg merge # only required if you've made changes since installing. If you have you may need to deal with conflicts.
    hg commit -m "merged" # likewise - only required if you made changes since installing
    bundle install --deployment
    bundle exec rake seek:upgrade RAILS_ENV=production
    bundle exec rake tmp:assets:clear RAILS_ENV=production
    bundle exec rake tmp:clear RAILS_ENV=production

    bundle exec rake sunspot:solr:start RAILS_ENV=production # to restart the search server
    RAILS_ENV=production ./script/delayed_job start
    touch tmp/restart.txt

## Steps to upgrade from 0.11.x to 0.13.x

There follows the commands required to upgrade. Anything after # are notes and
do not need to be included in the command run. There are a few additional
steps for this upgrade due to the switch from Solr to Sunspot as the search
system, and the introduction of Delayed Job for background processing.

First there is an additional dependency you will need, which on Ubuntu 10.04
or Debian can be installed with:

    sudo apt-get install libxslt-dev

on Ubuntu 12.04 this will be:

    sudo apt-get install libxslt1-dev

then the following steps will update the SEEK server:

    bundle exec rake solr:stop RAILS_ENV=production # this is specific to this upgrade, since the command to stop and start the search has changed.
    hg pull https://bitbucket.org/seek4science/seek -r v0.13.3
    hg update
    hg merge # only required if you've made changes since installing. If you have you may need to deal with conflicts.
    hg commit -m "merged" # likewise - only required if you made changes since installing
    bundle install --deployment
    bundle exec rake seek:upgrade RAILS_ENV=production
    bundle exec rake sunspot:solr:start RAILS_ENV=production # to restart the search server
    bundle exec rake sunspot:solr:reindex RAILS_ENV=production  # to reindex
    bundle exec rake tmp:assets:clear RAILS_ENV=production
    bundle exec rake tmp:clear RAILS_ENV=production

SEEK v0.13.x now uses a Ruby tool called [Delayed
Job](https://github.com/tobi/delayed_job) to handle background processing
which now needs to be started using:

    RAILS_ENV=production ./script/delayed_job start

And now SEEK should be ready to restart. If running together with Passenger
Phusion as described in the install guide this is simply a case of:

    touch tmp/restart.txt

If you auto start solr with an init.d/ script - this will need updating to
reflect the change to sunspot:solr:start. The updated script should look
something like: https://gist.github.com/3143434

