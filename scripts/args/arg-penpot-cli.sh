#!/usr/bin/env bash

argparse "$@" <<ARGEOF || exit 1
parser.add_argument('PROJECT_NAME',
                    help='The name of the Penpot project in this folder.')
parser.add_argument('-r', '--run',
                    default="_none_",
                    help='Run the backend\'s own tool (manage.py) with these arguments, in its container. Example: --run "search-profile -e editor@example.com"')
parser.add_argument('-a', '--add-users',
                    action='store_true',
                    default=False,
                    help='Make the default accounts (owner, admin, editor, viewer) and their team, or give them back their names, passwords and roles.')
parser.add_argument('-c', '--cancel-users',
                    action='store_true',
                    default=False,
                    help='Delete the default accounts, the way the backend\'s own tool does: they cannot log in any more, and Penpot removes them after its deletion delay.')
parser.add_argument('-s', '--sample-content',
                    action='store_true',
                    default=False,
                    help='Add the sample content the step pack is tested on, where it is missing.')
parser.add_argument('-t', '--tidy',
                    action='store_true',
                    default=False,
                    help='Remove what a test run that was stopped half way left ("Webship test …"), and put the roles and the onboarding of the default accounts back.')
ARGEOF
