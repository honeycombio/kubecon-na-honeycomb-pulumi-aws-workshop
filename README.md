# Aws-workshop-template

## Repo structure

```bash
.
├── contentspec.yaml                  <-- Specifies the version of the content
├── README.md                         <-- This instructions file
├── static                            <-- Directory for static assets to be hosted alongside the workshop (ie. images, scripts, documents, etc) 
└── content                           <-- Directory for workshop content markdown
    └── index.en.md                   <-- At the root of each directory, there must be at least one markdown file
    └── introduction                  <-- Directory for workshop content markdown
        └── index.en.md               <-- Markdown file that would be render 
```

## What's Included

This project contains the following folders:
* `static`: This folder contains static assets to be hosted alongside the workshop (ie. images, scripts, documents, etc) 
* `content`: This is the core workshop folder. This is generated as HTML and hosted for presentation for customers.

## How to create content

Under the `content` folder, Each folder requires at least one `index.<lang>.md` file. The file will have a header

```aidl
+++
title = "AWS Workshop Template"
weight = 0
+++
```

The title will be the title on navigation panel on the left. The weight determines the order the page appears in the navigation panel.

## How to run

`preview_build` is located in *static* folder.

### On Mac
1. Open Terminal and change to the location of the preview_build app with `cd YourDirectory`
2. Make the binary executable by running `chmod +x preview_build`. [Reference](https://support.apple.com/en-gb/guide/terminal/apdd100908f-06b3-4e63-8a87-32e71241bab4/mac)
3. If you're using macOS 15 Sequoia or greater, follow [these steps](https://support.apple.com/en-gb/guide/mac-help/mh40616/15.0/mac/15.0)
4. Otherwise, In the Finder on your Mac, locate the downloaded app
* Don’t use Launchpad to do this. Launchpad doesn’t allow you to access the shortcut menu.
5. **Control-click the app icon**, then choose **Open** from the shortcut menu
6. Click **Open**
7. Launch the preview application from your CLI by providing the relative or absolute path, such as running `~/Downloads/preview_build` in Terminal