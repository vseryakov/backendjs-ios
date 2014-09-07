# Backendjs iOS SDK

# Requirements

XCode 5 or higher is required. No external dependencies.

# Installation

This framework is supposed to be intergated and possibly modified according to your project requirements so
the only method of installation supported is to copy files into your project directory or just add references 
in the XCode without copying.

# Usage

The Example project provides some basic usage but the primary goal is to talk to Backendjs server. 

All other features like UI, navigation, components are completely optional.

The minimal use case is to only copy 2 files BKjs.h and BKjs.m with AFNetworking folder and use it for making 
requests to a backendjs server.

These files provide also a generic way to make HTTP calls to any server and support Query parameters, 
JSON and images for GET and POST requests.

Access to keychain, easy and safe access to dictionaries, shortcuts to the system information and other little useful
pieces of code are also include in the base BKjs singleton.

## Social support

The Social folder contains components to interact with social networks, supported OAUth1 and OAUth2 methods of authentication
along with OAUth2 for Web only(Facebook).

## UI support

UI support includes basic navigation subsystem that allows making complex navigation between controllers without using storyboard.
There are also some useful methods and functions that every project requires and "re-invents" every time.

# Author 

Vlad Seryakov

