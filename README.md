# Pencil
A dotfile management system thats more easier than a whole ecosystem.

## Installation
```ps1
iwr -useb https://raw.githubusercontent.com/himadrickit/pencil/refs/heads/main/install.ps1 | iex
```

## Usage
I basically read ~/.graphite/graphites.ps1 that has a array.
```
Name = "Name"
Path = "Symlink Target Path"
Get = "File Name"
dir = true -> create a dir ; false -> is a dir (files will have dir true for creating a dir in the graphite dir) 
Got = "The dir name that will be created in the Graphite"
```
###### For Example:
```
$Graphites = @(
    @{ Name = "Github Cli"; Path = "$env:USERPROFILE\AppData\Roaming\GitHub CLI"; Get = "Github Cli"; dir = $false; Got = "Github Cli" }
    @{ Name = "Visual Studio Code"; Path = "$env:USERPROFILE\AppData\Roaming\Code\User\settings.json"; Get = "Code/settings.json"; dir = $true; Got = "Code" }
)
```

The cli has some commands :

```
    pencil buy <url>   clone your graphite repo to ~/.graphite
    pencil dot         copy existing configs (charcoals) into ~/.graphite
    pencil write       erase existing links, then symlink graphite -> system paths
    pencil erase       remove the configs from their system paths
    pencil sharp       commit and push ~/.graphite
    pencil make        add "Make Graphite" to the Explorer folder context menu
    pencil adopt <dir> move <dir> into ~/.graphite and symlink it back
    pencil shell       interactive mode (alias: pen)
    pencil help
```
