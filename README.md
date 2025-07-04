# Resolve Scripts
Repository of scripts I've made for Fusion and DaVinci Resolve

Support me at: [https://www.buymeacoffee.com/thatcherfreeman](https://www.buymeacoffee.com/thatcherfreeman)

## Contents
- [Resolve Scripts](#resolve-scripts)
    - [Contents](#contents)
- [Installation](#installation)
    - [Running](#running)
    - [Debugging](#debugging)
- [The Scripts](#the-scripts)
    - [Coding](#coding)
        - [Get Scripting Properties](#get-scripting-properties)
    - [Color](#color)
        - [Compute DNG Matrix](#compute-dng-matrix)
        - [Export CDLs](#export-cdls)
        - [Toggle Nodes](#toggle-nodes)
    - [Comp](#comp)
    - [Edit](#edit)
        - [Copy Timeline Settings](#copy-timeline-settings)
        - [Generate All Clips Timeline](#generate-all-clips-timeline)
        - [Rename Clips](#rename-clips)
        - [Rename Timelines](#rename-timelines)
        - [Update Version Number](#update-version-number)
    - [Deliver](#deliver)
    - [Utility](#utility)
        - [Relink Media Pool Clips](#relink-media-pool-clips)
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

## Coding
### Get Scripting Properties
Prints to the console the project/Timeline/Clip/MediaItem settings for reference.

## Color

### Compute DNG Matrix
Computes the Color Formation Matrix from the currently active DNG clip. The standard in DNG image processing is that two matrices are in the metadata of a DNG, one optimized for each of two white balance settings (usually daylight and illuminant A). These two matrices are interpolated between depending on the in-camera white balance setting. Additionally, this can be done in one of two methods: using the "Forward Matrix" approach, or with the standard approach that is used when the forward matrices are not provided (instead, using the ColorMatrix tags). This script requires that you have exiftool installed, so you'll have to paste in the path to exiftool in the first box that shows up, or you'll want to overwrite it in the first few lines of the script.

### Export CDLs
With a relevant timeline open, run this script and specify a destination directory. In that folder, the script will write CDL, CC, or CCC files. CDL or CC files will be titled by the file name or reel name of the clip, depending on what is specified before you hit Go. If the reel name could not be found, it will write with the clip's file name.

The script goes through each clip in the timeline in the first track in order and generates a CDL, CC, or CCC file. If a file already exists, then the script will refuse to overwrite that file unless "Overwrite color files" is checked. I would not recommend running this on timelines that have Fusion compositions, compound clips, or duplicate clips/clips that have been split. I would also recommend running this with the console open just to see if there are any warnings and for an explanation of which clips were skipped, etc.

### Toggle Nodes
Indicate the node id and layer index and this tool will allow you to enable or disable all nodes with that node number.

## Comp

## Edit

### Copy Timeline Settings
Attempts to copy a specified timeline's settings to all timelines in the currently open bin.

### Generate All Clips Timeline
Generates a timeline that contains all the video clips used in any timeline in your project, and their original media pool linked audio. Only takes the portion of each file from the first frame that is used in any timeline to the last frame used in any timeline, and everything between those two frames. Allows you to specify the name of the new timeline and whether you want to include disabled clips or not. Doesn't always work right when you have retimed clips.

### Rename Clips
Find and replace clip names within the current media pool bin.

### Rename Timelines
Find and replace timeline names within the current bin, and add prefixes or suffixes.

### Update Version Number
Select some clips in the media pool. This goes through clips whose paths include something like "v002" or "V1234" and replaces each selected media pool item with a new version number.

#### Known Caveats:
**if you're skipping version numbers for some reason** - This will break the "maximize version" button because that works by incrementing the version number until it fails.

**or if your file path for a clip has multiple v#### where they do not match** - How am I supposed to adjust version numbers in this case right


## Deliver

## Utility
### Relink Media Pool Clips
Useful for if you have moved your entire project structure to a new folder. Allows you to relink all file paths for all projects in a project manager folder.

#### Instructions
For each project, replace all clips with a certain filename prefix to a new prefix.
To use this, use the following steps:
1. Copy the folder with all your footage to a new location.
2. In the Project manager, make sure there is a folder that contains only projects whose clips are ALL in the folder from step 1.
3. Run this script. In the first box, indicate the OLD path, ending with the appropriate slash (mac) or backslash (windows)
4. In the second box, indicate the NEW folder. Make sure that if what's written in the first box is substituted for what's in the second box, the clips will all still exist!
5. BACK UP YOUR PROJECT DATABASE
6. Run once with the "I backed up my project database" box unchecked. This will do a dry run.
7. Check the console after the dry run to make sure that it got through all your projects without having difficulty finding a file.
8. Run the script again with the checkbox checked.
9. Cross your fingers.

### Remove Empty Bins
Deletes all bins in the media pool that do not contain any clips.
