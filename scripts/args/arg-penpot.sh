#!/usr/bin/env bash

argparse "$@" <<ARGEOF || exit 1
parser.add_argument('PROJECT_NAME',
                    help='The name of the project: its folder, its DDEV project and its host name.')
parser.add_argument('--runtime',
                    dest='RUNTIME',
                    default="_none_",
                    choices=['ddev'],
                    help='The container runtime to build on: ddev. Penpot builds on DDEV only for now (webship/workspace#694).')
parser.add_argument('-i', '--install',
                    action='store_true',
                    default=False,
                    help='Make the workspace account an account of the site.')
parser.add_argument('-a', '--add-users',
                    action='store_true',
                    default=False,
                    help='With --install, add the default accounts (owner, admin, editor, viewer) in the team "Design team": the ones the test scenarios log in as.')
parser.add_argument('-s', '--sample-content',
                    action='store_true',
                    default=False,
                    help='With --install and --add-users, add the sample content the step pack is tested on: two projects, their files (two imported from the plugin\'s .penpot files), a shared library, a draft and a comment.')
parser.add_argument('-v', '--penpot-version',
                    default="",
                    help='The release of the site (a tag of the publisher\'s images): 2.19.4 by default. Example: --penpot-version 2.19.4')
parser.add_argument('-l', '--launch',
                    action='store_true',
                    default=False,
                    help='Open the site in a browser when it is ready.')
ARGEOF
