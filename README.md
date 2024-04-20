# BloodHound Neo4j DB wrapper

## Problem description

BloodHound is a fantastic tool. But if you want to switch between dataset (ex: htb prolabs) you have to clear and reimport the data losing your progression along the way (ex: owned nodes). The database behind BloodHound is Neo4j and their multi-database option is a paid feature.

Also need something to import the output data from BloodHound faster.

## Solution

In the neo4j configuration, if you set the default database to something other then "neo4j", it will create a new folder and therefore a new database.

So with this little wrapper you can start neo4j with your desired database. You will keep your progress when switching between databases and can delete data when the project is finished.

I guess it can be used with something else then BloodHound, should work with any other tools that use neo4j databases.

The import function is from [bloodhound-import](https://github.com/som3canadian/bloodhound-import) by [somecanadian](https://twitter.com/_somecanadian_).

## How to start

Notice: only been test/used on Kali Linux. See the quick demo at the end.

### Requirements

```bash
sudo apt update
sudo apt install jq moreutils tmux bloodhound neo4j -y
```

- [Docker](https://docs.docker.com/engine/install) (for importing the BloodHound data)

### Quick start

Setup the wrapper, create a new database and import the json output from BloodHound.

```bash
git clone https://github.com/service-yack/BloodHound-Neo4j-wrapper.git
cd BloodHound-Neo4j-wrapper

# setup the wrapper
./bh-neo4j-wrapper.sh setup

# create a new database
bh-neo4j-wrapper.sh run offshore

# wait a few sec for neo4j to start

# import json output from bloodhound
bh-neo4j-wrapper.sh import neo4j 'neo4jpassword' /tmp/bloodhoundoutput json sudo

# open bloodhound
bloodhound
```

### Usage

```bash
# when setup is done, you can use the command from anywhere
bh-neo4j-wrapper.sh help
bh-neo4j-wrapper.sh list
bh-neo4j-wrapper.sh run offshore
bh-neo4j-wrapper.sh rm dante
bh-neo4j-wrapper.sh import neo4j 'neo4jpassword' /tmp/bloodhoundoutput json
# bh-neo4j-wrapper.sh import neo4j 'neo4jpassword' /tmp/bloodhoundoutput zip sudo
```

### How to uninstall

```bash
# you can delete the repo
rm -rf <reponame>
# delete symlink
sudo rm /usr/local/bin/tool.sh
```

## Quick demo

[![asciicast](https://asciinema.org/a/YqvC6YlsqTxYH5n5lUMRkyFdB.svg)](https://asciinema.org/a/YqvC6YlsqTxYH5n5lUMRkyFdB)
