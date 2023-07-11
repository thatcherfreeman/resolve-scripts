# Resolve Scripts
Repository of scripts I've made for Fusion and DaVinci Resolve

## Contents
- [Resolve Scripts](#resolve-scripts)
    - [Contents](#contents)
- [Installation](#installation)
    - [Running](#running)
    - [Debugging](#debugging)
- [The Scripts](#the-scripts)
    - [Color](#color)
    - [Comp](#comp)
    - [Edit](#edit)
    - [Deliver](#deliver)
    - [Utility](#utility)
        - [Remove Empty Bins](#remove-empty-bins)


# Installation
On startup, DaVinci Resolve scans the subfolders in the directories shown below and enumerates the scripts found in the Workspace application menu under Scripts.
Place your script under Utility to be listed in all pages, under Comp or Tool to be available in the Fusion page or under folders for individual pages (Edit, Color or Deliver). Scripts under Deliver are additionally listed under render jobs.
Placing your script here and invoking it from the menu is the easiest way to use scripts.

- Mac OS X:
    - All users: `/Library/Application Support/Blackmagic Design/DaVinci Resolve/Fusion/Scripts`
    - Specific user: `/Users/<UserName>/Library/Application Support/Blackmagic Design/DaVinci Resolve/Fusion/Scripts`
- Windows:
    - All users: `%PROGRAMDATA%\Blackmagic Design\DaVinci Resolve\Fusion\Scripts`
    - Specific user: `%APPDATA%\Roaming\Blackmagic Design\DaVinci Resolve\Support\Fusion\Scripts`
- Linux:
    - All users: `/opt/resolve/Fusion/Scripts`  (or `/home/resolve/Fusion/Scripts/` depending on installation)
    - Specific user: `$HOME/.local/share/DaVinciResolve/Fusion/Scripts`

## Running
Run a script by navigating to `Workspace > Scripts > Your Script Name`, once you've put the script in the right folder.

## Debugging
If a script doesn't seem to do anything, go to `Workspace > Console` and make a Github issue including anything you see in the console.

# The Scripts

## Color

## Comp

## Edit

## Deliver

## Utility
### Remove Empty Bins
Deletes all bins in the media pool that do not contain any clips.