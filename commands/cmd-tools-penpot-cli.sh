#!/usr/bin/env bash

# Installed by the Penpot plugin (plugins.sh --install penpot); __WORKSPACE__ is the workspace it was installed into.
#
# A Penpot site of this folder: what it is and its accounts; --run the backend's own tool (manage.py) in its
# container; --add-users and --cancel-users the default accounts; --sample-content the sample content; --tidy what a
# stopped test run left.

# Bootstrap.
# Find the workspace tooling from this script, so a fresh clone needs no setup.
WORKSPACE_SCRIPTS="${WORKSPACE_SCRIPTS:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../core/scripts" && pwd)}";
source ${WORKSPACE_SCRIPTS}/bootstrap.sh || exit 1 ;

# Load workspace settings.
eval $(parse_yaml ${WORKSPACE_CONFIG}/workspace.__WORKSPACE__.settings.yml);

ARGPARSE_DESCRIPTION="A Penpot site of __WORKSPACE__: what it is, its accounts, the backend's own tool"
# The args file comes with the plugin: core/scripts/plugins/penpot/ is where plugins.sh --install puts it.
source ${WORKSPACE_SCRIPTS}/plugins/penpot/args/arg-penpot-cli.sh || exit 1 ;

shift $#;

penpot_cli_tool ;
