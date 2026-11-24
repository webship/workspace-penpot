#!/usr/bin/env bash

# workspace-name: Penpot (design and prototyping)

# Installed by the Penpot plugin (plugins.sh --install penpot); __WORKSPACE__ is the workspace it was installed into.
#
# Build a Penpot site in containers: the publisher's images of its frontend, backend and exporter, with PostgreSQL
# and Valkey, as services of a project of the container tool, at https://<name>.ddev.site, its mail caught at
# https://<name>.ddev.site:8026. With --install the workspace account is an account of the site; with --add-users the
# default accounts are in the team "Design team"; with --sample-content the projects, files and comment the step pack
# is tested on. Penpot builds on DDEV only for now.

# Bootstrap.
# Find the workspace tooling from this script, so a fresh clone needs no setup.
WORKSPACE_SCRIPTS="${WORKSPACE_SCRIPTS:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../core/scripts" && pwd)}";
source ${WORKSPACE_SCRIPTS}/bootstrap.sh || exit 1 ;

# Load workspace settings.
eval $(parse_yaml ${WORKSPACE_CONFIG}/workspace.__WORKSPACE__.settings.yml);

# Distribution.
distribution_name="penpot";
distribution_title="Penpot";

ARGPARSE_DESCRIPTION="Build a ${distribution_title} site in __WORKSPACE__"
# The args file comes with the plugin: core/scripts/plugins/penpot/ is where plugins.sh --install puts it.
source ${WORKSPACE_SCRIPTS}/plugins/penpot/args/arg-penpot.sh || exit 1 ;

shift $#;

penpot_build ;
