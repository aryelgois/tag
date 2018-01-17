# Intro

A tool for using tags in files

It is a Bash* command line tool to manipulate tags in your files. They are
stored in a `.tags` file in the same directory as the tagged file.

Tags can contain any character, except comma (`,`) and newline (`\n`).

> \* developed with version 4.3.48(1)-release


# Install

Run [install.sh]. You can pass a root directory where files will be installed.

For a manual installation, copy [src/tag.sh] to any directory in your PATH and
gzip [doc/tag.1] into `/usr/local/man/man1/`


# Documentation

There is a man page availabe:

- If you have installed the package, simply run `man tag`
- You can also run `man doc/tag.1` inside the repository


[install.sh]: install.sh
[src/tag.sh]: src/tag.sh
[doc/tag.1]: doc/tag.1
